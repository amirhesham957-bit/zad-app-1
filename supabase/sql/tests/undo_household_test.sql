-- «تراجع» knows the household (20261011160000). Run after undo_household_scaffold.sql
-- and the migration; see the scaffold for the order. Family: mom f001, dad f002 (fa001);
-- neighbour f003.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- What the brain did as dad, logged the way recordAction logs it.
insert into public.zad_shopping_list (id, user_id, item_name) values
  ('00000000-0000-0000-0000-0000000005a1', '00000000-0000-0000-0000-00000000f001', 'جبنة');
update public.zad_shopping_list set is_purchased = true where id = '00000000-0000-0000-0000-0000000005a1';
insert into public.agent_actions (id, user_id, tool_name, target_table, target_id, previous_state, new_state) values
  ('00000000-0000-0000-0000-00000000ac01', '00000000-0000-0000-0000-00000000f002', 'complete_shopping_item',
   'zad_shopping_list', '00000000-0000-0000-0000-0000000005a1',
   (select to_jsonb(s) || '{"is_purchased": false}' from zad_shopping_list s where id = '00000000-0000-0000-0000-0000000005a1'),
   '{"is_purchased": true}');

update public.zad_inventory set quantity = 0 where item_name = 'زيت';
insert into public.agent_actions (id, user_id, tool_name, target_table, target_id, previous_state, new_state) values
  ('00000000-0000-0000-0000-00000000ac02', '00000000-0000-0000-0000-00000000f002', 'update_inventory_qty',
   'zad_inventory', (select id from zad_inventory where item_name = 'زيت'), '{"quantity": 2}', '{"quantity": 0}');

-- dad deleted mom's «عيش» line.
insert into public.agent_actions (id, user_id, tool_name, target_table, target_id, previous_state, new_state) values
  ('00000000-0000-0000-0000-00000000ac03', '00000000-0000-0000-0000-00000000f002', 'delete_shopping_item',
   'zad_shopping_list', (select id from zad_shopping_list where item_name = 'عيش'),
   (select to_jsonb(s) from zad_shopping_list s where item_name = 'عيش'), null);
delete from public.zad_shopping_list where item_name = 'عيش';

-- A forged entry: the neighbour's log claims the family's line.
insert into public.agent_actions (id, user_id, tool_name, target_table, target_id, previous_state, new_state) values
  ('00000000-0000-0000-0000-00000000ac04', '00000000-0000-0000-0000-00000000f003', 'complete_shopping_item',
   'zad_shopping_list', '00000000-0000-0000-0000-0000000005a1', '{"is_purchased": false}', '{"is_purchased": true}');

-- A transaction stays the owner's alone.
insert into public.zad_transactions (id, user_id, amount) values ('00000000-0000-0000-0000-0000000007a1', '00000000-0000-0000-0000-00000000f001', 50);
insert into public.agent_actions (id, user_id, tool_name, target_table, target_id, previous_state, new_state) values
  ('00000000-0000-0000-0000-00000000ac05', '00000000-0000-0000-0000-00000000f002', 'update_transaction',
   'zad_transactions', '00000000-0000-0000-0000-0000000007a1', '{"amount": 40}', '{"amount": 50}');

begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000f002","role":"authenticated"}', true);
set local role authenticated;
do $$
declare r jsonb;
begin
  -- 1. dad takes back ticking mom's line
  r := zad_agent_undo('00000000-0000-0000-0000-00000000ac01');
  assert (r->>'ok')::bool, 'undo of a ticked household line: ' || r::text;
  -- 2. and changing the household's oil
  r := zad_agent_undo('00000000-0000-0000-0000-00000000ac02');
  assert (r->>'ok')::bool, 'undo of a household pantry change: ' || r::text;
  -- 3. and deleting mom's bread
  r := zad_agent_undo('00000000-0000-0000-0000-00000000ac03');
  assert (r->>'ok')::bool, 'undo of a deleted household line: ' || r::text;
  -- 6. a transaction of mom's is not dad's to restore
  r := zad_agent_undo('00000000-0000-0000-0000-00000000ac05');
  assert not (r->>'ok')::bool and r->>'error' = 'target_row_missing', 'transaction undo: ' || r::text;
end $$;
reset role;
do $$ begin
  assert not (select is_purchased from zad_shopping_list where id = '00000000-0000-0000-0000-0000000005a1'), 'جبنة still ticked';
  assert (select quantity from zad_inventory where item_name = 'زيت') = 2, 'oil not restored';
  assert (select user_id from zad_shopping_list where item_name = 'عيش') = '00000000-0000-0000-0000-00000000f001',
    'bread not back as mom''s';
  assert (select amount from zad_transactions where id = '00000000-0000-0000-0000-0000000007a1') = 50, 'mom''s transaction changed';
end $$;
rollback;

-- 5. the neighbour cannot undo into the family's list
begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000f003","role":"authenticated"}', true);
set local role authenticated;
do $$
declare r jsonb;
begin
  r := zad_agent_undo('00000000-0000-0000-0000-00000000ac04');
  assert not (r->>'ok')::bool and r->>'error' = 'target_row_missing', 'neighbour undo: ' || r::text;
end $$;
reset role;
do $$ begin
  assert (select is_purchased from zad_shopping_list where id = '00000000-0000-0000-0000-0000000005a1'), 'the neighbour unticked the family''s line';
end $$;
rollback;

\echo undo_household_test: all checks passed
