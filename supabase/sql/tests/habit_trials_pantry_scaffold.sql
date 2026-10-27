-- What 20261027080000_habit_trials_pantry.sql reads beyond habit_trials_scaffold.sql, as live 2026-10-27.
create table public.zad_waste_log (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text not null,
  quantity numeric not null, unit text, logged_at timestamptz not null default now()
);
create table public.zad_inventory_observations (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text not null,
  qty numeric not null, observed_at timestamptz not null, source text, created_at timestamptz default now()
);
