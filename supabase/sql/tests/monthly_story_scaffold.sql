-- What 20261027023000_monthly_story.sql reads beyond scratch_scaffold.sql, as live 2026-10-27.
alter table public.zad_users add column if not exists country text;
create table public.zad_transactions (
  id uuid primary key default gen_random_uuid(), user_id uuid, amount double precision, category text,
  txn_kind text, counts_toward_budget boolean, created_at timestamptz default now()
);
create table public.zad_house_learnings (
  id uuid primary key default gen_random_uuid(), user_id uuid, note text, answer text, answered_at timestamptz
);
create table public.zad_voice_moments (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, moment text not null,
  facts jsonb not null default '{}'::jsonb, dedupe_key text not null, status text not null default 'pending',
  created_at timestamptz not null default now(), unique (user_id, dedupe_key)
);
alter table auth.users add column if not exists last_sign_in_at timestamptz;
create or replace function public.zad_market_timezone(p_country text) returns text language sql immutable as $$
  select case upper(coalesce(p_country, '')) when 'SA' then 'Asia/Riyadh' else 'Africa/Cairo' end $$;
