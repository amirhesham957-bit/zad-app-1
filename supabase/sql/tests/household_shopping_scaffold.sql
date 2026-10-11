-- Live shapes (read off the project 2026-10-11) of what
-- 20261011140000_one_household_shopping_list touches, on top of scratch_scaffold.sql:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/household_shopping_scaffold.sql
--   psql < supabase/migrations/20261011140000_one_household_shopping_list.sql
--   psql < supabase/sql/tests/household_shopping_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create table if not exists public.zad_shopping_list (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_name text not null,
  quantity integer default 1,
  estimated_price double precision default 0.0,
  is_purchased boolean default false,
  created_at timestamptz default now(),
  priority text not null default 'medium',
  predicted_days_left integer,
  store text);
create index if not exists idx_zad_shopping_list_user on public.zad_shopping_list (user_id);
create unique index if not exists zad_shopping_list_unique_open_item
  on public.zad_shopping_list (user_id, lower(btrim(item_name))) where is_purchased = false;
alter table public.zad_shopping_list enable row level security;
create policy "Users can view their own shopping list" on public.zad_shopping_list for select using ((select auth.uid()) = user_id);
create policy "Users can insert their own shopping list" on public.zad_shopping_list for insert with check ((select auth.uid()) = user_id);
create policy "Users can update their own shopping list" on public.zad_shopping_list for update using ((select auth.uid()) = user_id);
create policy "Users can delete their own shopping list" on public.zad_shopping_list for delete using ((select auth.uid()) = user_id);
grant select, insert, update, delete on public.zad_shopping_list to authenticated, service_role;

create table if not exists public.shared_grocery_list (
  id uuid primary key default gen_random_uuid(),
  family_id uuid, added_by uuid, item_name text, category text,
  is_purchased boolean default false,
  created_at timestamptz default timezone('utc'::text, now()));

create table if not exists public.zad_inventory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  family_id uuid references public.family_groups(id) on delete set null,
  item_name text not null, quantity numeric default 1);

alter table public.zad_inventory enable row level security;
create policy zad_inventory_select on public.zad_inventory for select
  using (((family_id is null) and ((select auth.uid()) = user_id)) or ((family_id is not null) and (family_id in (select get_my_family_ids()))));
create policy zad_inventory_insert on public.zad_inventory for insert with check ((select auth.uid()) = user_id);
create policy zad_inventory_update on public.zad_inventory for update
  using (((family_id is null) and ((select auth.uid()) = user_id)) or ((family_id is not null) and (family_id in (select get_my_family_ids()))))
  with check (((family_id is null) and ((select auth.uid()) = user_id)) or ((family_id is not null) and (family_id in (select get_my_family_ids()))));
create policy zad_inventory_delete on public.zad_inventory for delete
  using (((family_id is null) and ((select auth.uid()) = user_id)) or ((family_id is not null) and (family_id in (select get_my_family_ids()))));
grant select, insert, update, delete on public.zad_inventory to authenticated, service_role;

create or replace function public.populate_family_inventory()
returns trigger language plpgsql security definer set search_path to 'public'
as $function$
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
  for each row execute function public.populate_family_inventory();

-- The base scaffold stubs this with another parameter name; the live one is p_family.
drop function if exists public.zad_inventory_backfill_on_family_join(uuid);
create function public.zad_inventory_backfill_on_family_join(p_family uuid)
returns void language plpgsql security definer set search_path to 'public'
as $function$
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.family_members where user_id = auth.uid() and family_id = p_family
  ) then
    raise exception 'not_a_member';
  end if;
  update public.zad_inventory
     set family_id = p_family
   where user_id = auth.uid() and (family_id is null or family_id <> p_family);
end;
$function$;
grant execute on function public.zad_inventory_backfill_on_family_join(uuid) to authenticated;

-- Fixture: a family of two (mom, dad), a neighbour, and someone who joins later.
insert into auth.users values
  ('00000000-0000-0000-0000-00000000f001'), ('00000000-0000-0000-0000-00000000f002'),
  ('00000000-0000-0000-0000-00000000f003'), ('00000000-0000-0000-0000-00000000f004')
  on conflict do nothing;
insert into public.family_groups (id) values ('00000000-0000-0000-0000-0000000fa001');
insert into public.family_members (id, family_id, user_id) values
  ('00000000-0000-0000-0000-0000000ff001', '00000000-0000-0000-0000-0000000fa001', '00000000-0000-0000-0000-00000000f001'),
  ('00000000-0000-0000-0000-0000000ff002', '00000000-0000-0000-0000-0000000fa001', '00000000-0000-0000-0000-00000000f002');
insert into public.zad_inventory (user_id, item_name, quantity) values ('00000000-0000-0000-0000-00000000f001', 'زيت', 2);
-- Rows from before the migration: mom's and the neighbour's, both with no family column yet.
insert into public.zad_shopping_list (user_id, item_name) values
  ('00000000-0000-0000-0000-00000000f001', 'عيش'),
  ('00000000-0000-0000-0000-00000000f003', 'سكر');
-- The family tab's old list: one open line by dad, one already bought, one by a member who is gone.
insert into public.shared_grocery_list (family_id, added_by, item_name, is_purchased) values
  ('00000000-0000-0000-0000-0000000fa001', '00000000-0000-0000-0000-0000000ff002', ' سيتافيل كريم ', false),
  ('00000000-0000-0000-0000-0000000fa001', '00000000-0000-0000-0000-0000000ff002', 'رز', true),
  ('00000000-0000-0000-0000-0000000fa001', '00000000-0000-0000-0000-0000000ff0dd', 'حليب', false);
