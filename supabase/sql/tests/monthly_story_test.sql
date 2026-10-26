-- حكاية البيت الشهرية (migration 20261027023000, ZAD_PLAN 5.2), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/monthly_story_scaffold.sql
--   psql < supabase/migrations/20261027023000_monthly_story.sql
--   psql < supabase/sql/tests/monthly_story_test.sql
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
-- e1 (Cairo): October 2026 — 6 expenses in 3 weeks, one income, one not counting toward the budget, one 1 Nov
-- 00:30 Cairo (= 31 Oct 22:30 UTC, November locally), and September 1,000 to compare with. A «صح» in October.
-- e2: only 3 expenses in October. s1 (Riyadh): active, 5 expenses.
insert into auth.users (id, last_sign_in_at) values
  ('00000000-0000-0000-0000-0000000000e1', '2026-10-30Z'), ('00000000-0000-0000-0000-0000000000e2', '2026-10-30Z'),
  ('00000000-0000-0000-0000-0000000000b1', '2026-10-30Z');
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000e1', 'EGP', 'EG'), ('00000000-0000-0000-0000-0000000000e2', 'EGP', 'EG'),
  ('00000000-0000-0000-0000-0000000000b1', 'SAR', 'SA');
insert into public.zad_transactions (user_id, amount, category, txn_kind, counts_toward_budget, created_at) values
  ('00000000-0000-0000-0000-0000000000e1', 400, 'البقالة', 'expense', null, '2026-10-07 10:00Z'),
  ('00000000-0000-0000-0000-0000000000e1', 300, 'البقالة', 'expense', true, '2026-10-08 10:00Z'),
  ('00000000-0000-0000-0000-0000000000e1', 1000, 'الرعاية الصحية', 'expense', true, '2026-10-09 10:00Z'),
  ('00000000-0000-0000-0000-0000000000e1', 200, 'البقالة', 'expense', true, '2026-10-14 10:00Z'),
  ('00000000-0000-0000-0000-0000000000e1', 100, null, 'expense', true, '2026-10-21 10:00Z'),
  ('00000000-0000-0000-0000-0000000000e1', 50, 'الفواتير', 'expense', true, '2026-10-22 10:00Z'),
  ('00000000-0000-0000-0000-0000000000e1', 9000, 'دخل', 'income', true, '2026-10-10 10:00Z'),
  ('00000000-0000-0000-0000-0000000000e1', 5000, 'تحويل', 'expense', false, '2026-10-11 10:00Z'),
  ('00000000-0000-0000-0000-0000000000e1', 777, 'البقالة', 'expense', true, '2026-10-31 22:30Z'),
  ('00000000-0000-0000-0000-0000000000e1', 1000, 'البقالة', 'expense', true, '2026-09-15 10:00Z'),
  ('00000000-0000-0000-0000-0000000000e2', 100, 'البقالة', 'expense', true, '2026-10-07 10:00Z'),
  ('00000000-0000-0000-0000-0000000000e2', 100, 'البقالة', 'expense', true, '2026-10-08 10:00Z'),
  ('00000000-0000-0000-0000-0000000000e2', 100, 'البقالة', 'expense', true, '2026-10-09 10:00Z');
insert into public.zad_transactions (user_id, amount, category, txn_kind, counts_toward_budget, created_at)
select '00000000-0000-0000-0000-0000000000b1', 100, 'البقالة', 'expense', true, '2026-10-05 10:00Z'::timestamptz + make_interval(days => k)
  from generate_series(1, 5) k;
insert into public.zad_house_learnings (user_id, note, answer, answered_at) values
  ('00000000-0000-0000-0000-0000000000e1', 'البقالة غالباً يوم الأربعاء.', 'yes', '2026-10-28 12:00Z'),
  ('00000000-0000-0000-0000-0000000000e1', 'نمط اتقال عليه مش صح.', 'no', '2026-10-28 12:00Z');
\set QUIET 0

select pg_temp.check(public.zad_monthly_story_facts('00000000-0000-0000-0000-0000000000e1', '2026-10-31')
  @> '{"month": "2026-10", "spent": 2050, "last_month_spent": 1000, "change_pct": 105, "txn_count": 6, "days_with_spending": 6, "currency": "EGP"}',
  'October in Cairo time: expenses only, budget-counting only, the 1 Nov 00:30 one is November');
select pg_temp.check(public.zad_monthly_story_facts('00000000-0000-0000-0000-0000000000e1', '2026-10-31') -> 'top_categories'
  = '[{"name": "الرعاية الصحية", "amount": 1000}, {"name": "البقالة", "amount": 900}, {"name": "غير مصنّف", "amount": 100}]',
  'top three categories, biggest first, an empty category named');
select pg_temp.check(public.zad_monthly_story_facts('00000000-0000-0000-0000-0000000000e1', '2026-10-31') -> 'weeks'
  = '{"count": 3, "lowest": {"from": "2026-10-19", "spent": 150}, "highest": {"from": "2026-10-05", "spent": 1700}}',
  'weeks of the month from Monday: the dearest and the calmest');
select pg_temp.check(public.zad_monthly_story_facts('00000000-0000-0000-0000-0000000000e1', '2026-10-31') -> 'learned'
  = '["البقالة غالباً يوم الأربعاء."]', 'only what the customer called right');
select pg_temp.check(public.zad_monthly_story_facts('00000000-0000-0000-0000-0000000000e2', '2026-10-31') is null, 'under 5 expenses: no story');
select pg_temp.check(not (public.zad_monthly_story_facts('00000000-0000-0000-0000-0000000000e1', '2026-10-31')::text ~ 'تحويل|دخل'),
  'no transfer or income in the story');

-- 1 Nov 18:00 Riyadh = 15:00 UTC; 18:00 Cairo = 16:00 UTC.
select pg_temp.check(public.zad_enqueue_monthly_story('2026-11-01 14:00Z') = 0, 'not before 18:00 local');
select pg_temp.check(public.zad_enqueue_monthly_story('2026-11-01 15:10Z') = 1, 'Riyadh at its own 18:00 (15:00 UTC)');
select pg_temp.check(exists (select 1 from public.zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000b1'), '… and it is the Riyadh home');
select pg_temp.check(public.zad_enqueue_monthly_story('2026-11-01 16:00Z') = 1, 'Cairo at 18:00 on the 1st: one story (e2 has too little)');
select pg_temp.check((select (moment, dedupe_key, status, facts ->> 'spent') = ('monthly_story', 'monthly_story:2026-10', 'pending', '2050')
  from public.zad_voice_moments where user_id = '00000000-0000-0000-0000-0000000000e1'), 'the moment carries its facts');
select pg_temp.check(public.zad_enqueue_monthly_story('2026-11-01 16:30Z') = 0, 'once a month');
select pg_temp.check(public.zad_enqueue_monthly_story('2026-11-02 16:00Z') = 0, 'not on the 2nd');
