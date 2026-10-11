-- One shopping list for the household (20261011140000). Run after
-- household_shopping_scaffold.sql and the migration; see the scaffold for the order.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- As the migration owner: what it did to existing rows.
do $$
declare fam uuid := '00000000-0000-0000-0000-0000000fa001';
begin
  -- 1. mom's old row now belongs to the household; the neighbour's stays hers alone
  assert (select family_id from zad_shopping_list where item_name = 'عيش') = fam, 'mom''s row has no family';
  assert (select family_id from zad_shopping_list where item_name = 'سكر') is null, 'neighbour''s row got a family';
  -- 2. the family tab's open line moved over, trimmed, as dad's; the bought one and the orphan did not
  assert (select user_id from zad_shopping_list where item_name = 'سيتافيل كريم')
         = '00000000-0000-0000-0000-00000000f002', 'dad''s line did not move';
  assert (select family_id from zad_shopping_list where item_name = 'سيتافيل كريم') = fam;
  assert not exists (select 1 from zad_shopping_list where item_name in ('رز', 'حليب')), 'bought or orphan line moved';
end $$;

-- 3. dad sees mom's line, can tick it (as the app's upsert does) and his own insert is household
begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000f002","role":"authenticated"}', true);
set local role authenticated;
do $$
declare mom_row record;
begin
  assert (select count(*) from zad_shopping_list) = 2, 'dad should see عيش and سيتافيل كريم, saw '
         || (select string_agg(item_name, ',') from zad_shopping_list);
  select * into mom_row from zad_shopping_list where item_name = 'عيش';
  insert into zad_shopping_list (id, user_id, item_name, is_purchased)
  values (mom_row.id, mom_row.user_id, mom_row.item_name, true)
  on conflict (id) do update set is_purchased = excluded.is_purchased;
  assert (select is_purchased from zad_shopping_list where id = mom_row.id), 'dad could not tick mom''s line';
  insert into zad_shopping_list (user_id, item_name) values (auth.uid(), 'لبن');
  assert (select family_id from zad_shopping_list where item_name = 'لبن') = '00000000-0000-0000-0000-0000000fa001',
    'dad''s new line is not the household''s';
end $$;
rollback;

-- 3b. the shared pantry: dad's edit of mom's item, sent the way the app sends it (upsert)
begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000f002","role":"authenticated"}', true);
set local role authenticated;
do $$
declare r record;
begin
  select * into r from zad_inventory where item_name = 'زيت';
  assert found, 'dad does not see mom''s pantry item';
  insert into zad_inventory (id, user_id, item_name, quantity) values (r.id, r.user_id, r.item_name, 1)
  on conflict (id) do update set quantity = excluded.quantity;
  assert (select quantity from zad_inventory where id = r.id) = 1, 'dad could not change mom''s pantry item';
end $$;
rollback;

-- 3c. nobody writes a pantry item as someone outside their household
begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000f002","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  insert into zad_inventory (user_id, item_name) values ('00000000-0000-0000-0000-00000000f003', 'دس');
  raise exception 'dad wrote a pantry item as the neighbour';
exception when insufficient_privilege then null;
end $$;
rollback;

-- 4. the neighbour sees only her own; she cannot write a line as someone else
begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000f003","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  assert (select count(*) from zad_shopping_list) = 1 and exists (select 1 from zad_shopping_list where item_name = 'سكر'),
    'the neighbour sees the family''s list';
  update zad_shopping_list set is_purchased = true where item_name = 'عيش';
  assert not found, 'the neighbour ticked the family''s line';
  begin
    insert into zad_shopping_list (user_id, item_name) values ('00000000-0000-0000-0000-00000000f001', 'دس');
    raise exception 'the neighbour wrote a line as mom';
  exception when insufficient_privilege then null; end;
end $$;
rollback;

-- 5. joining the family brings the joiner's list along, through the call join/create already make
insert into public.zad_shopping_list (user_id, item_name) values ('00000000-0000-0000-0000-00000000f004', 'زيت');
insert into public.family_members (family_id, user_id) values ('00000000-0000-0000-0000-0000000fa001', '00000000-0000-0000-0000-00000000f004');
begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000f004","role":"authenticated"}', true);
set local role authenticated;
select public.zad_inventory_backfill_on_family_join('00000000-0000-0000-0000-0000000fa001');
do $$ begin
  assert (select family_id from zad_shopping_list where item_name = 'زيت') = '00000000-0000-0000-0000-0000000fa001',
    'the joiner''s list did not follow';
  assert exists (select 1 from zad_shopping_list where item_name = 'عيش'), 'the joiner does not see the household list';
end $$;
rollback;

-- 6. someone who leaves still sees their own lines (the pantry hides them; this list does not)
begin;
delete from public.family_members where user_id = '00000000-0000-0000-0000-00000000f002';
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000f002","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  assert exists (select 1 from zad_shopping_list where item_name = 'سيتافيل كريم'), 'a leaver lost their own line';
  assert not exists (select 1 from zad_shopping_list where item_name = 'عيش'), 'a leaver still sees the family''s line';
end $$;
rollback;

\echo household_shopping_test: all checks passed
