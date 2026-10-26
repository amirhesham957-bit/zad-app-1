-- «اتعلمت إن» (migration 20261027001500, ZAD_PLAN 5.2), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/house_learnings_scaffold.sql
--   psql < supabase/migrations/20261027001500_house_learnings.sql
--   psql < supabase/sql/tests/house_learnings_test.sql
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
-- Wednesday noon, Cairo, [k] weeks ago (always in the past).
create or replace function pg_temp.wed(k int, hh int default 12, zone text default 'Africa/Cairo') returns timestamptz language sql as $$
  select ((date_trunc('week', now() at time zone zone) - make_interval(weeks => k) + interval '2 days' + make_interval(hours => hh)) at time zone zone) $$;
-- e1: groceries on Wednesday in 3 weeks (3 of 5 grocery buys = 60%). e2: the same, 2 weeks only.
-- o1: only «أخرى». s1 (Riyadh): groceries at 22:30 UTC Tuesday = Wednesday 01:30 in Riyadh, 3 weeks.
insert into auth.users values
  ('00000000-0000-0000-0000-0000000000e1'), ('00000000-0000-0000-0000-0000000000e2'),
  ('00000000-0000-0000-0000-0000000000f1'), ('00000000-0000-0000-0000-0000000000b1');
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000e1', 'EGP', 'EG'), ('00000000-0000-0000-0000-0000000000e2', 'EGP', 'EG'),
  ('00000000-0000-0000-0000-0000000000f1', 'EGP', 'EG'), ('00000000-0000-0000-0000-0000000000b1', 'SAR', 'SA');
insert into public.zad_transactions (user_id, amount, category, is_expense, created_at)
select '00000000-0000-0000-0000-0000000000e1'::uuid, 100, 'البقالة', true, pg_temp.wed(k) from generate_series(1, 3) k
union all select '00000000-0000-0000-0000-0000000000e1', 50, 'البقالة', true, pg_temp.wed(1) + interval '2 days'
union all select '00000000-0000-0000-0000-0000000000e1', 50, 'البقالة', true, pg_temp.wed(2) + interval '3 days'
union all select '00000000-0000-0000-0000-0000000000e1', 900, 'البقالة', false, pg_temp.wed(4)
union all select '00000000-0000-0000-0000-0000000000e2'::uuid, 100, 'البقالة', true, pg_temp.wed(k) from generate_series(1, 2) k
union all select '00000000-0000-0000-0000-0000000000e2', 100, 'البقالة', true, pg_temp.wed(1) - interval '1 hour'
union all select '00000000-0000-0000-0000-0000000000e2', 50, 'البقالة', true, pg_temp.wed(2) + interval '2 days'
union all select '00000000-0000-0000-0000-0000000000e2', 50, 'البقالة', true, pg_temp.wed(3) + interval '3 days'
union all select '00000000-0000-0000-0000-0000000000f1'::uuid, 100, 'أخرى', true, pg_temp.wed(k) from generate_series(1, 6) k
union all select '00000000-0000-0000-0000-0000000000b1'::uuid, 100, 'البقالة', true, pg_temp.wed(k, 1, 'Asia/Riyadh') from generate_series(1, 5) k;
\set QUIET 0

select pg_temp.check((select public.zad_house_pattern('00000000-0000-0000-0000-0000000000e1')
  @> '{"category": "البقالة", "weekday": "الأربعاء", "times": 3, "weeks": 3, "category_times": 5, "share_pct": 60}'),
  'groceries on Wednesday in 3 of 8 weeks, 60% of grocery buys (income not counted)');
select pg_temp.check(public.zad_house_pattern('00000000-0000-0000-0000-0000000000e1') ->> 'note'
  = 'البقالة غالباً يوم الأربعاء: 3 مرة في 3 أسابيع مختلفة من آخر ٨، يعني 60٪ من مرات البقالة.', 'the sentence carries its numbers');
select pg_temp.check(public.zad_house_pattern('00000000-0000-0000-0000-0000000000e2') is null, 'two weeks are not a pattern');
select pg_temp.check(public.zad_house_pattern('00000000-0000-0000-0000-0000000000f1') is null, '«أخرى» is not a category');
select pg_temp.check(public.zad_house_pattern('00000000-0000-0000-0000-0000000000b1') ->> 'weekday' = 'الأربعاء',
  'the weekday is the account''s market time (Riyadh), not UTC');

select public._agent_home_weekly_digest_for_user('00000000-0000-0000-0000-0000000000e1');
select pg_temp.check((select task_description like '%• اتعلمت إن (من حركاتك المسجلة): البقالة غالباً يوم الأربعاء: 3 مرة%«صح؟».%'
  from public.agent_tasks where user_id = '00000000-0000-0000-0000-0000000000e1'), 'the weekly digest carries the line');
select pg_temp.check((select (key, answer is null) = ('category_weekday:البقالة:3', true) from public.zad_house_learnings
  where user_id = '00000000-0000-0000-0000-0000000000e1'), 'what was said is recorded, unanswered');
select pg_temp.check(public.zad_house_pattern('00000000-0000-0000-0000-0000000000e1') is null, 'not said again within 28 days');
update public.zad_house_learnings set said_at = now() - interval '30 days';
select pg_temp.check(public.zad_house_pattern('00000000-0000-0000-0000-0000000000e1') is not null, 'unanswered and 28 days on: it may be said again');
update public.zad_house_learnings set answer = 'no', answered_at = now();
select pg_temp.check(public.zad_house_pattern('00000000-0000-0000-0000-0000000000e1') is null, '«مش صح» is never said again');
update public.zad_house_learnings set answer = 'yes';
select pg_temp.check(public.zad_house_pattern('00000000-0000-0000-0000-0000000000e1') is null, '«صح» is known now, not repeated');

-- s1 has no spending this week, nothing low, nothing due: the pattern alone is worth a digest.
select public._agent_home_weekly_digest_for_user('00000000-0000-0000-0000-0000000000b1');
select pg_temp.check((select count(*) = 1 from public.agent_tasks where user_id = '00000000-0000-0000-0000-0000000000b1'), 'a pattern alone is worth the weekly digest');
-- f1: spending this week? No (all weeks ago), no pattern: nothing sent.
select public._agent_home_weekly_digest_for_user('00000000-0000-0000-0000-0000000000f1');
select pg_temp.check(not exists (select 1 from public.agent_tasks where user_id = '00000000-0000-0000-0000-0000000000f1')
  or (select task_description not like '%اتعلمت إن%' from public.agent_tasks where user_id = '00000000-0000-0000-0000-0000000000f1'),
  'no pattern, no learned line');
