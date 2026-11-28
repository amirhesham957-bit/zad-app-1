-- P3.5: كل توقع بنطاق (low..high) بيتقفل تلقائي بالفعلي، وقياس تغطية النطاق.
--
--   • الأسبوع: النطاق = p20..p80 من آخر ≤ ٨ أسابيع اتقفلت بدليل (٣ مصاريف+ والفعلي > ٠) لنفس العميل، بشرط ≥ ٤ أسابيع،
--     وبيتوسّع عشان يشمل الرقم المتوقع. أقل من كده = من غير نطاق (low/high null) ومايتخترعش.
--   • «هيخلص»: النطاق = اليوم المتوقع ± وسيط الغلط بالأيام في توقعات العميل اللي خلصت فعلاً، بشرط ≥ ٥ أحكام.
--   • in_range بيتحط وقت القفل (zad_forecasts_tick). بس للتوقعات اللي ليها نطاق وحكم له دليل.
--   • zad_forecast_range_coverage: نسبة اللي الفعلي وقع جوه نطاقها. الاسمي ٦٠٪ للأسبوع (p20..p80) و٥٠٪ لـ«هيخلص»
--     (وسيط الغلط بيغطي نص الحالات بالتعريف). تغطية بعيدة عن الاسمي = النطاق ضيق أو واسع، ومايتقالش للعميل كأنه مضمون.
--   • مفيش حاجة بتظهر للعميل هنا: أعمدة وقياس بس.

alter table public.zad_forecasts add column if not exists low numeric check (low is null or low >= 0);
alter table public.zad_forecasts add column if not exists high numeric check (high is null or high >= 0);
alter table public.zad_forecasts add column if not exists range_basis text check (range_basis is null or char_length(range_basis) <= 200);
alter table public.zad_forecasts add column if not exists in_range boolean;
alter table public.zad_forecasts drop constraint if exists zad_forecasts_range;
alter table public.zad_forecasts add constraint zad_forecasts_range
  check ((low is null) = (high is null) and (low is null or (low <= high and range_basis is not null)));

/** نطاق الأسبوع من تاريخ العميل: {n, p20, p80}. */
create or replace function public.zad_forecast_band_weekly(p_user uuid)
returns jsonb
language sql
stable
set search_path to 'public'
as $fn$
  select jsonb_build_object('n', count(*), 'p20', percentile_cont(0.2) within group (order by actual),
                            'p80', percentile_cont(0.8) within group (order by actual))
    from (select actual from public.zad_forecasts
           where user_id = p_user and kind = 'weekly_spend' and settled_at is not null and recorded >= 3 and actual > 0
           order by settled_at desc limit 8) w;
$fn$;

/** غلط «هيخلص» بالأيام: وسيط |الفعلي − المتوقع| للي خلص فعلاً. m = null لو أقل من ٥ أحكام. */
create or replace function public.zad_forecast_slack_runs_out(p_user uuid)
returns table (m numeric, n int)
language sql
stable
set search_path to 'public'
as $fn$
  select case when count(*) >= 5 then round((percentile_cont(0.5) within group (order by abs(actual - predicted)))::numeric, 1) end,
         count(*)::int
    from public.zad_forecasts
   where user_id = p_user and kind = 'runs_out' and outcome = 'out' and actual is not null;
$fn$;

create or replace function public.zad_forecasts_tick(p_now timestamptz default now())
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_settled int;
  v_settled_out int;
  v_made int;
  v_made_out int;
begin
  -- ── صرف الأسبوع (20261026214500، من غير تغيير) ──
  with due as (
    select f.id,
           coalesce(sum(t.amount) filter (where t.id is not null), 0) as spent,
           count(t.id) as n
      from public.zad_forecasts f
      left join public.zad_transactions t
        on t.user_id = f.user_id and t.is_expense
       and t.created_at >= f.made_at and t.created_at < f.due_at
     where f.settled_at is null and f.due_at <= p_now and f.kind = 'weekly_spend'
     group by f.id
  )
  update public.zad_forecasts f
     set actual = round(due.spent::numeric, 2), recorded = due.n, settled_at = p_now
    from due where f.id = due.id;
  get diagnostics v_settled = row_count;

  -- ── «هيخلص»: الحكم من إجابات البيت بين التوقع والقفل ──
  with due as (
    select f.id,
           min(o.observed_at) filter (where o.qty = 0) as first_zero,
           bool_or(o.qty > 0 and o.source <> 'purchase'
                   and o.observed_at >= f.made_at + make_interval(days => f.predicted::int)) as had_after,
           bool_or(o.source = 'purchase') as bought,
           count(o.id) as n,
           f.made_at
      from public.zad_forecasts f
      left join public.zad_inventory_observations o
        on o.user_id = f.user_id
       and public.zad_inventory_name_key(o.item_name) = public.zad_inventory_name_key(f.subject)
       and o.observed_at > f.made_at and o.observed_at <= f.due_at
     where f.settled_at is null and f.due_at <= p_now and f.kind = 'runs_out'
     group by f.id
  )
  update public.zad_forecasts f
     set outcome = case when due.first_zero is not null then 'out'
                        when coalesce(due.had_after, false) then 'still_had'
                        when coalesce(due.bought, false) then 'restocked'
                        else 'unknown' end,
         actual = case when due.first_zero is not null
                       then round((extract(epoch from due.first_zero - due.made_at) / 86400)::numeric, 1) end,
         recorded = due.n,
         settled_at = p_now
    from due where f.id = due.id;
  get diagnostics v_settled_out = row_count;

  -- ── فتح توقع الأسبوع: نفس بوابة spend_forecast (ملف أقدم من ١٤ يوم أو متوسط صفر = مفيش أساس) ──
  insert into public.zad_forecasts (user_id, kind, made_at, due_at, predicted, basis, low, high, range_basis)
  select b.user_id, 'weekly_spend', p_now, p_now + interval '7 days', b.avg_weekly_spending,
         jsonb_build_object('source', 'user_behavior_profile.avg_weekly_spending', 'profile_at', b.last_updated_at),
         case when (w.band ->> 'n')::int >= 4 then round(least((w.band ->> 'p20')::numeric, b.avg_weekly_spending), 2) end,
         case when (w.band ->> 'n')::int >= 4 then round(greatest((w.band ->> 'p80')::numeric, b.avg_weekly_spending), 2) end,
         case when (w.band ->> 'n')::int >= 4 then format('p20-p80 of %s settled weeks with evidence', w.band ->> 'n') end
    from public.user_behavior_profile b
   cross join lateral (select public.zad_forecast_band_weekly(b.user_id) as band) w
   where b.avg_weekly_spending > 0
     and b.last_updated_at > p_now - interval '14 days'
     and exists (select 1 from auth.users u where u.id = b.user_id)
     and not exists (
       select 1 from public.zad_forecasts f
        where f.user_id = b.user_id and f.kind = 'weekly_spend' and f.settled_at is null
     );
  get diagnostics v_made = row_count;

  -- ── فتح «هيخلص» من حالة بيت اتحسبت آخر يوم ──
  insert into public.zad_forecasts (user_id, kind, subject, made_at, due_at, predicted, basis, low, high, range_basis)
  select distinct on (h.user_id, public.zad_inventory_name_key(r.name))
         h.user_id, 'runs_out', left(r.name, 80), p_now,
         p_now + make_interval(days => greatest(r.days, 0) + 3), greatest(r.days, 0),
         jsonb_build_object('source', 'zad_home_state.pantry.running_out', 'approx', coalesce(r.approx, true),
                            'state_at', h.computed_at),
         case when sl.m is not null then greatest(0, greatest(r.days, 0) - sl.m) end,
         case when sl.m is not null then greatest(r.days, 0) + sl.m end,
         case when sl.m is not null then format('predicted +/- median miss (%s days) of %s judged run-outs', sl.m, sl.n) end
    from public.zad_home_state h
   cross join lateral (select * from public.zad_forecast_slack_runs_out(h.user_id)) sl
   cross join lateral jsonb_to_recordset(coalesce(h.state -> 'pantry' -> 'running_out', '[]'::jsonb))
         as r(name text, days int, approx boolean)
   where h.computed_at > p_now - interval '1 day'
     and char_length(trim(coalesce(r.name, ''))) between 1 and 80
     and r.days is not null and r.days between 0 and 7
     and exists (select 1 from auth.users u where u.id = h.user_id)
     and not exists (
       select 1 from public.zad_forecasts f
        where f.user_id = h.user_id and f.kind = 'runs_out'
          and public.zad_inventory_name_key(f.subject) = public.zad_inventory_name_key(r.name)
          and (f.settled_at is null or f.made_at > p_now - interval '7 days')
     )
   order by h.user_id, public.zad_inventory_name_key(r.name), r.days;
  get diagnostics v_made_out = row_count;

  -- النطاق اتغطّى؟ بس لو التوقع كان له نطاق، والحكم له دليل (أسبوع فيه ٣ مصاريف+ والفعلي > ٠، أو «هيخلص» خلص فعلاً).
  update public.zad_forecasts f
     set in_range = case
           when f.kind = 'weekly_spend' then case when f.recorded >= 3 and f.actual > 0 then f.actual between f.low and f.high end
           when f.kind = 'runs_out' then case when f.outcome = 'out' then f.actual between f.low and f.high end
         end
   where f.settled_at = p_now and f.low is not null and f.in_range is null;

  return jsonb_build_object('settled', v_settled, 'made', v_made, 'settled_runs_out', v_settled_out, 'made_runs_out', v_made_out);
end
$fn$;

revoke all on function public.zad_forecasts_tick(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_forecasts_tick(timestamptz) to service_role;
revoke all on function public.zad_forecast_band_weekly(uuid) from public, anon, authenticated;
revoke all on function public.zad_forecast_slack_runs_out(uuid) from public, anon, authenticated;
grant execute on function public.zad_forecast_band_weekly(uuid), public.zad_forecast_slack_runs_out(uuid) to service_role;

/** تغطية النطاق لكل نوع في آخر p_days يوم: كام حكم، كام وقع جوه النطاق، والنسبة مقابل الاسمي. */
create or replace function public.zad_forecast_range_coverage(p_now timestamptz default now(), p_days int default 90)
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $fn$
  select coalesce(jsonb_object_agg(k.kind, jsonb_build_object(
           'judged', k.judged, 'covered', k.covered,
           'coverage_pct', round(100.0 * k.covered / nullif(k.judged, 0)),
           'nominal_pct', case k.kind when 'weekly_spend' then 60 else 50 end,
           'enough', k.judged >= 5)), '{}'::jsonb)
    from (select kind, count(*) filter (where in_range is not null) as judged, count(*) filter (where in_range) as covered
            from public.zad_forecasts
           where settled_at is not null and settled_at > p_now - make_interval(days => p_days) and settled_at <= p_now
           group by kind) k;
$fn$;
revoke all on function public.zad_forecast_range_coverage(timestamptz, int) from public, anon, authenticated;
grant execute on function public.zad_forecast_range_coverage(timestamptz, int) to service_role;
