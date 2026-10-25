-- Tables zad_health_brain_cost (20261025050500) reads and fills, on top of scratch_scaffold.sql. Only the columns it touches.
create table public.zad_brain_runs (id uuid primary key default gen_random_uuid(), user_id uuid, trigger text, status text,
  started_at timestamptz default now(), finished_at timestamptz, input_tokens bigint, output_tokens bigint, prompt_sizes jsonb);
create table public.zad_health_daily (day date not null, user_id uuid not null, brain_runs int default 0, primary key (day, user_id));
