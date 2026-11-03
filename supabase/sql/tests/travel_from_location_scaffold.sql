-- What 20261103180000_travel_from_location.sql reads beyond scratch_scaffold.sql, in the live shape (2026-11-03):
-- zad_users' market, travel and last-point columns, and zad_voice_moments with its (user_id, dedupe_key) key.
alter table public.zad_users
  add column if not exists country text,
  add column if not exists travel_country text,
  add column if not exists travel_since timestamptz,
  add column if not exists last_lat double precision,
  add column if not exists last_lon double precision,
  add column if not exists last_location_at timestamptz;
create table public.zad_voice_moments (id uuid primary key default gen_random_uuid(), user_id uuid, moment text, facts jsonb,
  dedupe_key text, status text default 'pending', created_at timestamptz default now(), unique (user_id, dedupe_key));
