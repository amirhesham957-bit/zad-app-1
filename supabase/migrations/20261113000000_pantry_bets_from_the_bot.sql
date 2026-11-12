-- ZAD_PLAN ١٠.١ الشريحة ٤ (ب): سؤال البوت بالليل «لسه عندك؟» رهان هو كمان، في نفس zad_pantry_bets.
--
-- البوت بيسأل من جدول تاني (telegram_checkin_prompts، ٢١ سؤال في آخر ٣٠ يوم على الحي) وبيقرر يسأل بقاعدته
-- هو (checkInPriority: المعدل، أو دورة الشرا لو مفيش معدل). من غير الربط ده، القياس الأسبوعي
-- (zad_pantry_bet_accuracy) كان هيشوف أسئلة الموبايل بس، و«لسه» من تليجرام ماكانتش بتسكّت كارت الرئيسية.
--
-- الربط بتريجر على telegram_checkin_prompts، مش في كود البوت: أي طريق بيكتب سؤال أو إجابة (الكرون اليومي،
-- السؤال الفوري، الزرار، الرد بالكلام) بيتسجل من غير ما حد يفتكر.
--   • سؤال اتبعت ⇒ رهان channel = 'telegram' بالأيام الباقية حسب المعدل (أو 'cycle' لو البوت سأل بالدورة).
--     لو الموبايل فتح رهان لنفس الصنف النهارده، السؤال بيتربط بيه بدل ما يتعمل رهان تاني.
--   • إجابة ⇒ الحكم: «خلص» = finished، «قليل» (answer_fraction ≤ ٠٫٢٥) = low (صاب: كان قرب يخلص فعلاً)،
--     «كتير/نصه/زي ما هو» = still_have (خاب). انتهى من غير رد ⇒ يفضل من غير إجابة (اتجاهل).
--   • البوت بيكتب answer_fraction جنب الحالة؛ الحالة لوحدها (answered_yes) مابتفرّقش بين «قليل» و«كتير».

alter table public.zad_pantry_bets
  add column if not exists channel text not null default 'app',
  add column if not exists prompt_id uuid;

alter table public.zad_pantry_bets drop constraint if exists zad_pantry_bets_channel_check;
alter table public.zad_pantry_bets add constraint zad_pantry_bets_channel_check check (channel in ('app', 'telegram'));
alter table public.zad_pantry_bets drop constraint if exists zad_pantry_bets_answer_check;
alter table public.zad_pantry_bets add constraint zad_pantry_bets_answer_check
  check (answer is null or answer in ('finished', 'used_one', 'low', 'still_have'));
alter table public.zad_pantry_bets drop constraint if exists zad_pantry_bets_confidence_check;
alter table public.zad_pantry_bets add constraint zad_pantry_bets_confidence_check
  check (confidence in ('known', 'approximate', 'cycle', 'unasked'));
create unique index if not exists zad_pantry_bets_prompt on public.zad_pantry_bets (prompt_id) where prompt_id is not null;

alter table public.telegram_checkin_prompts
  add column if not exists answer_fraction numeric check (answer_fraction is null or (answer_fraction >= 0 and answer_fraction <= 1));

create or replace function private.zad_pantry_bet_from_prompt()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_rate double precision;
  v_known boolean;
  v_today date;
begin
  if tg_op = 'INSERT' then
    select i.id, i.item_name, i.quantity into v_item
      from public.zad_inventory i
     where i.user_id = new.user_id and i.item_name = new.item_name
     order by i.created_at desc nulls last
     limit 1;
    if not found then
      return new;
    end if;

    select max(c.avg_daily_qty) filter (where c.avg_daily_qty > 0), bool_or(c.rate_known and c.avg_daily_qty > 0)
      into v_rate, v_known
      from public.zad_consumption c
     where c.user_id = new.user_id
       and c.item_name in (v_item.item_name, private.zad_product_canonical_for(new.user_id, v_item.item_name));

    select (new.sent_at at time zone coalesce(public.zad_market_timezone(u.country), 'Africa/Cairo'))::date
      into v_today from public.zad_users u where u.id = new.user_id;

    insert into public.zad_pantry_bets
      (user_id, item_id, item_name, asked_on, asked_at, predicted_days_left, confidence, channel, prompt_id)
    values
      (new.user_id, v_item.id, v_item.item_name,
       coalesce(v_today, (new.sent_at at time zone 'Africa/Cairo')::date), new.sent_at,
       case when v_rate > 0 then round(greatest(coalesce(new.quantity_at_prompt, v_item.quantity), 0) / v_rate::numeric, 1) end,
       case when v_rate > 0 then case when v_known then 'known' else 'approximate' end else 'cycle' end,
       'telegram', new.id)
    on conflict on constraint zad_pantry_bets_one_a_day
      do update set prompt_id = coalesce(public.zad_pantry_bets.prompt_id, excluded.prompt_id);
    return new;
  end if;

  if new.status in ('answered_yes', 'answered_no') and old.status is distinct from new.status then
    update public.zad_pantry_bets b
       set answer = case
                      when new.status = 'answered_no' or new.answer_fraction = 0 then 'finished'
                      when new.answer_fraction is not null and new.answer_fraction <= 0.25 then 'low'
                      else 'still_have'
                    end,
           answered_at = coalesce(new.answered_at, now())
     where b.prompt_id = new.id and b.answer is null;
  end if;
  return new;
end;
$$;

revoke all on function private.zad_pantry_bet_from_prompt() from public, anon, authenticated;

drop trigger if exists zad_pantry_bet_from_prompt on public.telegram_checkin_prompts;
create trigger zad_pantry_bet_from_prompt
  after insert or update of status on public.telegram_checkin_prompts
  for each row execute function private.zad_pantry_bet_from_prompt();

-- القياس: «قليل» صاب، وكل قناة لوحدها.
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
    'hit', count(*) filter (where answer in ('finished', 'used_one', 'low')),
    'miss', count(*) filter (where answer = 'still_have'),
    'ignored', count(*) filter (where answer is null),
    'hit_rate_of_answered', round(100.0 * count(*) filter (where answer in ('finished', 'used_one', 'low'))
                                  / nullif(count(*) filter (where answer is not null), 0)),
    'by_confidence', (select jsonb_object_agg(confidence, n) from (
                        select confidence, jsonb_build_object(
                                 'asked', count(*),
                                 'hit', count(*) filter (where answer in ('finished', 'used_one', 'low')),
                                 'miss', count(*) filter (where answer = 'still_have')) as n
                          from b group by confidence) x),
    'by_channel', (select jsonb_object_agg(channel, n) from (
                     select channel, jsonb_build_object(
                              'asked', count(*),
                              'hit', count(*) filter (where answer in ('finished', 'used_one', 'low')),
                              'miss', count(*) filter (where answer = 'still_have'),
                              'ignored', count(*) filter (where answer is null)) as n
                       from b group by channel) y)
  ) from b;
$$;

revoke all on function public.zad_pantry_bet_accuracy(int) from public, anon, authenticated;
grant execute on function public.zad_pantry_bet_accuracy(int) to service_role;

-- الأمان (مراجعة security-audit ١٢/١١): السياسة القديمة user_own_checkin_prompts كانت ALL، فالعميل يقدر يكتب
-- أسئلة وإجابات لنفسه — وبالتريجر فوق ده بقى معناه رهانات مزيفة في القياس. التطبيق عمره ما كتب في الجدول ده؛
-- اللي بيكتب البوت والعقل بـservice role بس (zad-telegram-bot، _shared/outbound.ts بيقرا). العميل يقرا بس.
drop policy if exists user_own_checkin_prompts on public.telegram_checkin_prompts;
drop policy if exists telegram_checkin_prompts_own_read on public.telegram_checkin_prompts;
create policy telegram_checkin_prompts_own_read on public.telegram_checkin_prompts for select to authenticated
  using ((select auth.uid()) = user_id);
revoke insert, update, delete, truncate on table public.telegram_checkin_prompts from anon, authenticated;
