-- A Supabase-shaped scratch database for the behaviour tests beside this file:
-- the roles, auth.uid()/auth.role() read from request.jwt.claims as PostgREST
-- sets them, and the live shapes (read off the project 2026-09-21) of the
-- tables the 2026-09-21 migrations touch — columns, indexes, RLS policies.
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20260921130000_family_membership_through_the_server.sql
--   psql < supabase/migrations/20260921140000_pharmacy_restock.sql
--   psql < supabase/migrations/20260921150000_family_money_through_the_server.sql
--   psql < supabase/migrations/20260921160000_price_reports_through_the_server.sql
--   psql < supabase/sql/tests/pharmacy_restock_test.sql
--   psql < supabase/sql/tests/family_money_test.sql
--   psql < supabase/sql/tests/price_reports_test.sql
--
-- Never against the live project: it writes, and the guard below refuses.

\set ON_ERROR_STOP on

-- Scratch databases only: these files write rows. A real Supabase database has a
-- storage schema; refuse before touching anything.
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- Minimal Supabase shape: roles, auth.uid()/auth.role() from request.jwt.claims.
create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid $$;
create function auth.role() returns text language sql stable as $$
  select current_setting('request.jwt.claims', true)::jsonb ->> 'role' $$;
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

-- zad_pharmacy_items as live (2026-09-21).
create table public.zad_pharmacy_items (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, name text not null,
  active_ingredient text, category text not null default 'عام', dosage text,
  remaining_quantity integer not null default 1, unit text not null default 'قرص',
  daily_dose_count integer not null default 1, expiry_date text, price double precision not null default 0,
  is_recurring boolean not null default false, family_member_id uuid, created_at timestamptz default now(),
  dose_times text, units_per_dose numeric, qty_confirmed_at timestamptz,
  has_invalid_dose_time boolean not null default false, dose_carry numeric not null default 0);
create unique index zad_pharmacy_items_unique_per_owner on public.zad_pharmacy_items
  (user_id, lower(trim(both from name)), coalesce(family_member_id::text, ''));
alter table public.zad_pharmacy_items enable row level security;
create policy user_own_pharmacy_items on public.zad_pharmacy_items for all using ((select auth.uid()) = user_id);

-- Live shapes, 2026-09-21.
create table public.family_groups (id uuid primary key default gen_random_uuid(), invite_code text, created_at timestamptz default now());
create table public.family_members (
  id uuid primary key default gen_random_uuid(), family_id uuid references public.family_groups(id) on delete cascade, user_id uuid,
  role text default 'member', alias text, created_at timestamptz default now(), balance numeric default 0, savings_goal numeric default 0,
  zad_id text, last_seen_at timestamptz default now(), daily_limit numeric, weekly_limit numeric);
create or replace function public.get_my_family_ids() returns setof uuid language sql stable security definer set search_path = public as $$
  select family_id from family_members where user_id = auth.uid(); $$;
alter table public.family_members enable row level security;
alter table public.family_groups enable row level security;
create policy family_members_select on public.family_members for select using ((family_id in (select get_my_family_ids())) or user_id = (select auth.uid()));
create function public.zad_inventory_backfill_on_family_join(p uuid) returns void language sql as $$ select $$;

create table public.family_chores (id uuid primary key default gen_random_uuid(), family_id uuid, assigned_to uuid, title text, due_date text,
  is_completed boolean default false, created_at timestamptz default now(), reward_amount numeric default 0);
alter table public.family_chores enable row level security;
create policy family_chores_delete on public.family_chores for delete using (family_id in (select get_my_family_ids()));
create policy family_chores_insert on public.family_chores for insert with check (family_id in (select get_my_family_ids()));
create policy family_chores_select on public.family_chores for select using (family_id in (select get_my_family_ids()));
create policy family_chores_update on public.family_chores for update using (family_id in (select get_my_family_ids()));

create table public.family_financial_challenges (id uuid primary key default gen_random_uuid(), family_id uuid, challenge_type text default 'monthly',
  title text, description text, target_amount numeric default 0, reward_amount numeric default 0, start_date timestamptz, end_date timestamptz,
  is_active boolean default true, created_at timestamptz default now());
alter table public.family_financial_challenges enable row level security;
create policy family_financial_challenges_insert on public.family_financial_challenges for insert with check (family_id in (select get_my_family_ids()));
create policy family_financial_challenges_select on public.family_financial_challenges for select using (family_id in (select get_my_family_ids()));
create policy family_financial_challenges_update on public.family_financial_challenges for update using (family_id in (select get_my_family_ids()));

create table public.financial_challenge_progress (id uuid primary key default gen_random_uuid(), challenge_id uuid, user_id uuid,
  current_amount numeric default 0, is_completed boolean default false, completed_at timestamptz, created_at timestamptz default now());
alter table public.financial_challenge_progress enable row level security;
create policy financial_challenge_progress_insert on public.financial_challenge_progress for insert with check ((select auth.uid()) = user_id);
create policy financial_challenge_progress_select on public.financial_challenge_progress for select using (challenge_id in (select id from family_financial_challenges where family_id in (select get_my_family_ids())));
create policy financial_challenge_progress_update on public.financial_challenge_progress for update using ((select auth.uid()) = user_id);

create table public.chat_messages (id uuid primary key default gen_random_uuid(), family_id uuid, sender_id text, message text,
  created_at timestamptz default now(), message_type text, metadata text, is_pinned boolean, reactions text, voice_url text);
alter table public.chat_messages enable row level security;
create policy chat_messages_select on public.chat_messages for select using (family_id in (select get_my_family_ids()));
create policy chat_messages_insert on public.chat_messages for insert with check (family_id in (select get_my_family_ids()));
create policy chat_messages_update on public.chat_messages for update using (family_id in (select get_my_family_ids()));

create table public.family_messages (id uuid primary key default gen_random_uuid(), family_id uuid, sender_id uuid, message text,
  message_type text default 'TEXT', metadata text, created_at timestamptz default now());
alter table public.family_messages enable row level security;
create policy family_messages_auth on public.family_messages for all using ((select auth.role()) = 'authenticated');

create table public.app_notifications (id uuid primary key default gen_random_uuid(), user_id uuid not null, title varchar not null, message text not null,
  is_read boolean default false, created_at timestamptz default now());
alter table public.app_notifications enable row level security;
create policy users_read_own_notifications on public.app_notifications for select using (user_id = (select auth.uid()));

-- price_index and the zad_users column zad_report_price reads, as live 2026-09-21.
create table public.zad_users (id uuid primary key, currency text);
create table public.price_index (
  id bigserial primary key, item_name text not null, item_category text, price double precision not null,
  currency text not null default 'EGP', user_id uuid references auth.users(id) on delete set null, location text,
  source text not null default 'usda', "timestamp" timestamptz not null default now(),
  store_name text check (store_name is null or char_length(store_name) <= 60));
alter table public.price_index enable row level security;
create policy price_index_public_read on public.price_index for select using (true);
create policy price_index_server_write on public.price_index for insert with check (user_id is null);
create policy price_index_user_crowdsource_write on public.price_index for insert
  with check ((user_id is null) or ((select auth.uid()) = user_id));
create or replace function public.zad_cheapest_prices(p_currency text, p_location text default null, p_days int default 14, p_limit int default 20)
returns table (item_name text, min_price double precision, avg_price double precision, reports int,
  cheapest_location text, cheapest_store text, last_reported timestamptz)
language sql stable set search_path to 'public' as $$ select null::text, 0::float8, 0::float8, 0, null::text, null::text, now() where false $$;
