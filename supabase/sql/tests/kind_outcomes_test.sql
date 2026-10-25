-- يتعلم من النتيجة (migration 20261025033500, ZAD_PLAN 3.6), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/kind_outcomes_scaffold.sql
--   psql < supabase/migrations/20261025033500_kind_outcomes.sql
--   psql < supabase/sql/tests/kind_outcomes_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
create or replace function pg_temp.who(p uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, false); end $$;
grant execute on function pg_temp.who(uuid) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set b '''00000000-0000-0000-0000-0000000000b1'''
-- a: 12 spend forecasts, one acted on; 4 habit nudges, 3 acted and 1 acted-then-dismissed; one forecast 90 days old.
insert into public.zad_guardian_outcomes (task_id, user_id, kind, delivered_at, replied_within_day, acted_within_2h, dismissed)
select gen_random_uuid(), :a::uuid, 'spend_forecast', now() - make_interval(days => g), g <= 3, g = 1, false from generate_series(1, 12) g
union all select gen_random_uuid(), :a::uuid, 'habit_budget', now() - make_interval(days => g), true, true, g = 4 from generate_series(1, 4) g
union all select gen_random_uuid(), :a::uuid, 'spend_forecast', now() - interval '90 days', true, true, false
union all select gen_random_uuid(), :b::uuid, 'spend_forecast', now() - interval '1 day', true, true, false;
\set QUIET 0

select pg_temp.check((select sent = 12 and replied = 3 and acted = 1 and dismissed = 0 from public.zad_kind_outcomes(:a, 60) where kind = 'spend_forecast'),
  'one home, one kind: sent, replied, acted inside the window');
select pg_temp.check((select acted = 3 and dismissed = 1 from public.zad_kind_outcomes(:a, 60) where kind = 'habit_budget'),
  'acting and then dismissing is not acting');
select pg_temp.check((select last_at > now() - interval '2 days' from public.zad_kind_outcomes(:a, 60) where kind = 'spend_forecast'), 'and when it last reached them');
select pg_temp.check((select sent from public.zad_kind_outcomes(:a, 120) where kind = 'spend_forecast') = 13, 'a wider window reaches the old one');
select pg_temp.check((select sent from public.zad_kind_outcomes(:b, 60) where kind = 'spend_forecast') = 1, 'another home is counted apart');

set role authenticated;
select pg_temp.who(:a);
select pg_temp.check((select count(*) from public.zad_my_kind_outcomes(60)) = 2, 'the customer reads their own kinds');
reset role;
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_kind_outcomes(uuid, int)', 'execute'), 'customers cannot read by user id');
