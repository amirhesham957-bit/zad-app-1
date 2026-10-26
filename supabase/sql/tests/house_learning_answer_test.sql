-- «صح / مش صح» (migration 20261027013000, ZAD_PLAN 5.2), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/house_learnings_scaffold.sql
--   psql < supabase/sql/tests/house_learning_answer_scaffold.sql
--   psql < supabase/migrations/20261027001500_house_learnings.sql
--   psql < supabase/migrations/20261027013000_house_learning_answer.sql
--   psql < supabase/sql/tests/house_learning_answer_test.sql
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
create or replace function pg_temp.wed(k int) returns timestamptz language sql as $$
  select ((date_trunc('week', now() at time zone 'Africa/Cairo') - make_interval(weeks => k) + interval '2 days 12 hours') at time zone 'Africa/Cairo') $$;
-- e1 and e2: groceries on Wednesday in 3 weeks, 60% of grocery buys.
insert into auth.users values ('00000000-0000-0000-0000-0000000000e1'), ('00000000-0000-0000-0000-0000000000e2');
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000e1', 'EGP', 'EG'), ('00000000-0000-0000-0000-0000000000e2', 'EGP', 'EG');
insert into public.zad_transactions (user_id, amount, category, is_expense, created_at)
select u, 100, 'البقالة', true, pg_temp.wed(k)
  from unnest(array['00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000e2']::uuid[]) u, generate_series(1, 3) k
union all select u, 50, 'البقالة', true, pg_temp.wed(2) + interval '3 days'
  from unnest(array['00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000e2']::uuid[]) u
union all select u, 50, 'البقالة', true, pg_temp.wed(3) + interval '4 days'
  from unnest(array['00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000e2']::uuid[]) u;
\set QUIET 0

select public._agent_home_weekly_digest_for_user('00000000-0000-0000-0000-0000000000e1');
select public._agent_home_weekly_digest_for_user('00000000-0000-0000-0000-0000000000e2');
select pg_temp.check((select count(*) = 2 from public.zad_house_learnings l join public.agent_tasks t on t.id = l.task_id
  where t.kind = 'home_weekly_digest' and t.user_id = l.user_id), 'each learning points at the digest that said it');

-- The digest already sent today: a second run writes no task and keeps the learning's task.
select public._agent_home_weekly_digest_for_user('00000000-0000-0000-0000-0000000000e1');
select pg_temp.check((select count(*) = 1 from public.agent_tasks where user_id = '00000000-0000-0000-0000-0000000000e1'), 'one digest a week');

select pg_temp.check(public.zad_house_learning_answer_service('00000000-0000-0000-0000-0000000000e2',
  (select id from public.zad_house_learnings where user_id = '00000000-0000-0000-0000-0000000000e1'), true) ->> 'reason' = 'not_found',
  'another home cannot answer');
select pg_temp.check(public.zad_house_learning_answer_service('00000000-0000-0000-0000-0000000000e1',
  (select id from public.zad_house_learnings where user_id = '00000000-0000-0000-0000-0000000000e1'), true) ->> 'answer' = 'yes', '«صح» is recorded');
select pg_temp.check((select (scope, confidence::numeric(3,1), evidence_count) = ('house_pattern', 0.9, 3) from public.zad_memory
  where user_id = '00000000-0000-0000-0000-0000000000e1'), '«صح» becomes a memory with its evidence count');
select pg_temp.check(public.zad_house_learning_answer_service('00000000-0000-0000-0000-0000000000e1',
  (select id from public.zad_house_learnings where user_id = '00000000-0000-0000-0000-0000000000e1'), false)
  = '{"ok": true, "answer": "yes", "already": true}', 'one answer only: a second tap changes nothing');

select pg_temp.check(public.zad_house_learning_answer_service('00000000-0000-0000-0000-0000000000e2',
  (select id from public.zad_house_learnings where user_id = '00000000-0000-0000-0000-0000000000e2'), false) ->> 'answer' = 'no', '«مش صح» is recorded');
select pg_temp.check(not exists (select 1 from public.zad_memory where user_id = '00000000-0000-0000-0000-0000000000e2'), '«مش صح» writes no memory');
update public.zad_house_learnings set said_at = now() - interval '60 days';
select pg_temp.check(public.zad_house_pattern('00000000-0000-0000-0000-0000000000e2') is null, 'a pattern called wrong is never said again');
