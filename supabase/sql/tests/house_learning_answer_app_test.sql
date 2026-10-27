-- «صح / مش صح» from the app's notification (migration 20261027090000, ZAD_PLAN 5.2), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/house_learnings_scaffold.sql
--   psql < supabase/sql/tests/house_learning_answer_scaffold.sql
--   psql < supabase/migrations/20261027001500_house_learnings.sql
--   psql < supabase/migrations/20261027013000_house_learning_answer.sql
--   psql < supabase/migrations/20261027090000_house_learning_answer_app.sql
--   psql < supabase/sql/tests/house_learning_answer_app_test.sql
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
create or replace function pg_temp.who(p uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, false); end $$;
insert into auth.users values ('00000000-0000-0000-0000-0000000000f1'), ('00000000-0000-0000-0000-0000000000f2');
insert into public.zad_house_learnings (id, user_id, key, note, evidence) values
  ('00000000-0000-0000-0000-00000000aaf1', '00000000-0000-0000-0000-0000000000f1', 'cat_day:البقالة:3',
   'البقالة بتتشرى يوم الأربع', '{"times": 4}');
\set QUIET 0

select pg_temp.check(public.zad_house_learning_answer('00000000-0000-0000-0000-00000000aaf1', true) ->> 'reason' = 'not_signed_in',
  'the app RPC needs a session');
select pg_temp.who('00000000-0000-0000-0000-0000000000f2');
select pg_temp.check(public.zad_house_learning_answer('00000000-0000-0000-0000-00000000aaf1', true) ->> 'reason' = 'not_found',
  'another home''s learning is not found');
select pg_temp.who('00000000-0000-0000-0000-0000000000f1');
select pg_temp.check(public.zad_house_learning_answer('00000000-0000-0000-0000-00000000aaf1', true) ->> 'answer' = 'yes',
  'the owner''s «صح» is recorded');
select pg_temp.check((select count(*) = 1 from public.zad_memory where user_id = '00000000-0000-0000-0000-0000000000f1' and scope = 'house_pattern'),
  'and becomes a memory, as from Telegram');
select pg_temp.check(public.zad_house_learning_answer('00000000-0000-0000-0000-00000000aaf1', false) ->> 'already' = 'true',
  'answered once: the bot''s or the app''s first answer stands');
select pg_temp.check(not has_function_privilege('anon', 'public.zad_house_learning_answer(uuid, boolean)', 'execute'),
  'anon cannot call it');
