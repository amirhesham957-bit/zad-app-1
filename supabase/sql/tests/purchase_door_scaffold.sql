-- Scratch scaffold for purchase_door_test.sql (migration 20261019180000). Scratch database
-- only — CI runs it on a throwaway postgres service (edge-functions.yml, job sql-tests):
--
--   psql < supabase/sql/tests/purchase_door_scaffold.sql
--   psql < supabase/migrations/20261019180000_purchase_door.sql
--   psql < supabase/sql/tests/purchase_door_test.sql
--
-- Table shapes and the constraints that can refuse a write were read off the live project
-- on 2026-10-19 (information_schema, pg_constraint, pg_trigger — read-only). Functions the
-- door calls are either copied word for word (zad_inventory_name_key, zad_pharmacy_restock,
-- populate_family_inventory) or stand-ins that record the call (prices, consumption).

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

do $$ begin
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
exception when duplicate_object then null; end $$;
create schema if not exists auth;
create schema if not exists private;
create table if not exists auth.users (id uuid primary key);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid $$;
create or replace function auth.role() returns text language sql stable as $$
  select current_setting('request.jwt.claims', true)::jsonb ->> 'role' $$;
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;

create table public.family_groups (id uuid primary key default gen_random_uuid());
create table public.family_members (user_id uuid, family_id uuid references public.family_groups(id));

create table public.zad_transactions (
  id uuid primary key default gen_random_uuid(), user_id uuid, amount double precision, title text,
  category text, is_expense boolean default true, created_at timestamptz default now(),
  wallet text default 'card', txn_kind text default 'expense', transfer_to text, merchant_name text,
  bank_name text, source_type text, is_verified boolean default true, currency text,
  counts_toward_budget boolean default true, original_amount numeric, original_currency text,
  linked_obligation_id uuid,
  constraint transfer_needs_target check (((txn_kind = 'transfer') and (transfer_to is not null)) or ((txn_kind <> 'transfer') and (transfer_to is null))),
  constraint zad_transactions_txn_kind_check check (txn_kind = any (array['expense', 'income', 'transfer'])),
  constraint zad_transactions_wallet_check check (wallet = any (array['cash', 'card', 'bank'])));

create table public.zad_inventory (
  id uuid primary key default gen_random_uuid(), user_id uuid, item_name text, category text,
  quantity integer default 1, expiry_date text, created_at timestamptz default now(),
  unit text default 'pcs', low_stock_threshold integer default 2,
  family_id uuid references public.family_groups(id) on delete set null);

create table public.zad_shopping_list (
  id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete cascade,
  item_name text, quantity integer default 1, estimated_price double precision default 0,
  is_purchased boolean default false, created_at timestamptz default now(), priority text default 'medium',
  predicted_days_left integer, store text, family_id uuid references public.family_groups(id) on delete set null);

create table public.zad_inventory_observations (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  item_name text not null, qty numeric not null check (qty >= 0), observed_at timestamptz not null default now(),
  source text not null check (source = any (array['question_answer', 'camera_ocr', 'manual', 'purchase', 'chat_add'])),
  created_at timestamptz not null default now());

create table public.zad_pharmacy_items (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, name text not null,
  category text not null default 'عام', remaining_quantity integer not null default 1,
  unit text not null default 'قرص', family_member_id uuid, created_at timestamptz default now());
create unique index zad_pharmacy_items_unique_per_owner on public.zad_pharmacy_items
  (user_id, lower(trim(both from name)), coalesce(family_member_id::text, ''));
create table public.zad_pharmacy_restocks (
  id uuid primary key, user_id uuid not null, item_id uuid not null, quantity integer not null,
  created_at timestamptz not null default now());

-- Live, word for word.
create or replace function public.populate_family_inventory() returns trigger
language plpgsql security definer set search_path to 'public' as $function$
begin
  if new.user_id is not null then
    select family_id into new.family_id from public.family_members where user_id = new.user_id limit 1;
  else
    new.family_id := null;
  end if;
  return new;
end;
$function$;
create trigger trigger_populate_family_inventory before insert or update on public.zad_inventory
  for each row execute function populate_family_inventory();
create trigger trigger_populate_family_shopping before insert or update on public.zad_shopping_list
  for each row execute function populate_family_inventory();

create or replace function public.zad_inventory_name_key(p_name text) returns text
language sql immutable parallel safe set search_path to 'pg_catalog' as $function$
  select array_to_string(array(
    select case when w like 'ال%' and length(w) > 2 then substr(w, 3) else w end
      from unnest(regexp_split_to_array(lower(translate(trim(coalesce(p_name, '')), 'أإآةى', 'اااهي')), '\s+')) w
     where w <> ''
  ), ' ');
$function$;

create or replace function public.zad_pharmacy_restock(p_user uuid, p_restock uuid, p_item uuid, p_quantity integer, p_name text default null, p_unit text default null, p_category text default null)
returns jsonb language plpgsql set search_path to 'public', 'pg_temp' as $function$
declare
  v_item public.zad_pharmacy_items%rowtype;
  v_prior uuid;
  v_logged uuid;
  v_created boolean := false;
begin
  if p_user is null or p_restock is null or p_item is null
     or p_quantity is null or p_quantity < 1 or p_quantity > 10000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;
  if auth.uid() is distinct from p_user and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select item_id into v_prior from public.zad_pharmacy_restocks where id = p_restock and user_id = p_user;
  if found then
    select * into v_item from public.zad_pharmacy_items where id = v_prior and user_id = p_user;
    return jsonb_build_object('ok', true, 'duplicate', true, 'created', false,
      'item', case when v_item.id is null then null else to_jsonb(v_item) end);
  end if;
  select * into v_item from public.zad_pharmacy_items where id = p_item and user_id = p_user for update;
  if not found then
    if nullif(btrim(p_name), '') is null then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;
    insert into public.zad_pharmacy_items (id, user_id, name, unit, category, remaining_quantity)
    values (p_item, p_user, btrim(p_name), coalesce(nullif(btrim(p_unit), ''), 'قرص'),
            coalesce(nullif(btrim(p_category), ''), 'عام'), 0)
    on conflict do nothing;
    v_created := found;
    select * into v_item from public.zad_pharmacy_items where id = p_item and user_id = p_user for update;
    if not found then
      select * into v_item from public.zad_pharmacy_items
      where user_id = p_user and lower(btrim(name)) = lower(btrim(p_name)) and family_member_id is null for update;
    end if;
    if not found then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;
  end if;
  insert into public.zad_pharmacy_restocks (id, user_id, item_id, quantity)
  values (p_restock, p_user, v_item.id, p_quantity) on conflict (id) do nothing returning id into v_logged;
  if v_logged is null then
    return jsonb_build_object('ok', true, 'duplicate', true, 'created', false, 'item', to_jsonb(v_item));
  end if;
  update public.zad_pharmacy_items set remaining_quantity = remaining_quantity + p_quantity
  where id = v_item.id returning * into v_item;
  return jsonb_build_object('ok', true, 'duplicate', false, 'created', v_created, 'added', p_quantity, 'item', to_jsonb(v_item));
end;
$function$;

-- Stand-ins that record the call.
create or replace function private.zad_product_canonical_for(p_user uuid, p_name text) returns text
language sql stable as $$ select p_name $$;

create table public.test_recomputes (user_id uuid, item text);
create or replace function public.zad_recompute_consumption(p_user uuid, p_item text) returns jsonb
language plpgsql as $$ begin insert into public.test_recomputes values (p_user, p_item); return '{}'::jsonb; end $$;

-- The live impl caps reports per hour; the stand-in refuses after two, so the test can see
-- the door stop asking and still record the purchase.
create table public.test_price_reports (report uuid primary key, user_id uuid, item text, price numeric, store text);
create or replace function private.zad_report_price_impl(p_uid uuid, p_report uuid, p_item text, p_price numeric,
  p_currency text, p_location text, p_store text, p_category text) returns jsonb
language plpgsql as $$
begin
  if (select count(*) from public.test_price_reports where user_id = p_uid) >= 2 then
    return jsonb_build_object('ok', false, 'reason', 'too_many');
  end if;
  insert into public.test_price_reports values (p_report, p_uid, p_item, p_price, p_store);
  return jsonb_build_object('ok', true);
end $$;

-- The test reads the tables back between calls under the customer's role.
grant select on all tables in schema public to authenticated;
