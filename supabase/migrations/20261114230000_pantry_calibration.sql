-- خطة المخزن الواعي، الخطوة ٧ (المالك ١٤/١١): هدف دقة بيتقاس كل أسبوع، والأرقام المبدئية بتتظبط على كل بيت.
--
-- • zad_pantry_calibration: معامل لكل بيت (صاحب الحساب) بيضرب المعدل المبدئي (20261114200000). بيبدأ ١.
--   كل رهان بثقة 'prior' اتحكم عليه: «لسه» (still_have) = البيت بيستهلك أبطأ ⇒ ×٠٫٨٥؛ «خلص» (finished) = أسرع أو
--   زي المتوقع ⇒ ×١٫٠٥. «قليل»/«−١» صح ومش بيحرك. حدود ٠٫٣–٣ عشان رد غلط واحد مايبوّظش الحساب.
-- • zad_pantry_accuracy_weekly(): القياس الأسبوعي (zad_pantry_bet_accuracy) لرسالة المالك في تليجرام، والهدف
--   ٧٠٪ صح من اللي اتجاوب. كرون الاتنين ٩:٣٧ UTC.

create table if not exists public.zad_pantry_calibration (
  user_id uuid primary key references auth.users (id) on delete cascade,
  factor numeric not null default 1 check (factor between 0.3 and 3),
  hits int not null default 0,
  misses int not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.zad_pantry_calibration enable row level security;
revoke all on table public.zad_pantry_calibration from anon, authenticated;
grant all on table public.zad_pantry_calibration to service_role;

comment on table public.zad_pantry_calibration is
  'Pantry plan step 7 — per-home factor on the household prior, moved by every judged prior bet (still_have x0.85, finished x1.05). Written by the zad_pantry_calibrate trigger only.';

/** رهان 'prior' اتحكم عليه ⇒ معامل بيت صاحبه يتحرك. */
create or replace function private.zad_pantry_calibrate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_step numeric;
begin
  if new.confidence <> 'prior' or new.answer is null or old.answer is not null then
    return new;
  end if;
  v_step := case new.answer when 'still_have' then 0.85 when 'finished' then 1.05 else 1 end;
  insert into public.zad_pantry_calibration (user_id, factor, hits, misses)
  values (new.user_id, least(3, greatest(0.3, v_step)),
          case when new.answer = 'still_have' then 0 else 1 end,
          case when new.answer = 'still_have' then 1 else 0 end)
  on conflict (user_id) do update
    set factor = least(3, greatest(0.3, public.zad_pantry_calibration.factor * v_step)),
        hits = public.zad_pantry_calibration.hits + case when new.answer = 'still_have' then 0 else 1 end,
        misses = public.zad_pantry_calibration.misses + case when new.answer = 'still_have' then 1 else 0 end,
        updated_at = now();
  return new;
end;
$$;

revoke all on function private.zad_pantry_calibrate() from public, anon, authenticated;

drop trigger if exists zad_pantry_calibrate on public.zad_pantry_bets;
create trigger zad_pantry_calibrate
  after update of answer on public.zad_pantry_bets
  for each row execute function private.zad_pantry_calibrate();

/** الأيام الباقية بالمعدل المبدئي (20261114200000) × معايرة البيت. */
create or replace function private.zad_pantry_prior_days(p_user uuid)
returns table (item_id uuid, item_name text, days_left numeric, daily numeric, people int, held boolean)
language sql
stable
security definer
set search_path = public
as $$
  with fam as (
    select f.family_id from public.family_members f where f.user_id = p_user
  ),
  home as (
    select p_user as uid
    union
    select m.user_id from public.family_members m where m.family_id in (select family_id from fam) and m.user_id is not null
  ),
  ppl as (select private.zad_household_people(p_user) as n),
  -- معايرة البيت (20261114230000): «لسه» على تخمين = البيت بيستهلك أبطأ؛ «خلص» = أسرع.
  cal as (select coalesce((select c.factor from public.zad_pantry_calibration c where c.user_id = p_user), 1) as f),
  inv as (
    select i.id, i.item_name, i.quantity, i.created_at,
           private.zad_product_canonical_for(p_user, i.item_name) as canon,
           private.zad_pantry_prior_daily(i.item_name, i.unit, (select n from ppl)) * (select f from cal) as daily
      from public.zad_inventory i
     where (i.user_id = p_user or (i.family_id is not null and i.family_id in (select family_id from fam)))
       and i.quantity > 0
       and i.restock_mode is distinct from 'occasional'
     limit 400
  ),
  learned as (
    select inv.id
      from inv
      join public.zad_consumption c
        on c.user_id in (select uid from home) and c.item_name in (inv.canon, inv.item_name) and c.avg_daily_qty > 0
     group by inv.id
  ),
  seen as (
    select inv.id,
           max(o.observed_at) as last_at,
           count(distinct (o.observed_at at time zone 'UTC')::date)
             filter (where o.source in ('purchase', 'camera_ocr', 'chat_add')
                       and o.observed_at > now() - interval '180 days') as bought_days
      from inv
      join public.zad_inventory_observations o
        on o.user_id in (select uid from home) and o.item_name in (inv.canon, inv.item_name)
     where inv.daily > 0
     group by inv.id
  )
  select inv.id, inv.item_name,
         greatest(0, round(inv.quantity / inv.daily
                           - extract(epoch from now() - coalesce(greatest(s.last_at, inv.created_at), now()))::numeric / 86400, 1)),
         inv.daily,
         (select n from ppl),
         exists (
           select 1 from public.zad_pantry_bets b
            where b.user_id in (select uid from home) and b.item_id = inv.id
              and b.answer = 'still_have' and b.answered_at > now() - interval '3 days')
    from inv
    left join seen s on s.id = inv.id
   where inv.daily > 0
     and coalesce(s.bought_days, 0) < 3
     and not exists (select 1 from learned l where l.id = inv.id);
$$;


revoke all on function private.zad_pantry_prior_days(uuid) from public, anon, authenticated;

/** القياس الأسبوعي للمالك: نسبة الصح من اللي اتجاوب قصاد هدف ٧٠٪، ولكل ثقة لوحدها. */
create or replace function public.zad_pantry_accuracy_weekly()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  a jsonb := public.zad_pantry_bet_accuracy(7);
  v_rate int := (a ->> 'hit_rate_of_answered')::int;
  v_body text;
begin
  v_body := format('اتسأل %s سؤال في %s بيت: صح %s، غلط %s، اتجاهل %s. الدقة %s (الهدف ٧٠٪).%s',
    coalesce(a ->> 'asked', '0'), coalesce(a ->> 'homes', '0'), coalesce(a ->> 'hit', '0'), coalesce(a ->> 'miss', '0'),
    coalesce(a ->> 'ignored', '0'),
    case when v_rate is null then 'مش محسوبة — محدش جاوب' else v_rate || '٪' end,
    case when a -> 'by_confidence' is null or a -> 'by_confidence' = 'null'::jsonb then ''
         else chr(10) || 'حسب الأساس: ' || (a -> 'by_confidence')::text end);
  perform public.zad_notify_admin(
    case when v_rate is not null and v_rate >= 70 then '✅ دقة المخزن' else '📦 دقة المخزن' end, v_body);
  return v_body;
exception when others then
  -- رسالة للمالك مش لازم تكسر الكرون.
  return 'failed: ' || sqlerrm;
end;
$$;

revoke all on function public.zad_pantry_accuracy_weekly() from public, anon, authenticated;
grant execute on function public.zad_pantry_accuracy_weekly() to service_role;

do $cron$
begin
  if to_regnamespace('cron') is null then
    return;
  end if;
  perform cron.unschedule(jobid) from cron.job where jobname = 'pantry-accuracy-weekly';
  perform cron.schedule('pantry-accuracy-weekly', '37 9 * * 1', 'select public.zad_pantry_accuracy_weekly();');
end
$cron$;
