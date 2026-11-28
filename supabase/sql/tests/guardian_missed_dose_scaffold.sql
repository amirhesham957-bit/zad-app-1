-- Scratch shape for guardian_missed_dose_test.sql (P2.6): only the columns zad_enqueue_guardian_missed_doses reads (items with dose_times, no 'missed' rows), and a consent
-- table behind a stand-in zad_family_share_granted (the live one is 20261001130000). Never against live.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
do $$ begin
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
exception when duplicate_object then null; end $$;
create schema if not exists auth;
create table auth.users (id uuid primary key);
create table public.zad_household_members (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
  display_name text not null, kind text not null, linked_user_id uuid references auth.users(id),
  guardian_member_id uuid, archived_at timestamptz);
create table public.zad_users (id uuid primary key, country text);
create or replace function public.zad_market_timezone(p_country text) returns text language sql immutable as $$ select 'UTC' $$;
create table public.zad_pharmacy_items (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, name text not null, dose_times text,
  remaining_quantity integer not null default 10, has_invalid_dose_time boolean not null default false,
  created_at timestamptz not null default now() - interval '3 days');
create table public.zad_pharmacy_doses (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, item_id uuid not null,
  scheduled_at timestamptz, taken_at timestamptz, status text not null check (status in ('taken','skipped','missed')));
create table public.zad_dose_log (id uuid primary key default gen_random_uuid(), user_id uuid, pharmacy_item_id uuid, taken_at timestamptz);
create table public.zad_dose_snoozes (user_id uuid, item_id uuid, scheduled_at timestamptz, snooze_until timestamptz);
create table public.zad_voice_moments (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, moment text not null,
  facts jsonb not null default '{}'::jsonb, dedupe_key text not null, status text not null default 'pending',
  created_at timestamptz not null default now(), unique (user_id, dedupe_key));
create table public.scratch_medicine_grants (viewer uuid, owner uuid);
create or replace function public.zad_family_share_granted(p_viewer uuid, p_owner uuid, p_scope text) returns boolean
language sql security definer set search_path = public as $$
  select p_scope = 'medicines' and exists (select 1 from public.scratch_medicine_grants where viewer = p_viewer and owner = p_owner) $$;
