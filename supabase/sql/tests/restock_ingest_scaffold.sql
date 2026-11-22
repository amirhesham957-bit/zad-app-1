-- Minimal stand-in for zad_deals (the real one needs the whole deals chain). Scratch only.
create or replace function public.zad_inventory_name_key(p text) returns text language sql immutable as $$ select lower(btrim(p)) $$;
create table if not exists public.zad_deals (
  country text not null, store_key text not null, item_key text not null, source_kind text not null,
  lat double precision, lng double precision, found_at timestamptz not null default now(), expires_at timestamptz not null
);
