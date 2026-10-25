-- سقف الذكاء الاصطناعي (migration 20261025193500, ZAD_PLAN 8.2), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/brain_cost_scaffold.sql
--   psql < supabase/migrations/20261025050500_brain_cost.sql
--   psql < supabase/sql/tests/ai_budget_scaffold.sql
--   psql < supabase/migrations/20261025193500_ai_budget.sql
--   psql < supabase/sql/tests/ai_budget_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
\set a '''00000000-0000-0000-0000-0000000000a1'''
update public.zad_ai_budget set monthly_cap_usd = 10;
-- 7.50 USD in November: three runs of 2.50 output tokens each on 3.5 lite (1M out = 2.50).
insert into public.zad_brain_runs (user_id, trigger, status, started_at, finished_at, input_tokens, output_tokens, prompt_sizes) values
  (:a, 'chat', 'success', '2026-11-02 10:00:00+00', '2026-11-02 10:00:02+00', 0, 1000000, '{"calls":{"models":["gemini-3.5-flash-lite"]}}'),
  (:a, 'chat', 'success', '2026-11-03 10:00:00+00', '2026-11-03 10:00:02+00', 0, 1000000, '{"calls":{"models":["gemini-3.5-flash-lite"]}}'),
  (:a, 'chat', 'success', '2026-11-04 10:00:00+00', '2026-11-04 10:00:02+00', 0, 1000000, '{"calls":{"models":["gemini-3.5-flash-lite"]}}'),
  -- October's spend does not count toward November
  (:a, 'chat', 'success', '2026-10-30 10:00:00+00', '2026-10-30 10:00:02+00', 0, 9000000, '{"calls":{"models":["gemini-3.5-flash-lite"]}}');
\set QUIET 0

select pg_temp.check((public.zad_ai_budget_check('2026-11-05 06:00+00') ->> 'alerted')::boolean = false, '75% of the cap: no alert yet');
select pg_temp.check((select count(*) from public.notified) = 0, 'nobody was told');

insert into public.zad_brain_runs (user_id, trigger, status, started_at, finished_at, input_tokens, output_tokens, prompt_sizes) values
  (:a, 'chat', 'success', '2026-11-05 10:00:00+00', '2026-11-05 10:00:02+00', 0, 400000, '{"calls":{"models":["gemini-3.5-flash-lite"]}}');
select pg_temp.check(public.zad_ai_budget_check('2026-11-06 06:00+00') ->> 'kind' = 'ai_budget_80', '85% of the cap: the 80% alert');
select pg_temp.check((select count(*) from public.notified where title like '%قرّب%') = 1, 'the owner is told once');
select pg_temp.check((public.zad_ai_budget_check('2026-11-07 06:00+00') ->> 'alerted')::boolean = false, 'the next day does not repeat it');

insert into public.zad_brain_runs (user_id, trigger, status, started_at, finished_at, input_tokens, output_tokens, prompt_sizes) values
  (:a, 'chat', 'success', '2026-11-08 10:00:00+00', '2026-11-08 10:00:02+00', 0, 1000000, '{"calls":{"models":["gemini-3.5-flash-lite"]}}');
select pg_temp.check(public.zad_ai_budget_check('2026-11-09 06:00+00') ->> 'kind' = 'ai_budget_100', 'past the cap: the 100% alert');
select pg_temp.check((select count(*) from public.notified) = 2, 'two alerts in the month, no more');
select pg_temp.check((select count(*) from public.zad_brain_health_alerts where alert_date = '2026-11-01') = 2, 'both are recorded against the month');

\echo 'ai_budget: all checks passed'
