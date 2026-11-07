-- قناة المؤسس (20261107101500). Scratch database only:
--
--   psql < supabase/sql/tests/founder_channel_test.sql   -- stand-ins, the migration, then the checks
--
-- What it proves: the report counts people and homes and never names one (no user id, no store, no
-- amount of anybody's), the city demand line stays silent under 5 homes and speaks at 5, a family
-- is one home, the probe account is outside every number, and each instant alert goes once a day.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role; end if;
end $$;

-- pg_cron, as far as the migration uses it.
create schema if not exists cron;
create table if not exists cron.job (jobname text primary key, schedule text, command text);
create or replace function cron.unschedule(p_name text) returns boolean language sql as
  $$ delete from cron.job where jobname = p_name returning true $$;
create or replace function cron.schedule(p_name text, p_schedule text, p_command text) returns bigint language sql as
  $$ insert into cron.job values (p_name, p_schedule, p_command)
     on conflict (jobname) do update set schedule = excluded.schedule, command = excluded.command returning 1::bigint $$;

-- The admin sender: captured, not sent.
create table if not exists public._admin_sent (title text, body text);
create or replace function public.zad_notify_admin(p_title text, p_body text) returns void language sql as
  $$ insert into public._admin_sent values (p_title, p_body) $$;

-- The tables the report reads, with the live columns it uses.
create table if not exists public.zad_users (id uuid primary key, country text, created_at timestamptz default now());
create table if not exists public.zad_product_events (id bigserial, user_id uuid, name text, at timestamptz);
create table if not exists public.zad_customer_profile (user_id uuid primary key, city text);
create table if not exists public.zad_shopping_list (
  id uuid default gen_random_uuid(), user_id uuid, family_id uuid, item_name text, created_at timestamptz default now());
create table if not exists public.zad_health_daily (
  day date, user_id uuid, brain_runs int, brain_runs_failed int, brain_cost_usd numeric, brain_p90_secs numeric,
  guardian_delivered int, guardian_replied int, guardian_acted int);
create table if not exists public.zad_eval_nights (day date primary key, run_id uuid);
-- The verdict, steered by the test.
create table if not exists public._verdicts (day date primary key, v jsonb);
create or replace function public.zad_eval_verdict(p_day date default ((now() at time zone 'utc')::date)) returns jsonb
  language sql as $$ select coalesce((select v from public._verdicts where day = p_day),
                                     jsonb_build_object('finished', false, 'green', false)) $$;

\i supabase/migrations/20261107101500_founder_channel.sql

do $$
declare
  probe constant uuid := 'a11ce000-0000-4000-8000-00000000a11a';
  fam constant uuid := '00000000-0000-0000-0000-0000000000f1';
  u uuid[] := array(select gen_random_uuid() from generate_series(1, 6));
  t text;
  n int;
begin
  -- Six people (two of them one family) and the probe.
  insert into zad_users (id, country) select x, 'EG' from unnest(u) x;
  insert into zad_users (id, country) values (probe, 'EG');
  insert into zad_customer_profile select x, 'القاهرة' from unnest(u) x;
  insert into zad_customer_profile values (probe, 'القاهرة');
  insert into zad_product_events (user_id, name, at)
    select x, 'app_open', now() - interval '1 day' from unnest(u) x;
  insert into zad_product_events (user_id, name, at) values (probe, 'app_open', now());

  -- «زيت» on 4 homes' lists: u1+u2 are one family, u3, u4 — plus the probe. Under the floor.
  insert into zad_shopping_list (user_id, family_id, item_name) values
    (u[1], fam, 'زيت'), (u[2], fam, 'زيت'), (u[3], null, 'زيت'), (u[4], null, 'زيت'), (u[5], null, 'زيت'),
    (probe, null, 'زيت');
  t := public.zad_founder_report();
  assert t like '%لسه مفيش صنف دخل قايمة 5 بيوت%', 'four homes (a family counts once, the probe not at all) stay silent: ' || t;
  assert t like '%6 حساب%', 'the probe is not counted: ' || t;

  -- A fifth home: now it speaks, as a count.
  insert into zad_shopping_list (user_id, family_id, item_name) values (u[6], null, 'زيت ');
  t := public.zad_founder_report();
  assert t like '%القاهرة: زيت (5 بيت)%', 'five homes in one city: ' || t;

  -- Never a person.
  for n in 1..6 loop
    assert position(u[n]::text in t) = 0, 'a user id leaked';
  end loop;
  assert position(probe::text in t) = 0, 'the probe id leaked';

  -- Instant alerts: a bank cut-off, once a day.
  insert into zad_product_events (user_id, name, at) values (u[3], 'bank.off', now() - interval '10 minutes');
  assert public.zad_founder_watch() = 1, 'bank off alerts';
  assert public.zad_founder_watch() = 0, 'and only once that day';
  assert (select body from _admin_sent where title like '%البنك%') like '%عند 1 حساب%', 'as a count';

  -- A red night alerts; an unfinished or green one does not.
  insert into _verdicts values ((now() at time zone 'utc')::date,
    '{"finished": true, "green": false, "passed": 160, "ran": 185, "pct": 86, "safety_failed": 1, "failed_cases": ["q_euro"]}');
  assert public.zad_founder_watch() = 1, 'red night alerts';
  assert (select body from _admin_sent where title like '%التقييم%') like '%q_euro%', 'with the failed cases';

  -- The weekly report goes to the admin chat.
  perform public.zad_founder_weekly();
  assert exists (select 1 from _admin_sent where title = '📊 تقرير زاد الأسبوعي'), 'weekly report sent';

  -- Scheduled.
  assert (select schedule from cron.job where jobname = 'founder-weekly') = '5 5 * * 0', 'sunday';
  assert exists (select 1 from cron.job where jobname = 'founder-watch'), 'hourly watch';
  raise notice 'founder channel: ok';
end $$;
