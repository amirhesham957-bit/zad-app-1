-- What 20261028030000_past_appointments.sql reads, as live 2026-10-28 (after scratch_scaffold.sql).

\set ON_ERROR_STOP on

alter table public.zad_users add column if not exists country text;

-- zad_market_timezone as live (20261001170000), the countries the test uses.
create or replace function public.zad_market_timezone(p_country text) returns text
language sql immutable set search_path to 'public' as $$
  select case upper(coalesce(p_country, ''))
    when 'SA' then 'Asia/Riyadh' when 'EG' then 'Africa/Cairo' when 'AE' then 'Asia/Dubai'
    else 'Africa/Cairo' end;
$$;

create table if not exists public.zad_appointments (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, title text not null, kind text not null default 'personal',
  starts_at timestamptz not null, place_label text, remind_minutes_before integer not null default 30,
  recurrence text not null default 'once' check (recurrence in ('once', 'hourly', 'daily', 'weekly', 'monthly')),
  status text not null default 'upcoming' check (status in ('upcoming', 'done', 'cancelled')), source text, notes text,
  created_at timestamptz default now(), updated_at timestamptz default now(), for_person text, expected_cost numeric);

create table if not exists public.zad_voice_moments (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, moment text not null,
  facts jsonb not null default '{}'::jsonb, dedupe_key text not null, status text not null default 'pending',
  created_at timestamptz not null default now(), unique (user_id, dedupe_key));
