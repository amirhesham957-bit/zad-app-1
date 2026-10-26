-- «اتعلمت إن» needs a channel (migration 20261027031500, ZAD_PLAN 5.2), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/house_learnings_scaffold.sql
--   psql < supabase/sql/tests/house_learning_answer_scaffold.sql
--   psql < supabase/sql/tests/learning_needs_channel_scaffold.sql
--   psql < supabase/migrations/20261027001500_house_learnings.sql
--   psql < supabase/migrations/20261027013000_house_learning_answer.sql
--   psql < supabase/migrations/20261027031500_learning_needs_channel.sql
--   psql < supabase/sql/tests/learning_needs_channel_test.sql
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
-- Same Wednesday-groceries pattern for four homes: t1 on Telegram, p1 with a push token, u1 with an unbound
-- Telegram row, n1 with nothing. Each also spent this week, so every one gets a digest.
insert into auth.users values
  ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2'),
  ('00000000-0000-0000-0000-0000000000a3'), ('00000000-0000-0000-0000-0000000000a4');
insert into public.zad_users (id, currency, country)
select u, 'EGP', 'EG' from unnest(array['00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2',
  '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a4']::uuid[]) u;
insert into public.zad_transactions (user_id, amount, category, is_expense, created_at)
select u, 100, 'البقالة', true, pg_temp.wed(k)
  from unnest(array['00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2',
                    '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a4']::uuid[]) u, generate_series(1, 3) k
union all select u, 50, d.c, true, now() - interval '1 hour'
  from unnest(array['00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2',
                    '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a4']::uuid[]) u,
       (values ('البقالة'), ('البقالة')) d(c);
insert into public.telegram_bindings (user_id, chat_id, bound_at) values
  ('00000000-0000-0000-0000-0000000000a1', 1, now()), ('00000000-0000-0000-0000-0000000000a3', 3, null);
insert into public.zad_fcm_tokens (user_id, token) values ('00000000-0000-0000-0000-0000000000a2', 'tok-a2');
\set QUIET 0

select public._agent_home_weekly_digest_for_user(u) from unnest(array['00000000-0000-0000-0000-0000000000a1',
  '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a4']::uuid[]) u;
select pg_temp.check((select count(*) = 4 from public.agent_tasks where kind = 'home_weekly_digest'), 'every home still gets its digest');
select pg_temp.check((select array_agg(user_id order by user_id) from public.zad_house_learnings)
  = array['00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2']::uuid[],
  'a pattern is recorded as said only for a home on Telegram or with a push token');
select pg_temp.check((select bool_and(task_description like '%اتعلمت إن%') from public.agent_tasks
  where user_id in ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2')), 'homes with a channel hear it');
select pg_temp.check((select bool_and(task_description not like '%اتعلمت إن%') from public.agent_tasks
  where user_id in ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a4')), 'an unbound Telegram row is not a channel, and nothing is not one');
select pg_temp.check(public.zad_house_pattern('00000000-0000-0000-0000-0000000000a4') is not null, 'the pattern waits for the day the home has a channel');
