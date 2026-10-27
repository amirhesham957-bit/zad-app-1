-- حلقة المبادرة (migration 20261027070000, ZAD_PLAN 5.4), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/habit_trials_scaffold.sql
--   psql < supabase/migrations/20261027070000_habit_trials.sql
--   psql < supabase/sql/tests/habit_trials_test.sql
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
-- 1 Nov 2026 18:00 Cairo = 16:00 UTC. t1 (Telegram): 6 restaurant meals and 10 grocery days in the 28 days before;
-- restaurants cost more, so they are proposed. n1: the same spending, no Telegram. q1 (Telegram): 3 meals only.
insert into auth.users values
  ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2'), ('00000000-0000-0000-0000-0000000000a3');
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000a1', 'EGP', 'EG'), ('00000000-0000-0000-0000-0000000000a2', 'EGP', 'EG'),
  ('00000000-0000-0000-0000-0000000000a3', 'EGP', 'EG');
insert into public.telegram_bindings (user_id, chat_id, bound_at) values
  ('00000000-0000-0000-0000-0000000000a1', 1, now()), ('00000000-0000-0000-0000-0000000000a3', 3, now());
insert into public.zad_transactions (user_id, amount, category, is_expense, created_at)
select u, 400, 'المطاعم', true, '2026-10-30 12:00Z'::timestamptz - k * interval '4 days'
  from unnest(array['00000000-0000-0000-0000-0000000000a1'::uuid, '00000000-0000-0000-0000-0000000000a2'::uuid]) u,
       generate_series(0, 5) k
union all
select '00000000-0000-0000-0000-0000000000a1', 100, 'البقالة', true, '2026-10-31 12:00Z'::timestamptz - k * interval '2 days'
  from generate_series(0, 9) k
union all
-- the same grocery day twice counts as one day
select '00000000-0000-0000-0000-0000000000a1', 50, 'البقالة', true, '2026-10-31 13:00Z'
union all
-- outside the 28 days, income, and another category do not count
select '00000000-0000-0000-0000-0000000000a1', 9000, 'المطاعم', true, '2026-09-20 12:00Z'
union all select '00000000-0000-0000-0000-0000000000a1', 9000, 'المطاعم', false, '2026-10-20 12:00Z'
union all select '00000000-0000-0000-0000-0000000000a1', 9000, 'الفواتير', true, '2026-10-20 12:00Z'
union all
select '00000000-0000-0000-0000-0000000000a3', 400, 'المطاعم', true, '2026-10-30 12:00Z'::timestamptz - k * interval '4 days'
  from generate_series(0, 2) k;
\set QUIET 0

select pg_temp.check(public.zad_enqueue_habit_trials('2026-11-01 15:00Z') = 0, 'not before 18:00 local');
select pg_temp.check(public.zad_enqueue_habit_trials('2026-11-01 16:00Z') = 1, 'one home: Telegram, and a pattern over its threshold');
select pg_temp.check((select (kind, category, baseline_weekly, baseline_count, status) = ('eat_out_less', 'المطاعم', 600::numeric, 6, 'proposed')
  from public.zad_habit_trials where user_id = '00000000-0000-0000-0000-0000000000a1'),
  'the costlier pattern is proposed: 6 meals, 2,400 over 4 weeks = 600 a week');
select pg_temp.check((select t.kind = 'habit_trial' and t.task_description like '%6 مرة في ٤ أسابيع%' and t.task_description like '%600%'
  from public.agent_tasks t join public.zad_habit_trials h on h.proposal_task_id = t.id), 'a habit_trial task with the measured numbers');
select pg_temp.check(public.zad_enqueue_habit_trials('2026-11-02 16:00Z') = 0, 'one open trial per home');

-- another home cannot answer; «نجرب» starts two weeks.
select pg_temp.check(public.zad_habit_trial_answer_service('00000000-0000-0000-0000-0000000000a3',
  (select id from public.zad_habit_trials), true) ->> 'reason' = 'not_found', 'another home cannot answer');
select pg_temp.check(public.zad_habit_trial_answer_service('00000000-0000-0000-0000-0000000000a1',
  (select id from public.zad_habit_trials), true) ->> 'answer' = 'start', '«نجرب» starts the trial');
select pg_temp.check((select status = 'active' and ends_at - started_at = interval '14 days' from public.zad_habit_trials), 'active for 14 days');
select pg_temp.check(public.zad_habit_trial_answer_service('00000000-0000-0000-0000-0000000000a1',
  (select id from public.zad_habit_trials), false) ->> 'already' = 'true', 'a second tap does not undo it');

-- during the trial: 2 meals at 300 (600 over 2 weeks = 300 a week, half the baseline).
update public.zad_habit_trials set started_at = '2026-11-02 10:00Z', ends_at = '2026-11-16 10:00Z';
insert into public.zad_transactions (user_id, amount, category, is_expense, created_at) values
  ('00000000-0000-0000-0000-0000000000a1', 300, 'المطاعم', true, '2026-11-05 12:00Z'),
  ('00000000-0000-0000-0000-0000000000a1', 300, 'المطاعم', true, '2026-11-12 12:00Z'),
  ('00000000-0000-0000-0000-0000000000a1', 999, 'المطاعم', true, '2026-11-17 12:00Z');
select pg_temp.check(public.zad_enqueue_habit_trials('2026-11-15 16:00Z') = 0, 'not measured before it ends');
select pg_temp.check(public.zad_enqueue_habit_trials('2026-11-16 16:00Z') = 1, 'measured the evening it ends');
select pg_temp.check((select (status, result_weekly, result_count, verdict) = ('measured', 300::numeric, 2, 'better') from public.zad_habit_trials),
  'measured over the trial only: 300 a week, 2 meals, better');
select pg_temp.check((select t.kind = 'habit_trial_result' and t.task_description like '%الصرف نزل%'
  from public.agent_tasks t join public.zad_habit_trials h on h.result_task_id = t.id), 'a habit_trial_result task with the verdict');
select pg_temp.check(public.zad_habit_trial_answer_service('00000000-0000-0000-0000-0000000000a1',
  (select id from public.zad_habit_trials), true) ->> 'answer' = 'keep', '«ثبّتها» keeps it');
select pg_temp.check((select count(*) = 1 and bool_and(note like '%600%300%') from public.zad_memory where scope = 'house_habit'),
  'a kept habit is written to memory with its numbers');

-- a month on: the kept kind never returns; the next eligible pattern (groceries) is proposed.
select pg_temp.check(public.zad_enqueue_habit_trials('2026-11-20 16:00Z') = 0, 'nothing new within 28 days of the last proposal');
insert into public.zad_transactions (user_id, amount, category, is_expense, created_at)
select '00000000-0000-0000-0000-0000000000a1', 900, s.category, true, '2026-11-29 12:00Z'::timestamptz - k * interval '2 days'
  from (values ('المطاعم'), ('البقالة')) s(category), generate_series(0, 9) k;
insert into public.zad_transactions (user_id, amount, category, is_expense, created_at) values
  ('00000000-0000-0000-0000-0000000000a1', 50, 'البقالة', true, '2026-11-29 18:00Z');
select pg_temp.check(public.zad_enqueue_habit_trials('2026-12-01 16:00Z') >= 1, 'a month on, the next proposal');
select pg_temp.check((select kind = 'one_grocery_trip' from public.zad_habit_trials
  where user_id = '00000000-0000-0000-0000-0000000000a1' and status = 'proposed'), 'not the kept habit again: groceries');
select pg_temp.check((select baseline_count = 10 from public.zad_habit_trials
  where user_id = '00000000-0000-0000-0000-0000000000a1' and status = 'proposed'), 'grocery trips are days, not receipts: 11 rows, 10 days');

-- «لأ» closes it for 90 days; an unanswered proposal expires after 7.
select pg_temp.check(public.zad_habit_trial_answer_service('00000000-0000-0000-0000-0000000000a1',
  (select id from public.zad_habit_trials where status = 'proposed' and user_id = '00000000-0000-0000-0000-0000000000a1'), false)
  ->> 'answer' = 'decline', '«لأ» declines');
insert into public.zad_transactions (user_id, amount, category, is_expense, created_at)
select '00000000-0000-0000-0000-0000000000a3', 400, 'المطاعم', true, '2027-01-04 12:00Z'::timestamptz - k * interval '3 days' from generate_series(0, 4) k;
-- a1 still shops for groceries often: only the 90 days keep it from being asked again.
insert into public.zad_transactions (user_id, amount, category, is_expense, created_at)
select '00000000-0000-0000-0000-0000000000a1', 100, 'البقالة', true, '2027-01-04 12:00Z'::timestamptz - k * interval '2 days' from generate_series(0, 9) k;
select pg_temp.check(public.zad_enqueue_habit_trials('2027-01-05 16:00Z') = 1, 'only a3 is proposed a month on');
select pg_temp.check(not exists (select 1 from public.zad_habit_trials where user_id = '00000000-0000-0000-0000-0000000000a1'
  and status = 'proposed'), 'a1: the kept habit never returns and the declined one waits 90 days');
select pg_temp.check(exists (select 1 from public.zad_habit_trials where user_id = '00000000-0000-0000-0000-0000000000a3' and status = 'proposed'),
  'a3 is proposed once it has 4 meals');
select public.zad_enqueue_habit_trials('2027-01-13 16:00Z');
select pg_temp.check((select status = 'expired' from public.zad_habit_trials where user_id = '00000000-0000-0000-0000-0000000000a3'),
  'an unanswered proposal expires after 7 days');
