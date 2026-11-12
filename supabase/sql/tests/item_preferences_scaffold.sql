-- What 20261113010000_item_preferences.sql reads beyond scratch_scaffold.sql, as live 2026-11-13.
create table public.zad_inventory (
  id uuid primary key default gen_random_uuid(), user_id uuid, item_name text not null, category text,
  quantity numeric default 0, created_at timestamptz default now(), unit text,
  low_stock_threshold numeric, family_id uuid, restock_mode text, restock_cycle_days integer);
create or replace function public.zad_inventory_name_key(p_name text) returns text language sql immutable parallel safe as $f$
  select array_to_string(array(
    select case when w like 'ال%' and length(w) > 2 then substr(w, 3) else w end
      from unnest(regexp_split_to_array(lower(translate(trim(coalesce(p_name, '')), 'أإآةى', 'اااهي')), '\s+')) w
     where w <> ''), ' '); $f$;
