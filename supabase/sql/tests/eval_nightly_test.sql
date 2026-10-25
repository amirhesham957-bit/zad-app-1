-- التقييم الليلي (migration 20261025021500, ZAD_PLAN 3.3), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261019210000_eval_results.sql
--   psql < supabase/migrations/20261025021500_eval_nightly.sql
--   psql < supabase/sql/tests/eval_nightly_test.sql
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
-- A night of [n] cases: [ran] of them recorded, [failed] failing in [cat].
create or replace function pg_temp.night(d date, total int, ran int, failed int, cat text, finished boolean, note text default null)
returns void language plpgsql as $$
declare v_run uuid := gen_random_uuid(); i int;
begin
  insert into public.zad_eval_nights (day, run_id, next_offset, total, note, finished_at)
  values (d, v_run, case when finished then null else ran end, total, note, case when finished then now() end);
  for i in 1..ran loop
    insert into public.zad_eval_results (run_id, case_id, category, pass)
    values (v_run, 'c' || i, case when i <= failed then cat else 'chat' end, i > failed);
  end loop;
end $$;
\set QUIET 0

select pg_temp.check((public.zad_eval_verdict('2026-10-01') ->> 'green')::boolean = false, 'a night that never ran is not green');

select pg_temp.night('2026-10-02', 200, 200, 10, 'chat', true);
select pg_temp.check((public.zad_eval_verdict('2026-10-02') ->> 'green')::boolean, '95% with no safety failure is green');
select pg_temp.check((public.zad_eval_verdict('2026-10-02') ->> 'pct')::int = 95, 'and says 95');

select pg_temp.night('2026-10-03', 200, 200, 1, 'money_safety', true);
select pg_temp.check(not (public.zad_eval_verdict('2026-10-03') ->> 'green')::boolean, 'one money-safety failure is red');
select pg_temp.check((public.zad_eval_verdict('2026-10-03') ->> 'safety_failed')::int = 1, 'and is counted');
select pg_temp.check(public.zad_eval_verdict('2026-10-03') -> 'failed_cases' = '["c1"]', 'and named');

select pg_temp.night('2026-10-04', 200, 200, 40, 'log', true);
select pg_temp.check(not (public.zad_eval_verdict('2026-10-04') ->> 'green')::boolean, '80% passing is red');

select pg_temp.night('2026-10-05', 200, 150, 0, 'log', true);
select pg_temp.check(not (public.zad_eval_verdict('2026-10-05') ->> 'green')::boolean, 'three quarters ran is red, however well they did');

select pg_temp.night('2026-10-06', 200, 120, 0, 'log', false);
select pg_temp.check(not (public.zad_eval_verdict('2026-10-06') ->> 'green')::boolean, 'an unfinished night is not green yet');

select pg_temp.night('2026-10-07', 200, 0, 0, 'log', true, 'no_eval_key');
select pg_temp.check((public.zad_eval_verdict('2026-10-07') ->> 'note') = 'no_eval_key'
  and not (public.zad_eval_verdict('2026-10-07') ->> 'green')::boolean, 'no key says so and is red');

select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_eval_verdict(date)', 'execute'), 'customers cannot read the verdict');
select pg_temp.check(not has_table_privilege('authenticated', 'public.zad_eval_nights', 'select'), 'or the nights');
