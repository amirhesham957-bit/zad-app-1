-- الميعاد اللي فات (migration 20261028030000, ZAD_PLAN ٨ج.٤), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/past_appointments_scaffold.sql
--   psql < supabase/migrations/20261028030000_past_appointments.sql
--   psql < supabase/sql/tests/past_appointments_test.sql
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

-- ── the step, on fixed dates ────────────────────────────────────────────────────────────────
-- Egypt leaves summer time at the end of 29/10/2026: 08:20 Cairo is 05:20Z on the 28th and 06:20Z on the 30th.
select pg_temp.check(
  public.zad_next_appointment_start('2026-10-28 05:20+00', 'daily', 'Africa/Cairo', '2026-10-29 06:00+00')
    = '2026-10-30 06:20+00',
  'daily keeps 08:20 Cairo across the clock change (UTC step would give 05:20Z = 07:20)');
select pg_temp.check(
  public.zad_next_appointment_start('2026-10-28 05:20+00', 'daily', 'Africa/Cairo', '2026-10-28 06:00+00')
    = '2026-10-29 05:20+00',
  'the very next day, before the change, is still 05:20Z');
select pg_temp.check(
  public.zad_next_appointment_start('2026-10-01 05:20+00', 'daily', 'Africa/Cairo', '2026-11-15 12:00+00')
    = '2026-11-16 06:20+00',
  'weeks behind, it jumps to the first occurrence after now, not one step');
select pg_temp.check(
  public.zad_next_appointment_start('2026-10-22 16:00+00', 'weekly', 'Africa/Cairo', '2026-10-30 00:00+00')
    = '2026-11-05 17:00+00',
  'weekly: Thursday 19:00 Cairo stays Thursday 19:00');
select pg_temp.check(
  public.zad_next_appointment_start('2026-01-31 09:00+00', 'monthly', 'Asia/Riyadh', '2026-03-05 00:00+00')
    = '2026-03-31 09:00+00',
  'monthly counts from the first date: 31 Jan → 31 Mar, not a 30-day stride');
select pg_temp.check(
  public.zad_next_appointment_start('2026-10-29 20:30+00', 'hourly', 'Africa/Cairo', '2026-10-29 23:15+00')
    = '2026-10-29 23:30+00',
  'hourly stays in absolute hours');
select pg_temp.check(
  public.zad_next_appointment_start('2026-12-01 09:00+00', 'daily', 'Africa/Cairo', '2026-10-30 00:00+00')
    = '2026-12-01 09:00+00',
  'a start still ahead is left alone');

-- ── the cron function, against now() ────────────────────────────────────────────────────────
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1') on conflict do nothing;
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000a1', 'EGP', 'EG'), ('00000000-0000-0000-0000-0000000000b1', 'SAR', 'SA');

insert into public.zad_appointments (id, user_id, title, starts_at, recurrence, status) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'صحيان', now() - interval '20 days', 'once', 'upcoming'),
  ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1', 'البنك', now() - interval '90 minutes', 'once', 'upcoming'),
  ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a1', 'دكتور', now() + interval '1 day', 'once', 'upcoming'),
  ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a1', 'نادي', now() - interval '20 days', 'once', 'cancelled'),
  ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-0000000000a1', 'اشرب مياه', now() - interval '3 days 2 hours', 'daily', 'upcoming'),
  ('00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-0000000000b1', 'اجتماع', now() - interval '15 days', 'weekly', 'upcoming');

select public.zad_enqueue_appointment_moments();

select pg_temp.check((select status from public.zad_appointments where id = '00000000-0000-0000-0000-000000000001') = 'done',
  'a one-off 20 days past is closed');
select pg_temp.check((select status from public.zad_appointments where id = '00000000-0000-0000-0000-000000000002') = 'upcoming',
  'a one-off 90 minutes past stays upcoming (the brain still sees it for two hours)');
select pg_temp.check((select status from public.zad_appointments where id = '00000000-0000-0000-0000-000000000003') = 'upcoming',
  'a future one-off is untouched');
select pg_temp.check((select status from public.zad_appointments where id = '00000000-0000-0000-0000-000000000004') = 'cancelled',
  'a cancelled one stays cancelled');
select pg_temp.check((
  select starts_at > now() - interval '10 minutes' and starts_at <= now() + interval '1 day'
    and to_char(starts_at at time zone 'Africa/Cairo', 'HH24:MI') = to_char((now() - interval '3 days 2 hours') at time zone 'Africa/Cairo', 'HH24:MI')
    and status = 'upcoming'
  from public.zad_appointments where id = '00000000-0000-0000-0000-000000000005'),
  'a daily reminder three days behind moves to its next time today/tomorrow, same Cairo wall clock');
select pg_temp.check((
  select starts_at > now() and starts_at <= now() + interval '7 days'
    and extract(isodow from starts_at at time zone 'Asia/Riyadh') = extract(isodow from (now() - interval '15 days') at time zone 'Asia/Riyadh')
  from public.zad_appointments where id = '00000000-0000-0000-0000-000000000006'),
  'a weekly meeting two weeks behind lands on its weekday within the next week, in Riyadh time');

select public.zad_enqueue_appointment_moments();
select pg_temp.check((select count(*) from public.zad_appointments where status = 'done') = 1,
  'a second run changes nothing more');
