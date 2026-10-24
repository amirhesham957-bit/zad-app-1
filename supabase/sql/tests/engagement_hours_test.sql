-- الوقت اللي العميل بيرد فيه (migration 20261024223500, ZAD_PLAN 1.6), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261024223500_engagement_hours.sql
--   psql < supabase/sql/tests/engagement_hours_test.sql
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
alter table public.zad_users add column if not exists country text;
create or replace function public.zad_market_timezone(p_country text) returns text language sql as $$
  select case p_country when 'SA' then 'Asia/Riyadh' else 'Africa/Cairo' end $$;
create table public.zad_chat_turns (user_id uuid, role text, created_at timestamptz);
create table public.telegram_checkin_prompts (user_id uuid, answered_at timestamptz);
create table public.zad_product_events (user_id uuid, at timestamptz);
create table public.zad_day_closes (user_id uuid, created_at timestamptz);
create table public.zad_guardian_outcomes (user_id uuid, delivered_at timestamptz, acted_within_2h boolean, replied_within_day boolean);
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1') on conflict do nothing;
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000a1', 'SAR', 'SA'), ('00000000-0000-0000-0000-0000000000b1', 'EGP', 'EG');
\set QUIET 0

-- A answers at 9 p.m. Riyadh (18:00 UTC) on every channel; B has nothing.
\set a '''00000000-0000-0000-0000-0000000000a1'''
insert into public.zad_chat_turns values (:a, 'user', date_trunc('day', now()) - interval '1 day' + interval '18 hours 5 minutes'),
                                         (:a, 'assistant', date_trunc('day', now()) - interval '1 day' + interval '18 hours 6 minutes');
insert into public.telegram_checkin_prompts values (:a, date_trunc('day', now()) - interval '2 days' + interval '18 hours 10 minutes'), (:a, null);
insert into public.zad_product_events values (:a, date_trunc('day', now()) - interval '3 days' + interval '18 hours 20 minutes');
insert into public.zad_day_closes values (:a, date_trunc('day', now()) - interval '4 days' + interval '18 hours 30 minutes');
insert into public.zad_guardian_outcomes values
  (:a, date_trunc('day', now()) - interval '5 days' + interval '18 hours', true, false),
  (:a, date_trunc('day', now()) - interval '5 days' + interval '7 hours', false, false);
-- older than 30 days: not counted.
insert into public.zad_chat_turns values (:a, 'user', now() - interval '40 days');

select pg_temp.check(array_length(public.zad_engagement_hours(:a), 1) = 24, '24 hours');
select pg_temp.check((public.zad_engagement_hours(:a))[22] = 5, 'five acts at 21:00 Riyadh (index 22 = hour 21)');
select pg_temp.check((select sum(x) from unnest(public.zad_engagement_hours(:a)) x) = 5,
  'assistant turns, unanswered prompts, ignored guardian messages and old turns do not count');
select pg_temp.check((select sum(x) from unnest(public.zad_engagement_hours('00000000-0000-0000-0000-0000000000b1')) x) = 0, 'another account: zero');
select pg_temp.check(public.zad_engagement_hours('00000000-0000-0000-0000-0000000000c1') is null, 'unknown account: null');
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_engagement_hours(uuid)', 'execute'), 'customers cannot read it');
