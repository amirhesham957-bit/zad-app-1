-- Scratch shape for settings_buttons_test.sql, after the money_buttons chain: the budget columns of zad_users that the P2.5b
-- mirror (20261128260000) reads, and stand-ins for the two visibility helpers its RLS policies name (the real ones come from
-- 20261128190000_visibility_matrix, whose own chain is too wide to share with the door chain). Never against live.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
alter table public.zad_users
  add column if not exists budget double precision default 0,
  add column if not exists cycle_anchor text not null default 'day_of_month',
  add column if not exists balance_anchored_at timestamptz,
  add column if not exists travel_budget numeric,
  add column if not exists currency text;
create or replace function public.zad_i_am_minor() returns boolean language sql stable as $$ select false $$;
create or replace function public.zad_i_guard(p_target uuid) returns boolean language sql stable as $$ select false $$;
