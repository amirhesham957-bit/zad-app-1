-- The second question in a new account's first 72 hours (migration 20261010170000).
-- Scratch database only:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/newcomer_question_test.sql
--
-- The file creates what the migration needs in its live shape (read 2026-10-10) when
-- the scaffold lacks it, stubs pg_cron, applies the migration itself, and rolls back.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

begin;

alter table public.zad_users add column if not exists country text;
alter table public.zad_users add column if not exists created_at timestamptz default now();
create table if not exists public.family_members (
  id uuid primary key default gen_random_uuid(), family_id uuid, user_id uuid, role text);
create table if not exists public.zad_voice_moments (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  moment text not null, facts jsonb not null default '{}'::jsonb, status text not null default 'pending'
    check (status in ('pending', 'sending', 'sent', 'skipped', 'failed')),
  attempts int not null default 0, dedupe_key text, created_at timestamptz not null default now(),
  sent_at timestamptz, claimed_at timestamptz, delivery jsonb, error text,
  unique (user_id, dedupe_key));

-- pg_cron, as far as the migration uses it.
create schema if not exists cron;
create table if not exists cron.job (jobname text primary key, schedule text, command text);
create or replace function cron.unschedule(p_name text) returns boolean language sql as
  $$ delete from cron.job where jobname = p_name returning true $$;
create or replace function cron.schedule(p_name text, p_schedule text, p_command text) returns bigint language sql as
  $$ insert into cron.job values (p_name, p_schedule, p_command)
     on conflict (jobname) do update set schedule = excluded.schedule, command = excluded.command returning 1::bigint $$;
insert into cron.job values ('voice-moments-processor', '*/5 * * * *', 'select 1;') on conflict do nothing;

-- now() can't be moved, so the market zone is: a zone where it is 16:00 right now
-- for 'NEW', and one where it is not for 'OFF'.
create or replace function public.zad_market_timezone(p_country text) returns text language sql stable as $$
  select 'Etc/GMT' || case when o > 0 then '-' || o else '+' || (-o) end
  from (select case when 16 - h > 14 then 16 - h - 24 else 16 - h end
                 + case when p_country = 'OFF' then 1 else 0 end as o
        from (select extract(hour from now() at time zone 'UTC')::int as h) n) x
$$;

\i supabase/migrations/20261010170000_newcomer_second_question.sql

insert into auth.users (id) values
  ('00000000-0000-0000-0000-00000000000a'), ('00000000-0000-0000-0000-00000000000b'),
  ('00000000-0000-0000-0000-00000000000c'), ('00000000-0000-0000-0000-00000000000d');
insert into public.zad_users (id, country, created_at) values
  ('00000000-0000-0000-0000-00000000000a', 'NEW', now() - interval '1 hour'),   -- new, 16:00 ⇒ asked
  ('00000000-0000-0000-0000-00000000000b', 'NEW', now() - interval '80 hours'), -- past 72 hours
  ('00000000-0000-0000-0000-00000000000c', 'NEW', now() - interval '1 hour'),   -- a child's account
  ('00000000-0000-0000-0000-00000000000d', 'OFF', now() - interval '1 hour');   -- new, but it is 17:00 there
insert into public.family_members (user_id, role) values ('00000000-0000-0000-0000-00000000000c', 'child');

do $$
declare
  v int;
  v_row public.zad_voice_moments;
  v_cmd text;
begin
  v := public.zad_enqueue_newcomer_question();
  if v <> 1 then raise exception 'expected 1 newcomer question, got %', v; end if;
  select * into v_row from public.zad_voice_moments;
  if v_row.user_id <> '00000000-0000-0000-0000-00000000000a' or v_row.moment <> 'newcomer_question'
     or v_row.status <> 'pending' or v_row.dedupe_key <> 'newcomer_question:' || (v_row.facts ->> 'local_date')
     or v_row.facts ->> 'time_zone' is null then
    raise exception 'unexpected row: %', row_to_json(v_row);
  end if;
  -- The cron runs every 5 minutes: the same day is enqueued once.
  v := public.zad_enqueue_newcomer_question();
  if v <> 0 then raise exception 'second run inserted %', v; end if;

  -- The live cron command kept every call and gained this one.
  select command into v_cmd from cron.job where jobname = 'voice-moments-processor';
  if v_cmd not like '%zad_enqueue_newcomer_question()%' then raise exception 'cron lacks the new call'; end if;
  if v_cmd not like '%zad_enqueue_missed_doses()%' or v_cmd not like '%zad_enqueue_appointment_moments()%'
     or v_cmd not like '%zad_enqueue_morning_fallback()%' or v_cmd not like '%zad_enqueue_good_night()%'
     or v_cmd not like '%zad_enqueue_weekly_money_story()%' or v_cmd not like '%zad_evaluate_savings_challenges()%'
     or v_cmd not like '%"action":"process_voice_moments"%' then
    raise exception 'cron lost a call: %', v_cmd;
  end if;
  -- Nobody but the cron calls it.
  if has_function_privilege('authenticated', 'public.zad_enqueue_newcomer_question()', 'execute')
     or has_function_privilege('anon', 'public.zad_enqueue_newcomer_question()', 'execute') then
    raise exception 'clients can run the enqueue';
  end if;
  raise notice 'newcomer_question_test: all passed';
end $$;

rollback;
