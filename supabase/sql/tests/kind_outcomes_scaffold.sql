-- zad_guardian_outcomes as live (20261011230000 + 20261019100000), on top of scratch_scaffold.sql.
create table public.zad_guardian_outcomes (
  id uuid primary key default gen_random_uuid(), task_id uuid not null unique, user_id uuid not null, kind text not null,
  delivered_at timestamptz not null, replied_within_day boolean not null, judged_at timestamptz not null default now(),
  acted_within_2h boolean, dismissed boolean);
