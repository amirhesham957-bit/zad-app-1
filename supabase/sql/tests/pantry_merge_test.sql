-- One pantry row per item (migration 20261010140000). Scratch database only:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/pantry_merge_test.sql     -- table, data, the migration, checks
--
-- The table, its waste trigger and `zad_try_date` are recreated here in their live shape
-- (read 2026-10-10).

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

drop table if exists public.zad_inventory cascade;
drop table if exists public.zad_waste_log cascade;
create table public.zad_inventory (
  id uuid primary key default gen_random_uuid(), user_id uuid, item_name text, category text,
  quantity integer, expiry_date text, created_at timestamptz default now(), unit text,
  low_stock_threshold integer, family_id uuid);
create table public.zad_waste_log (user_id uuid, item_name text, quantity integer, unit text);

create or replace function public.zad_try_date(p text) returns date language plpgsql immutable as $$
begin return p::date; exception when others then return null; end $$;

create or replace function public.zad_log_inventory_waste() returns trigger language plpgsql as $$
declare v_expiry date;
begin
  if TG_OP = 'DELETE' then
    if OLD.quantity <= 0 or OLD.expiry_date is null then return OLD; end if;
    v_expiry := zad_try_date(OLD.expiry_date);
    if v_expiry is not null and v_expiry < current_date then
      insert into public.zad_waste_log values (OLD.user_id, OLD.item_name, OLD.quantity, OLD.unit);
    end if;
    return OLD;
  end if;
  if NEW.quantity = 0 and OLD.quantity > 0 and OLD.expiry_date is not null then
    v_expiry := zad_try_date(OLD.expiry_date);
    if v_expiry is not null and v_expiry < current_date then
      insert into public.zad_waste_log values (OLD.user_id, OLD.item_name, OLD.quantity, OLD.unit);
    end if;
  end if;
  return NEW;
end $$;
create trigger trigger_log_inventory_waste before delete or update on public.zad_inventory
  for each row execute function public.zad_log_inventory_waste();

-- a = the owner, b = someone else.
insert into public.zad_inventory (user_id, item_name, category, quantity, unit, expiry_date, created_at, low_stock_threshold) values
  -- The owner's بلح: البقالة then الفواكه, 1 كيلو each.
  ('00000000-0000-0000-0000-00000000000a', 'بلح', 'البقالة', 1, 'كيلو', null, '2026-09-20', null),
  ('00000000-0000-0000-0000-00000000000a', 'بلح', 'الفواكه', 1, 'كيلو', null, '2026-10-01', 2),
  -- Spelling the app already treats as one: «الجبنة» / «جبنه», «إندومي» / «اندومي».
  ('00000000-0000-0000-0000-00000000000a', 'الجبنة الرومي', 'الألبان', 0, 'علبة', '2026-01-01', '2026-08-01', null),
  ('00000000-0000-0000-0000-00000000000a', 'جبنه رومي', 'عام', 2, 'علبة', '2026-12-01', '2026-10-05', null),
  ('00000000-0000-0000-0000-00000000000a', 'جبنة رومي', null, 1, 'علبة', '2026-11-01', '2026-09-01', null),
  -- An expired duplicate that still had stock: moved, not wasted.
  ('00000000-0000-0000-0000-00000000000a', 'إندومي', 'البقالة', 3, 'كيس', '2020-01-01', '2026-07-01', null),
  ('00000000-0000-0000-0000-00000000000a', 'اندومي', 'البقالة', 2, 'كيس', '2027-01-01', '2026-10-02', null),
  -- Not merged: another unit, a looser name, another account.
  ('00000000-0000-0000-0000-00000000000a', 'سكر', 'البقالة', 1, 'كيلو', null, '2026-09-01', null),
  ('00000000-0000-0000-0000-00000000000a', 'سكر', 'البقالة', 5, 'كيس', null, '2026-10-01', null),
  ('00000000-0000-0000-0000-00000000000a', 'لبن', 'الألبان', 1, 'لتر', null, '2026-09-01', null),
  ('00000000-0000-0000-0000-00000000000a', 'لبن زبادي', 'الألبان', 4, 'لتر', null, '2026-10-01', null),
  ('00000000-0000-0000-0000-00000000000b', 'بلح', 'الفواكه', 1, 'كيلو', null, '2026-09-01', null);

\ir ../../migrations/20261010140000_pantry_one_row_per_item.sql

do $$
declare
  a uuid := '00000000-0000-0000-0000-00000000000a';
  b uuid := '00000000-0000-0000-0000-00000000000b';
  r record;
begin
  assert zad_inventory_name_key('  الجبنة   الرومي ') = 'جبنه رومي', zad_inventory_name_key('  الجبنة   الرومي ');
  assert zad_inventory_name_key('إندومي') = zad_inventory_name_key('اندومي');
  assert zad_inventory_name_key('مستشفى') = 'مستشفي';
  assert zad_inventory_name_key(null) = '';

  -- بلح: one row, both kilos, the specific category, the threshold that was set.
  select * into r from zad_inventory where user_id = a and item_name = 'بلح';
  assert (select count(*) from zad_inventory where user_id = a and item_name = 'بلح') = 1;
  assert r.quantity = 2 and r.category = 'الفواكه' and r.unit = 'كيلو' and r.low_stock_threshold = 2, r::text;

  -- Three spellings of the cheese: the newest name, stock added, ...
  assert (select count(*) from zad_inventory where user_id = a and zad_inventory_name_key(item_name) = 'جبنه رومي') = 1;
  select * into r from zad_inventory where user_id = a and zad_inventory_name_key(item_name) = 'جبنه رومي';
  assert r.item_name = 'جبنه رومي' and r.quantity = 3, r::text;
  -- ... «الألبان» over «عام», and the earliest expiry among rows that still have stock
  -- (the empty row's 2026-01-01 is not the one to use first).
  assert r.category = 'الألبان' and r.expiry_date = '2026-11-01', r::text;

  -- The expired اندومي with 3 in stock moved into the kept row; nothing logged as waste.
  select * into r from zad_inventory where user_id = a and zad_inventory_name_key(item_name) = 'اندومي';
  assert r.quantity = 5 and r.expiry_date = '2020-01-01', r::text;
  assert not exists (select 1 from zad_waste_log), (select string_agg(item_name, ',') from zad_waste_log);

  -- Untouched.
  assert (select count(*) from zad_inventory where user_id = a and item_name = 'سكر') = 2;
  assert (select count(*) from zad_inventory where user_id = a and item_name in ('لبن', 'لبن زبادي')) = 2;
  assert (select quantity from zad_inventory where user_id = b and item_name = 'بلح') = 1;
  -- 12 rows in, 4 folded into their kept rows.
  assert (select count(*) from zad_inventory) = 8, (select count(*) from zad_inventory)::text;

  -- The waste trigger is back on afterwards.
  assert (select tgenabled from pg_trigger where tgname = 'trigger_log_inventory_waste') = 'O';
end $$;

-- A second run changes nothing.
\ir ../../migrations/20261010140000_pantry_one_row_per_item.sql
do $$ begin
  assert (select count(*) from zad_inventory) = 8;
  assert (select quantity from zad_inventory where item_name = 'بلح' and user_id = '00000000-0000-0000-0000-00000000000a') = 2;
end $$;

select 'pantry_merge_test: all passed' as result;
