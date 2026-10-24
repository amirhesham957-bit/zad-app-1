-- Tables zad_held_messages (20261025003500) reads, on top of scratch_scaffold.sql. Only the columns it touches.
create table public.agent_tasks (id uuid primary key default gen_random_uuid(), user_id uuid, kind text, status text,
  result text, updated_at timestamptz default now(), created_at timestamptz default now());
create table public.zad_voice_moments (id uuid primary key default gen_random_uuid(), user_id uuid, moment text, status text,
  error text, created_at timestamptz default now(), claimed_at timestamptz);
