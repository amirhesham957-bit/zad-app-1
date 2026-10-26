-- spend_forecast says its measured accuracy (migration 20261026223500, ZAD_PLAN 5.5), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/forecasts_scaffold.sql
--   psql < supabase/sql/tests/forecast_said_scaffold.sql
--   psql < supabase/migrations/20261026214500_forecast_ledger.sql
--   psql < supabase/migrations/20261026223500_forecast_accuracy_said.sql
--   psql < supabase/sql/tests/forecast_said_test.sql
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
-- a1: three settled weeks in the ledger; a2: new, nothing measured. Both short this week.
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2');
insert into public.zad_users (id, currency) values
  ('00000000-0000-0000-0000-0000000000a1', 'SAR'), ('00000000-0000-0000-0000-0000000000a2', 'EGP');
insert into public.user_behavior_profile values
  ('00000000-0000-0000-0000-0000000000a1', 1000, now() - interval '1 hour'),
  ('00000000-0000-0000-0000-0000000000a2', 500, now() - interval '1 hour');
insert into public.test_balance values
  ('00000000-0000-0000-0000-0000000000a1', 400), ('00000000-0000-0000-0000-0000000000a2', 100);
insert into public.zad_forecasts (user_id, kind, made_at, due_at, predicted, actual, recorded, settled_at) values
  ('00000000-0000-0000-0000-0000000000a1', 'weekly_spend', now() - interval '28 days', now() - interval '21 days', 1000, 700, 2, now() - interval '21 days'),
  ('00000000-0000-0000-0000-0000000000a1', 'weekly_spend', now() - interval '21 days', now() - interval '14 days', 1000, 1100, 2, now() - interval '14 days'),
  ('00000000-0000-0000-0000-0000000000a1', 'weekly_spend', now() - interval '14 days', now() - interval '7 days', 1000, 2000, 1, now() - interval '7 days'),
  ('00000000-0000-0000-0000-0000000000a2', 'weekly_spend', now() - interval '14 days', now() - interval '7 days', 500, 0, 0, now() - interval '7 days');
\set QUIET 0

select public._agent_spend_forecast_for_user('00000000-0000-0000-0000-0000000000a1');
select public._agent_spend_forecast_for_user('00000000-0000-0000-0000-0000000000a2');
select pg_temp.check((select task_description like '%المتوقع يخرج 1000.00 SAR والمتاح دلوقتي 400.00 SAR%' from public.agent_tasks
  where user_id = '00000000-0000-0000-0000-0000000000a1'), 'the forecast itself is unchanged');
select pg_temp.check((select task_description like '%آخر 3 أسابيع اتقاسوا، الفرق بين المتوقع واللي اتصرف فعلاً كان حوالي 43٪ (الوسيط)، و1 منهم جم في حدود ٢٥٪.' from public.agent_tasks
  where user_id = '00000000-0000-0000-0000-0000000000a1'), 'a measured home hears the median error and the weeks within 25%');
select pg_temp.check((select task_description like '%لسه ماتقاسش على صرفك الفعلي%' from public.agent_tasks
  where user_id = '00000000-0000-0000-0000-0000000000a2'), 'a home with no recorded week hears the forecast is not measured yet');
select pg_temp.check((select count(*) from public.agent_tasks) = 2, 'one alert per home');
