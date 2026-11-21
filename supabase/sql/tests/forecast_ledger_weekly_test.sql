-- Weekly accuracy of everything in zad_forecasts (migration 20261122130000, ZAD_OR_PLAN م٣.٦), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/forecasts_scaffold.sql
--   psql < supabase/sql/tests/forecast_runs_out_scaffold.sql
--   psql < supabase/migrations/20261026214500_forecast_ledger.sql
--   psql < supabase/migrations/20261026233000_forecast_runs_out.sql
--   psql < supabase/migrations/20261122130000_forecast_ledger_weekly.sql
--   psql < supabase/sql/tests/forecast_ledger_weekly_test.sql
--
-- Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
create table public.admin_messages (title text, body text);
create function public.zad_notify_admin(p_title text, p_body text) returns void language sql as $$
  insert into public.admin_messages values (p_title, p_body) $$;
insert into auth.users values ('00000000-0000-0000-0000-0000000000b1'), ('00000000-0000-0000-0000-0000000000b2');

-- Report "now" = 2026-11-23 10:00Z, window = the 7 days before it.
insert into public.zad_forecasts (user_id, kind, made_at, due_at, predicted, actual, recorded, settled_at, subject, outcome) values
  -- weekly_spend, in the window: two evidence weeks, two thin ones (nothing recorded; one expense only).
  ('00000000-0000-0000-0000-0000000000b1', 'weekly_spend', '2026-11-10Z', '2026-11-17Z', 100, 80, 5, '2026-11-17 23:17Z', null, null),
  ('00000000-0000-0000-0000-0000000000b2', 'weekly_spend', '2026-11-10Z', '2026-11-17Z', 100, 125, 4, '2026-11-17 23:17Z', null, null),
  ('00000000-0000-0000-0000-0000000000b1', 'weekly_spend', '2026-11-11Z', '2026-11-18Z', 90, 0, 0, '2026-11-18 23:17Z', null, null),
  ('00000000-0000-0000-0000-0000000000b2', 'weekly_spend', '2026-11-11Z', '2026-11-18Z', 50, 10, 1, '2026-11-18 23:17Z', null, null),
  -- outside the window (settled 10 days before) and still open: neither counts.
  ('00000000-0000-0000-0000-0000000000b1', 'weekly_spend', '2026-11-06Z', '2026-11-13Z', 999, 1, 9, '2026-11-13 10:00Z', null, null),
  ('00000000-0000-0000-0000-0000000000b2', 'weekly_spend', '2026-11-19Z', '2026-11-26Z', 70, null, null, null, null, null),
  -- runs_out, in the window: one of each judged outcome and three unknown; one outside the window.
  ('00000000-0000-0000-0000-0000000000b1', 'runs_out', '2026-11-12Z', '2026-11-18Z', 2, 3, null, '2026-11-19 23:17Z', 'رز', 'out'),
  ('00000000-0000-0000-0000-0000000000b1', 'runs_out', '2026-11-12Z', '2026-11-18Z', 2, null, null, '2026-11-19 23:17Z', 'زيت', 'still_had'),
  ('00000000-0000-0000-0000-0000000000b1', 'runs_out', '2026-11-12Z', '2026-11-18Z', 2, null, null, '2026-11-19 23:17Z', 'سكر', 'restocked'),
  ('00000000-0000-0000-0000-0000000000b1', 'runs_out', '2026-11-12Z', '2026-11-18Z', 2, null, null, '2026-11-19 23:17Z', 'شاي', 'unknown'),
  ('00000000-0000-0000-0000-0000000000b2', 'runs_out', '2026-11-12Z', '2026-11-18Z', 2, null, null, '2026-11-19 23:17Z', 'لبن', 'unknown'),
  ('00000000-0000-0000-0000-0000000000b2', 'runs_out', '2026-11-12Z', '2026-11-18Z', 2, null, null, '2026-11-19 23:17Z', 'عيش', 'unknown'),
  ('00000000-0000-0000-0000-0000000000b2', 'runs_out', '2026-11-01Z', '2026-11-07Z', 2, null, null, '2026-11-08 23:17Z', 'جبنة', 'unknown');
\set QUIET 0

\set now '''2026-11-23 10:00Z'''
select pg_temp.check((public.zad_forecast_ledger_weekly(:now) #>> '{weekly_spend,settled}')::int = 4,
  'only weeks settled inside the window count, open ones never');
select pg_temp.check((public.zad_forecast_ledger_weekly(:now) #>> '{weekly_spend,evidence}')::int = 2
                 and (public.zad_forecast_ledger_weekly(:now) #>> '{weekly_spend,thin}')::int = 2,
  'a week needs 3+ recorded expenses and a non-zero actual to be evidence');
select pg_temp.check((public.zad_forecast_ledger_weekly(:now) #>> '{weekly_spend,wape}')::numeric = 0.220,
  'wape over evidence weeks only: (20 + 25) / 205');
select pg_temp.check((public.zad_forecast_ledger_weekly(:now) #>> '{weekly_spend,bias}')::numeric = -0.024,
  'bias over evidence weeks only, negative = under-forecast: (200 - 205) / 205');
select pg_temp.check((public.zad_forecast_ledger_weekly(:now) #>> '{runs_out,settled}')::int = 6
                 and (public.zad_forecast_ledger_weekly(:now) #>> '{runs_out,unknown}')::int = 3
                 and (public.zad_forecast_ledger_weekly(:now) #>> '{runs_out,out}')::int = 1,
  'runs_out counts each outcome inside the window');
select pg_temp.check((public.zad_forecast_ledger_weekly(:now) #>> '{runs_out,judged_pct}')::int = 50,
  'judged share = the non-unknown ones: 3 of 6');
select pg_temp.check(public.zad_forecast_ledger_weekly('2026-12-30Z') #>> '{weekly_spend,wape}' is null
                 and (public.zad_forecast_ledger_weekly('2026-12-30Z') #>> '{runs_out,judged_pct}') is null,
  'an empty week reports nulls, not zero');

select pg_temp.check(public.zad_forecast_ledger_weekly_notify(:now) like '%منهم 2 دليل%الخطأ 22٪ والانحياز -2٪%اتحكم على 50٪%مجهول 3%',
  'the owner''s message carries the evidence count, error, bias and the judged share');
select pg_temp.check((select count(*) = 1 and min(title) = '📈 دقة التوقعات' from public.admin_messages),
  'one admin message per run');
select pg_temp.check(public.zad_forecast_ledger_weekly_notify('2026-12-30Z') like '%الخطأ مش محسوب%اتحكم على ولا واحد%',
  'an empty week says so instead of printing a number');

select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_forecast_ledger_weekly(timestamptz, int)', 'execute')
                 and not has_function_privilege('anon', 'public.zad_forecast_ledger_weekly_notify(timestamptz)', 'execute'),
  'neither function is callable by app users');
