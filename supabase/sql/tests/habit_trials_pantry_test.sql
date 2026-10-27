-- حلقة المبادرة من المخزن والتطبيق (migration 20261027080000, ZAD_PLAN 5.4), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/habit_trials_scaffold.sql
--   psql < supabase/sql/tests/habit_trials_pantry_scaffold.sql
--   psql < supabase/migrations/20261027070000_habit_trials.sql
--   psql < supabase/migrations/20261027080000_habit_trials_pantry.sql
--   psql < supabase/sql/tests/habit_trials_pantry_test.sql
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
grant execute on function pg_temp.who(uuid) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
-- 1 Nov 2026 18:00 Cairo = 16:00 UTC.
-- w1 (app only, no Telegram): 6 things thrown away in 28 days, and 4 restaurant meals (exactly at the threshold).
-- s1 (Telegram): 3 stock-outs plus the same item out twice in one day; one waste row (under 3).
-- o1 (app only): nothing over a threshold.
insert into auth.users values
  ('00000000-0000-0000-0000-0000000000b1'), ('00000000-0000-0000-0000-0000000000b2'), ('00000000-0000-0000-0000-0000000000b3');
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000b1', 'EGP', 'EG'), ('00000000-0000-0000-0000-0000000000b2', 'SAR', 'SA'),
  ('00000000-0000-0000-0000-0000000000b3', 'EGP', 'EG');
insert into public.zad_fcm_tokens (user_id, token) values
  ('00000000-0000-0000-0000-0000000000b1', 'tok-b1'), ('00000000-0000-0000-0000-0000000000b3', 'tok-b3');
insert into public.telegram_bindings (user_id, chat_id, bound_at) values ('00000000-0000-0000-0000-0000000000b2', 2, now());
insert into public.zad_waste_log (user_id, item_name, quantity, logged_at)
select '00000000-0000-0000-0000-0000000000b1'::uuid, 'زبادي ' || k, 1, '2026-10-30 10:00Z'::timestamptz - k * interval '4 days' from generate_series(0, 5) k
union all select '00000000-0000-0000-0000-0000000000b1', 'قديم', 1, '2026-09-01 10:00Z'
union all select '00000000-0000-0000-0000-0000000000b2', 'خبز', 1, '2026-10-28 10:00Z';
insert into public.zad_transactions (user_id, amount, category, is_expense, created_at)
select '00000000-0000-0000-0000-0000000000b1', 900, 'المطاعم', true, '2026-10-30 12:00Z'::timestamptz - k * interval '5 days' from generate_series(0, 3) k;
-- Riyadh is UTC+3: 20:30Z and 22:30Z on 20 Oct are 21 Oct there — one day, not two.
insert into public.zad_inventory_observations (user_id, item_name, qty, observed_at) values
  ('00000000-0000-0000-0000-0000000000b2', 'رز', 0, '2026-10-10 10:00Z'),
  ('00000000-0000-0000-0000-0000000000b2', 'زيت', 0, '2026-10-15 10:00Z'),
  ('00000000-0000-0000-0000-0000000000b2', 'سكر', 0, '2026-10-20 21:30Z'),
  ('00000000-0000-0000-0000-0000000000b2', 'سكر', 0, '2026-10-20 22:30Z'),
  ('00000000-0000-0000-0000-0000000000b2', 'سكر', 2, '2026-10-22 10:00Z'),
  ('00000000-0000-0000-0000-0000000000b2', 'شاي', 0, '2026-09-01 10:00Z');
\set QUIET 0

select pg_temp.check((select (total, times) = (6::numeric, 6) from public.zad_habit_trial_measure(
  '00000000-0000-0000-0000-0000000000b1', 'waste_less', 'الهالك', 'Africa/Cairo', '2026-10-04 16:00Z', '2026-11-01 16:00Z')),
  'waste: the rows inside the 28 days only');
select pg_temp.check((select (total, times) = (3::numeric, 3) from public.zad_habit_trial_measure(
  '00000000-0000-0000-0000-0000000000b2', 'fewer_stockouts', 'المخزن', 'Asia/Riyadh', '2026-10-04 16:00Z', '2026-11-01 16:00Z')),
  'stock-outs: one per item per local day, zero readings only, inside the window');
select pg_temp.check((select (total, times) = (3600::numeric, 4) from public.zad_habit_trial_measure(
  '00000000-0000-0000-0000-0000000000b1', 'eat_out_less', 'المطاعم', 'Africa/Cairo', '2026-10-04 16:00Z', '2026-11-01 16:00Z')),
  'the money kinds still measure from transactions');

-- Riyadh's 18:00 is 15:00Z, Cairo's is 16:00Z.
select pg_temp.check(public.zad_enqueue_habit_trials('2026-11-01 15:00Z') = 1, 'Riyadh at its own 18:00');
select pg_temp.check((select (kind, baseline_count, baseline_weekly) = ('fewer_stockouts', 3, 0.75)
  from public.zad_habit_trials where user_id = '00000000-0000-0000-0000-0000000000b2'), 's1: stock-outs, 3 in 4 weeks = 0.75 a week');
select pg_temp.check(public.zad_enqueue_habit_trials('2026-11-01 16:00Z') = 1, 'Cairo: w1 has only the app, and is asked; o1 has nothing to ask');
select pg_temp.check((select kind = 'waste_less' from public.zad_habit_trials where user_id = '00000000-0000-0000-0000-0000000000b1'),
  'w1: 6 thrown away is twice its threshold, 4 meals only reach theirs — waste first, though the meals cost more');
select pg_temp.check((select t.task_description like '%6 حاجة اترمت في ٤ أسابيع%' and t.task_description like '%1.5 حاجة اترمت في الأسبوع%'
  from public.agent_tasks t join public.zad_habit_trials h on h.proposal_task_id = t.id
  where h.user_id = '00000000-0000-0000-0000-0000000000b1'), 'counted, not priced: «حاجة اترمت», no currency');

-- the app answers with the customer's own session; nobody else's trial, and not signed out.
select pg_temp.check(public.zad_habit_trial_answer((select id from public.zad_habit_trials where user_id = '00000000-0000-0000-0000-0000000000b1'), true)
  ->> 'reason' = 'not_signed_in', 'the app RPC needs a session');
select pg_temp.who('00000000-0000-0000-0000-0000000000b2');
select pg_temp.check(public.zad_habit_trial_answer((select id from public.zad_habit_trials where user_id = '00000000-0000-0000-0000-0000000000b1'), true)
  ->> 'reason' = 'not_found', 'another home''s trial is not found');
select pg_temp.who('00000000-0000-0000-0000-0000000000b1');
select pg_temp.check(public.zad_habit_trial_answer((select id from public.zad_habit_trials where user_id = '00000000-0000-0000-0000-0000000000b1'), true)
  ->> 'answer' = 'start', 'the owner starts it from the app');
select set_config('request.jwt.claims', '{}', false);

-- during the trial: one thing thrown away (0.5 a week against 1.5).
update public.zad_habit_trials set started_at = '2026-11-02 10:00Z', ends_at = '2026-11-16 10:00Z'
 where user_id = '00000000-0000-0000-0000-0000000000b1';
insert into public.zad_waste_log (user_id, item_name, quantity, logged_at)
values ('00000000-0000-0000-0000-0000000000b1', 'خس', 1, '2026-11-08 10:00Z');
select pg_temp.check(public.zad_enqueue_habit_trials('2026-11-16 16:00Z') = 1, 'measured the evening it ends');
select pg_temp.check((select (result_weekly, result_count, verdict) = (0.5, 1, 'better') from public.zad_habit_trials
  where user_id = '00000000-0000-0000-0000-0000000000b1'), '0.5 a week, better');
select pg_temp.check((select t.task_description like '%العدد نزل%' from public.agent_tasks t
  join public.zad_habit_trials h on h.result_task_id = t.id where h.user_id = '00000000-0000-0000-0000-0000000000b1'),
  'the verdict speaks of a count, not spending');
select pg_temp.check(public.zad_habit_trial_answer_service('00000000-0000-0000-0000-0000000000b1',
  (select id from public.zad_habit_trials where user_id = '00000000-0000-0000-0000-0000000000b1'), true) ->> 'answer' = 'keep', 'kept');
select pg_temp.check((select note like '%1.5 حاجة اترمت%0.5 حاجة اترمت%' from public.zad_memory where user_id = '00000000-0000-0000-0000-0000000000b1'),
  'the kept habit is remembered in counts');
