-- Tables the deal-reports migration (20261103170000) reads beyond deals_scaffold.sql, in the live shape:
-- zad_voice_moments (only the columns it touches) and zad_shopping_list (for deal_buttons, which runs first).
create table public.zad_voice_moments (id uuid primary key default gen_random_uuid(), user_id uuid, moment text, facts jsonb,
  status text default 'pending', created_at timestamptz default now());
create table public.zad_shopping_list (id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text not null,
  quantity integer, is_purchased boolean default false, family_id uuid, created_at timestamptz default now());
