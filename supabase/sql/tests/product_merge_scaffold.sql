-- On top of product_identity_scaffold.sql + 20261011200000: what
-- 20261011210000_product_merge touches besides — the waste trigger (repo 20260901050000),
-- zad_try_date, and the pantry's other columns.
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/household_shopping_scaffold.sql
--   psql < supabase/migrations/20261011140000_one_household_shopping_list.sql
--   psql < supabase/sql/tests/product_identity_scaffold.sql
--   psql < supabase/migrations/20261011200000_product_identity.sql
--   psql < supabase/sql/tests/product_merge_scaffold.sql
--   psql < supabase/migrations/20261011210000_product_merge.sql
--   psql < supabase/sql/tests/product_merge_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

alter table public.zad_inventory add column if not exists category text;
alter table public.zad_inventory add column if not exists expiry_date text;
alter table public.zad_inventory add column if not exists low_stock_threshold numeric;
alter table public.zad_inventory add column if not exists created_at timestamptz default now();

CREATE OR REPLACE FUNCTION public.zad_try_date(p_text TEXT)
RETURNS DATE LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
  RETURN left(btrim(p_text), 10)::date;
EXCEPTION WHEN others THEN
  RETURN NULL;
END $$;

create table if not exists public.zad_waste_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_name text not null,
  quantity numeric not null,
  unit text,
  logged_at timestamptz not null default now());

create or replace function public.zad_log_inventory_waste()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_expiry date;
  v_was_expired boolean;
begin
  if TG_OP = 'DELETE' then
    if OLD.quantity <= 0 or OLD.expiry_date is null then
      return OLD;
    end if;
    v_expiry := zad_try_date(OLD.expiry_date);
    if v_expiry is not null and v_expiry < current_date then
      insert into public.zad_waste_log (user_id, item_name, quantity, unit)
      values (OLD.user_id, OLD.item_name, OLD.quantity, OLD.unit);
    end if;
    return OLD;
  end if;

  -- UPDATE: بس الانتقال لصفر (مش كل تعديل) وبس لو كان فيه كمية فعلية اتلغت.
  if NEW.quantity = 0 and OLD.quantity > 0 and OLD.expiry_date is not null then
    v_expiry := zad_try_date(OLD.expiry_date);
    if v_expiry is not null and v_expiry < current_date then
      insert into public.zad_waste_log (user_id, item_name, quantity, unit)
      values (OLD.user_id, OLD.item_name, OLD.quantity, OLD.unit);
    end if;
  end if;
  return NEW;
end;
$function$;

drop trigger if exists trigger_log_inventory_waste on public.zad_inventory;
create trigger trigger_log_inventory_waste before delete or update on public.zad_inventory
  for each row execute function public.zad_log_inventory_waste();
