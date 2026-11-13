-- What 20261113110000_asks_after_you.sql reads beyond scratch_scaffold.sql, as live 2026-11-13.
alter table public.zad_users add column if not exists country text;
create table public.zad_product_events (id uuid primary key default gen_random_uuid(), user_id uuid, name text, at timestamptz default now());
create table public.zad_chat_turns (id uuid primary key default gen_random_uuid(), user_id uuid, role text, text text, created_at timestamptz default now());
create table public.telegram_bindings (user_id uuid, chat_id bigint);
create table public.zad_transactions (
  id uuid primary key default gen_random_uuid(), user_id uuid, amount double precision, txn_kind text, created_at timestamptz default now()
);
create table public.zad_voice_moments (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, moment text not null,
  facts jsonb not null default '{}'::jsonb, dedupe_key text not null, status text not null default 'pending',
  created_at timestamptz not null default now(), unique (user_id, dedupe_key)
);
create or replace function public.zad_market_timezone(p_country text) returns text language sql immutable as $$
  select case upper(coalesce(p_country, '')) when 'SA' then 'Asia/Riyadh' else 'Africa/Cairo' end $$;
