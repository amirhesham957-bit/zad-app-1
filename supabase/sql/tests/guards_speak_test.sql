-- الحراس بيتكلموا (migration 20261025003500, ZAD_PLAN 3.5), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/guards_speak_scaffold.sql
--   psql < supabase/migrations/20261025003500_guards_speak.sql
--   psql < supabase/sql/tests/guards_speak_test.sql
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
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set b '''00000000-0000-0000-0000-0000000000b1'''
insert into auth.users values (:a), (:b) on conflict do nothing;
insert into public.agent_tasks (user_id, kind, status, result, held_reason, held_count, held_at, updated_at) values
  (:a, 'predicted_shortage', 'pending', null, 'reply_hour', 2, now() - interval '1 hour', now() - interval '1 hour'),
  (:a, 'habit_budget', 'done', 'تمام', 'quiet_hours', 1, now() - interval '2 days', now() - interval '2 days'),
  (:a, 'spend_forecast', 'cancelled', 'expired: spend_forecast found no slot before it went stale (daily_cap)', 'daily_cap', 1, now() - interval '3 hours', now() - interval '3 hours'),
  (:a, 'pet_call', 'cancelled', 'duplicate: pet_call already sent in the last 20h', null, 0, null, now() - interval '5 hours'),
  (:a, 'goal_review', 'cancelled', 'user cancelled', null, 0, null, now() - interval '1 hour'),
  (:a, 'bill_reminder', 'done', 'تمام', null, 0, null, now()),
  (:a, 'warranty_reminder', 'pending', null, 'pacing', 1, now() - interval '20 days', now() - interval '20 days'),
  (:b, 'habit_budget', 'pending', null, 'muted', 1, now(), now());
insert into public.zad_voice_moments (user_id, moment, status, error, created_at) values
  (:a, 'good_night', 'skipped', 'quiet_hours', now() - interval '6 hours'),
  (:a, 'close_day', 'skipped', 'no longer relevant', now() - interval '7 hours'),
  (:a, 'weekly_money_story', 'skipped', 'nothing to tell this week', now() - interval '1 day'),
  (:a, 'morning_greeting', 'sent', null, now() - interval '8 hours'),
  (:a, 'shopping_zone_warning', 'skipped', 'merged into place_reminder', now() - interval '2 hours');
\set QUIET 0

select pg_temp.check((select count(*) from public.zad_held_messages(:a, 7)) = 7, 'seven held this week: 2 postponed, 2 dropped tasks, 3 dropped moments');
select pg_temp.check((select reason = 'reply_hour' and action = 'waiting' and times = 2 from public.zad_held_messages(:a, 7) where kind = 'predicted_shortage'),
  'a task still waiting says which guard and how many times');
select pg_temp.check((select reason = 'expired' and action = 'dropped' from public.zad_held_messages(:a, 7) where kind = 'spend_forecast'),
  'an expired task is dropped, not postponed, and appears once');
select pg_temp.check((select reason = 'duplicate' from public.zad_held_messages(:a, 7) where kind = 'pet_call'), 'a duplicate says so');
select pg_temp.check(not exists (select 1 from public.zad_held_messages(:a, 7) where kind in ('goal_review', 'bill_reminder')),
  'a task the customer cancelled, or one never held, is not a guard');
select pg_temp.check((select string_agg(reason, ',' order by reason) from public.zad_held_messages(:a, 7) where source = 'moment')
  = (select string_agg(x, ',' order by x) from unnest(array['nothing_new', 'not_relevant', 'quiet_hours']) x), 'skipped moments carry their reason codes; sent ones, and ones said inside another message, are not listed');
select pg_temp.check(not exists (select 1 from public.zad_held_messages(:a, 7) where kind = 'warranty_reminder'), 'older than the window is not listed');
select pg_temp.check((select count(*) from public.zad_held_messages(:a, 30)) = 8, 'a 30-day window reaches it');

-- The customer sees their own, never another account's; the service door is not theirs.
set role authenticated;
select pg_temp.who(:a);
select pg_temp.check((select count(*) from public.zad_my_held_messages(7)) = 7, 'the customer reads their own week');
select pg_temp.check(not exists (select 1 from public.zad_my_held_messages(7) where reason = 'muted'), 'and nothing of another account');
reset role;
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_held_messages(uuid, int)', 'execute'), 'customers cannot read by user id');
