-- ZAD_PLAN ١٠.١ الشريحة ٤ (أ): التعلّم كله على السيرفر، وكل «هل خلص؟» رهان بيتحكم عليه.
--
-- المقاس ١٢/١١: الموبايل كان عنده متعلّم تاني (ConsumptionLearner في Hive) هو اللي بيطلّع كارت «هل خلص X؟»
-- في الرئيسية، والأصناف الراكدة، و«هيخلص إمتى» في التقرير. العقل والبوت مابيشوفوهوش، وبيضيع لو الموبايل
-- اتغيّر، ومش بيشوف شرا باقي أفراد البيت. السيرفر بيتعلّم بالفعل من نفس الحركات (zad_record_observation ⇐
-- zad_consumption، ومن الشرا المتكرر من ١١/١١). يعني المتعلّم التاني تكرار — بيتشال، والموبايل بيقرا من هنا.
--
-- حلقة الفيدباك (سؤال المالك ١٢/١١): كل مرة السيرفر بيقول «اسأل عن الصنف ده» بيتسجّل رهان في
-- zad_pantry_bets — الأيام اللي فاضلة حسب المعدل وثقته — والإجابة بتحكم عليه: «خلص» أو «−١» = صاب،
-- «لسه» = خاب، ومفيش إجابة = اتجاهل. zad_pantry_bet_accuracy بتقيس النسبة كل أسبوع.
--
-- القواعد (نفس السيرفر النهارده، مش قواعد جديدة):
--   • المعدل: zad_consumption.avg_daily_qty لاسم الصنف المعتمد في البيت (zad_product_canonical_for)،
--     الأعلى بين أفراد البيت. الأيام الباقية = الكمية ÷ المعدل.
--   • يتسأل: الكمية > ٠، مش «على فترات»، والأيام الباقية ≤ ٢ (نفس _inventory_needs_checkin بالمعدل)،
--     ومحدش في البيت قال «لسه» عليه في آخر ٣ أيام، ومااتسألش واتجاوب النهارده.
--   • راكد (Task 23): الكمية > ٠، ومفيش حركة عليه ٣٠ يوم، وعمره ما نزل.

create table if not exists public.zad_pantry_bets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  item_id uuid not null,
  item_name text not null check (char_length(item_name) between 1 and 200),
  asked_on date not null,
  asked_at timestamptz not null default now(),
  predicted_days_left numeric check (predicted_days_left is null or predicted_days_left >= 0),
  confidence text not null check (confidence in ('known', 'approximate', 'unasked')),
  answer text check (answer is null or answer in ('finished', 'used_one', 'still_have')),
  answered_at timestamptz,
  constraint zad_pantry_bets_answered check ((answer is null) = (answered_at is null)),
  constraint zad_pantry_bets_one_a_day unique (user_id, item_id, asked_on)
);

create index if not exists zad_pantry_bets_user_recent on public.zad_pantry_bets (user_id, asked_at desc);

alter table public.zad_pantry_bets enable row level security;
revoke all on table public.zad_pantry_bets from anon, authenticated;
grant select on table public.zad_pantry_bets to authenticated;
grant all on table public.zad_pantry_bets to service_role;

drop policy if exists zad_pantry_bets_own on public.zad_pantry_bets;
create policy zad_pantry_bets_own on public.zad_pantry_bets for select to authenticated
  using (user_id = (select auth.uid()));

comment on table public.zad_pantry_bets is
  'ZAD_PLAN 10.1 slice 4 — every «هل خلص؟» the server asked, with its prediction and the answer that judged it. Written through zad_pantry_learning / zad_pantry_bet_answer only.';

/** مخزن البيت بعين السيرفر: لكل صنف الأيام الباقية وثقتها، وراكد ولا لأ، ويتسأل عنه ولا لأ. */
create or replace function public.zad_pantry_learning()
returns table (
  item_id uuid,
  item_name text,
  days_left numeric,
  confidence text,
  stagnant boolean,
  ask boolean
)
language plpgsql
volatile
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_me uuid := auth.uid();
  v_today date;
begin
  if v_me is null then
    raise exception 'not_authenticated';
  end if;

  select (now() at time zone coalesce(public.zad_market_timezone(u.country), 'Africa/Cairo'))::date
    into v_today
    from public.zad_users u where u.id = v_me;
  v_today := coalesce(v_today, (now() at time zone 'Africa/Cairo')::date);

  return query
  with home as (
    select v_me as uid
    union
    select m.user_id from public.family_members m
     where m.family_id in (select public.get_my_family_ids()) and m.user_id is not null
  ),
  inv as (
    select i.id, i.item_name, i.quantity, i.restock_mode, i.created_at,
           private.zad_product_canonical_for(v_me, i.item_name) as canon
      from public.zad_inventory i
     where i.user_id = v_me
        or (i.family_id is not null and i.family_id in (select public.get_my_family_ids()))
     limit 400
  ),
  rate as (
    select inv.id,
           max(c.avg_daily_qty) filter (where c.avg_daily_qty > 0) as avg_daily_qty,
           bool_or(c.rate_known and c.avg_daily_qty > 0) as known
      from inv
      join public.zad_consumption c
        on c.user_id in (select uid from home) and c.item_name in (inv.canon, inv.item_name)
     group by inv.id
  ),
  obs as (
    select o.item_name, o.observed_at,
           o.qty < lag(o.qty) over (partition by o.user_id, o.item_name order by o.observed_at, o.created_at, o.id) as dropped
      from public.zad_inventory_observations o
     where o.user_id in (select uid from home)
  ),
  activity as (
    select inv.id, max(obs.observed_at) as last_at, coalesce(bool_or(obs.dropped), false) as used
      from inv join obs on obs.item_name in (inv.canon, inv.item_name)
     group by inv.id
  ),
  judged as (
    select inv.id, inv.item_name, inv.quantity, inv.restock_mode, inv.created_at,
           case when r.avg_daily_qty > 0 then round((inv.quantity / r.avg_daily_qty::numeric), 1) end as days_left,
           case when r.avg_daily_qty > 0 then case when r.known then 'known' else 'approximate' end end as confidence,
           a.last_at, coalesce(a.used, false) as used
      from inv
      left join rate r on r.id = inv.id
      left join activity a on a.id = inv.id
  ),
  out as (
    select j.id, j.item_name, j.days_left, j.confidence,
           (j.quantity > 0
             and coalesce(j.last_at, j.created_at, now()) < now() - interval '30 days'
             and not j.used) as stagnant,
           (j.quantity > 0
             and j.restock_mode is distinct from 'occasional'
             and j.days_left is not null and j.days_left <= 2
             and not exists (
               select 1 from public.zad_pantry_bets b
                where b.user_id in (select uid from home) and b.item_id = j.id
                  and ((b.answer = 'still_have' and b.answered_at > now() - interval '3 days')
                       or (b.asked_on = v_today and b.answer is not null))
             )) as ask
      from judged j
  ),
  bets as (
    insert into public.zad_pantry_bets (user_id, item_id, item_name, asked_on, predicted_days_left, confidence)
    select v_me, o.id, o.item_name, v_today, o.days_left, o.confidence
      from out o where o.ask
    on conflict on constraint zad_pantry_bets_one_a_day do nothing
    returning 1
  )
  select o.id, o.item_name, o.days_left, o.confidence, o.stagnant, o.ask
    from out o
   order by o.ask desc, o.days_left asc nulls last, o.item_name;
end;
$$;

revoke all on function public.zad_pantry_learning() from public, anon;
grant execute on function public.zad_pantry_learning() to authenticated, service_role;

/**
 * إجابة «هل خلص؟» من الموبايل: بتحكم على آخر رهان مفتوح للصنف ده (آخر ٣ أيام). لو مفيش رهان (الكارت
 * اتشاف وهو أوفلاين)، بيتسجّل صف «unasked» بالإجابة — مش رهان، والقياس بيعرضه لوحده. الكمية نفسها بيحركها الموبايل في نفس اللحظة من طريقه العادي
 * (adjustQuantity ⇐ zad_record_observation)، فالدالة دي مابتلمسش المخزن — ماعدا «لسه»: قراية بالكمية زي
 * ما هي (question_answer) عشان المعدل يعرف إن الصنف مانزلش، زي إجابة البوت.
 */
create or replace function public.zad_pantry_bet_answer(p_item_id uuid, p_answer text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_item record;
  v_bet uuid;
  v_today date;
begin
  if v_me is null then
    raise exception 'not_authenticated';
  end if;
  if p_answer is null or p_answer not in ('finished', 'used_one', 'still_have') then
    return jsonb_build_object('ok', false, 'reason', 'bad_answer');
  end if;

  select i.id, i.item_name, i.quantity into v_item
    from public.zad_inventory i
   where i.id = p_item_id
     and (i.user_id = v_me
          or (i.family_id is not null and i.family_id in (select public.get_my_family_ids())));
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  select b.id into v_bet
    from public.zad_pantry_bets b
   where b.user_id = v_me and b.item_id = p_item_id and b.answer is null
     and b.asked_at > now() - interval '3 days'
   order by b.asked_at desc
   limit 1
   for update;

  if v_bet is null then
    select (now() at time zone coalesce(public.zad_market_timezone(u.country), 'Africa/Cairo'))::date
      into v_today from public.zad_users u where u.id = v_me;
    insert into public.zad_pantry_bets (user_id, item_id, item_name, asked_on, confidence, answer, answered_at)
    values (v_me, p_item_id, v_item.item_name,
            coalesce(v_today, (now() at time zone 'Africa/Cairo')::date), 'unasked', p_answer, now())
    on conflict (user_id, item_id, asked_on)
      do update set answer = excluded.answer, answered_at = excluded.answered_at
    returning id into v_bet;
  else
    update public.zad_pantry_bets set answer = p_answer, answered_at = now() where id = v_bet;
  end if;

  if p_answer = 'still_have' then
    perform public.zad_record_observation(v_me, v_item.item_name, v_item.quantity, 'question_answer');
  end if;

  return jsonb_build_object('ok', true, 'bet', v_bet);
end;
$$;

revoke all on function public.zad_pantry_bet_answer(uuid, text) from public, anon;
grant execute on function public.zad_pantry_bet_answer(uuid, text) to authenticated, service_role;

/**
 * القياس الأسبوعي: من الرهانات اللي اتسألت في آخر [p_days] يوم (وعدّى عليها يوم): كام صاب («خلص»/«−١»)،
 * كام خاب («لسه»)، كام اتجاهل. للسيرفر بس (المالك/فريق زاد)، مش لعميل.
 */
create or replace function public.zad_pantry_bet_accuracy(p_days int default 7)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with b as (
    select * from public.zad_pantry_bets
     where asked_at > now() - make_interval(days => greatest(1, least(p_days, 90)))
       and asked_at < now() - interval '1 day'
  )
  select jsonb_build_object(
    'days', greatest(1, least(p_days, 90)),
    'asked', count(*),
    'homes', count(distinct user_id),
    'hit', count(*) filter (where answer in ('finished', 'used_one')),
    'miss', count(*) filter (where answer = 'still_have'),
    'ignored', count(*) filter (where answer is null),
    'hit_rate_of_answered', round(100.0 * count(*) filter (where answer in ('finished', 'used_one'))
                                  / nullif(count(*) filter (where answer is not null), 0)),
    'by_confidence', (select jsonb_object_agg(confidence, n) from (
                        select confidence, jsonb_build_object(
                                 'asked', count(*),
                                 'hit', count(*) filter (where answer in ('finished', 'used_one')),
                                 'miss', count(*) filter (where answer = 'still_have')) as n
                          from b group by confidence) x)
  ) from b;
$$;

revoke all on function public.zad_pantry_bet_accuracy(int) from public, anon, authenticated;
grant execute on function public.zad_pantry_bet_accuracy(int) to service_role;
