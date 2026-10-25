-- رقم التكلفة (ZAD_PLAN ٣.٨): تكلفة الذكاء لكل بيت في الشهر وزمن الرد في لوحة الحقيقة.
--
-- • zad_model_prices — سعر كل موديل (دولار لكل مليون توكن، الطبقة المدفوعة Standard) بمصدره وتاريخه. اتملى
--   بس باللي مكتوب في صفحة جوجل الرسمية (https://ai.google.dev/gemini-api/docs/pricing، «Last updated
--   2026-10-22»). gemini-3.5-flash مش مكتوب هناك، وسعر Groq مش ظاهر في صفحتهم: مالهمش صف، ولفاتهم
--   بتتعدّ «مالهاش سعر» بدل رقم متخمّن. التكلفة دي «لو كانت على المدفوع» — مفاتيح المجمّع المجاني بصفر فعلياً.
-- • اللفة بتتسعّر بأغلى موديل ردّ فيها (prompt_sizes.calls.models) — حد أعلى، مش أقل من الحقيقة.
-- • zad_health_daily: brain_p90_secs، brain_fast_runs (تحت ٦ ثواني — بوابة المرحلة ٣: ٩٠٪)، brain_cost_usd،
--   brain_unpriced_runs. بيتملوا بـzad_health_brain_cost بعد zad_health_snapshot في نفس الكرون.
-- • zad_brain_cost_monthly(month) — لكل بيت: اللفات، التكلفة، اللي مالوش سعر، p90، ونسبة السريع.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

create table if not exists public.zad_model_prices (
  model text not null,
  valid_from date not null default '2025-01-01',
  valid_until date,
  input_usd_per_m numeric not null check (input_usd_per_m >= 0),
  output_usd_per_m numeric not null check (output_usd_per_m >= 0),
  source text not null,
  as_of date not null,
  primary key (model, valid_from)
);

alter table public.zad_model_prices enable row level security;
revoke all on public.zad_model_prices from anon, authenticated;
grant all on public.zad_model_prices to service_role;

insert into public.zad_model_prices (model, valid_from, valid_until, input_usd_per_m, output_usd_per_m, source, as_of) values
  ('gemini-3.5-flash-lite', '2025-01-01', null, 0.30, 2.50, 'https://ai.google.dev/gemini-api/docs/pricing', '2026-10-22'),
  ('gemini-3.1-flash-lite', '2025-01-01', null, 0.25, 1.50, 'https://ai.google.dev/gemini-api/docs/pricing', '2026-10-22'),
  ('gemini-3-flash-preview', '2025-01-01', null, 0.50, 3.00, 'https://ai.google.dev/gemini-api/docs/pricing', '2026-10-22'),
  ('gemini-3.6-flash', '2025-01-01', '2026-12-31', 0.75, 3.75, 'https://ai.google.dev/gemini-api/docs/pricing', '2026-10-22'),
  ('gemini-3.6-flash', '2027-01-01', null, 1.50, 7.50, 'https://ai.google.dev/gemini-api/docs/pricing', '2026-10-22')
on conflict (model, valid_from) do nothing;

alter table public.zad_health_daily
  add column if not exists brain_p90_secs numeric,
  add column if not exists brain_fast_runs int not null default 0,
  add column if not exists brain_cost_usd numeric(12, 6),
  add column if not exists brain_unpriced_runs int not null default 0;

/** تكلفة لفة واحدة بأغلى موديل فيها، أو null لو أي موديل مالوش سعر أو مفيش موديلات متسجلة. */
create or replace function public.zad_run_cost_usd(p_models jsonb, p_in bigint, p_out bigint, p_at timestamptz)
returns numeric
language sql
stable
set search_path to 'public'
as $$
  with m as (
    select distinct value as model
      from jsonb_array_elements_text(case when jsonb_typeof(p_models) = 'array' then p_models else '[]'::jsonb end)
  ),
  priced as (
    select m.model, (coalesce(p_in, 0) * pr.input_usd_per_m + coalesce(p_out, 0) * pr.output_usd_per_m) / 1e6 as usd
      from m left join public.zad_model_prices pr
        on pr.model = m.model and p_at::date >= pr.valid_from and (pr.valid_until is null or p_at::date <= pr.valid_until)
  )
  select case when not exists (select 1 from m) or exists (select 1 from priced where usd is null) then null
              else (select max(usd) from priced) end;
$$;

revoke all on function public.zad_run_cost_usd(jsonb, bigint, bigint, timestamptz) from public, anon, authenticated;
grant execute on function public.zad_run_cost_usd(jsonb, bigint, bigint, timestamptz) to service_role;

create or replace function public.zad_health_brain_cost(p_day date default ((now() at time zone 'utc')::date - 1))
returns int
language sql
security definer
set search_path to 'public'
as $$
  with b as (
    select (p_day::timestamp at time zone 'utc') as t0, ((p_day + 1)::timestamp at time zone 'utc') as t1
  ),
  r as (
    select br.user_id,
           extract(epoch from br.finished_at - br.started_at) as secs,
           public.zad_run_cost_usd(br.prompt_sizes -> 'calls' -> 'models', br.input_tokens, br.output_tokens, br.started_at) as usd
      from public.zad_brain_runs br, b
     where br.started_at >= b.t0 and br.started_at < b.t1 and br.finished_at is not null
  ),
  agg as (
    select user_id,
           round((percentile_cont(0.9) within group (order by secs))::numeric, 1) as p90,
           count(*) filter (where secs < 6)::int as fast,
           round(sum(usd)::numeric, 6) as usd,
           count(*) filter (where usd is null)::int as unpriced
      from r group by user_id
  ),
  up as (
    update public.zad_health_daily h
       set brain_p90_secs = agg.p90, brain_fast_runs = agg.fast, brain_cost_usd = agg.usd, brain_unpriced_runs = agg.unpriced
      from agg
     where h.day = p_day and h.user_id = agg.user_id
    returning 1
  )
  select count(*)::int from up;
$$;

revoke all on function public.zad_health_brain_cost(date) from public, anon, authenticated;
grant execute on function public.zad_health_brain_cost(date) to service_role;

create or replace function public.zad_brain_cost_monthly(p_month date default date_trunc('month', now() at time zone 'utc')::date)
returns table (user_id uuid, month date, runs int, cost_usd numeric, unpriced_runs int, p90_secs numeric, fast_pct int)
language sql
stable
security definer
set search_path to 'public'
as $$
  with r as (
    select br.user_id,
           extract(epoch from br.finished_at - br.started_at) as secs,
           public.zad_run_cost_usd(br.prompt_sizes -> 'calls' -> 'models', br.input_tokens, br.output_tokens, br.started_at) as usd
      from public.zad_brain_runs br
     where br.started_at >= date_trunc('month', p_month)::timestamp at time zone 'utc'
       and br.started_at < (date_trunc('month', p_month) + interval '1 month')::timestamp at time zone 'utc'
       and br.finished_at is not null
  )
  select r.user_id, date_trunc('month', p_month)::date, count(*)::int, round(sum(r.usd)::numeric, 4),
         count(*) filter (where r.usd is null)::int,
         round((percentile_cont(0.9) within group (order by r.secs))::numeric, 1),
         round(100.0 * count(*) filter (where r.secs < 6) / greatest(count(*), 1))::int
    from r group by r.user_id order by 4 desc nulls last;
$$;

revoke all on function public.zad_brain_cost_monthly(date) from public, anon, authenticated;
grant execute on function public.zad_brain_cost_monthly(date) to service_role;

-- آخر ١٤ يوم ياخدوا الأعمدة الجديدة.
do $backfill$
declare d date;
begin
  for d in select generate_series((now() at time zone 'utc')::date - 14, (now() at time zone 'utc')::date - 1, interval '1 day')::date loop
    perform public.zad_health_brain_cost(d);
  end loop;
end
$backfill$;

do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.schedule('health-daily', '41 5 * * *',
    'select public.zad_health_snapshot(); select public.zad_health_brain_cost();');
end
$cron$;
