-- One name per household (20261011200000). Family: mom f001, dad f002 (fa001); neighbour f003.
-- See product_identity_scaffold.sql for the order.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- 1. no answer yet in any home: every name is written as typed
begin;
insert into zad_inventory (user_id, item_name) values ('00000000-0000-0000-0000-00000000f002', ' حليب ');
do $$ begin
  assert exists (select 1 from zad_inventory where item_name = ' حليب '), 'a name changed with no answer given';
end $$;
rollback;

-- The family said «لبن» and «حليب» are the same, keep «لبن»; «مياه» and «ماء» likewise, and «ماء»
-- later became «مياه معدنية»'s; «لبن» and «لبن رايب» are not the same.
insert into zad_product_pairs (user_id, family_id, a_key, b_key, verdict, canonical_name)
select '00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-0000000fa001',
       least(zad_inventory_name_key('لبن'), zad_inventory_name_key('حليب')),
       greatest(zad_inventory_name_key('لبن'), zad_inventory_name_key('حليب')), 'same', 'لبن';
insert into zad_product_pairs (user_id, family_id, a_key, b_key, verdict, canonical_name, created_at)
select '00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-0000000fa001',
       least(zad_inventory_name_key('ماء'), zad_inventory_name_key('مياه')),
       greatest(zad_inventory_name_key('ماء'), zad_inventory_name_key('مياه')), 'same', 'مياه', now() - interval '1 day';
insert into zad_product_pairs (user_id, family_id, a_key, b_key, verdict, canonical_name)
select '00000000-0000-0000-0000-00000000f002', '00000000-0000-0000-0000-0000000fa001',
       least(zad_inventory_name_key('مياه'), zad_inventory_name_key('مياه معدنية')),
       greatest(zad_inventory_name_key('مياه'), zad_inventory_name_key('مياه معدنية')), 'same', 'مياه معدنية';
insert into zad_product_pairs (user_id, family_id, a_key, b_key, verdict)
select '00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-0000000fa001',
       least(zad_inventory_name_key('لبن'), zad_inventory_name_key('لبن رايب')),
       greatest(zad_inventory_name_key('لبن'), zad_inventory_name_key('لبن رايب')), 'different';

begin;
do $$
declare dad uuid := '00000000-0000-0000-0000-00000000f002';
begin
  -- 2. dad writes «الحليب» (article and all) — mom's answer holds for him: «لبن», in pantry and list
  insert into zad_inventory (user_id, item_name) values (dad, 'الحليب');
  insert into zad_shopping_list (user_id, item_name) values (dad, 'حليب');
  assert exists (select 1 from zad_inventory where user_id = dad and item_name = 'لبن'), 'pantry kept حليب';
  assert exists (select 1 from zad_shopping_list where user_id = dad and item_name = 'لبن'), 'list kept حليب';
  -- 3. a chain is followed: «ماء» → «مياه» → «مياه معدنية»
  insert into zad_inventory (user_id, item_name) values (dad, 'ماء');
  assert exists (select 1 from zad_inventory where user_id = dad and item_name = 'مياه معدنية'), 'chain not followed';
  -- 4. «different» renames nothing
  insert into zad_inventory (user_id, item_name) values (dad, 'لبن رايب');
  assert exists (select 1 from zad_inventory where user_id = dad and item_name = 'لبن رايب'), 'a different item was renamed';
  -- 5. a rename to another name goes through the answer too
  update zad_inventory set item_name = 'حليب' where user_id = dad and item_name = 'لبن رايب';
  assert not exists (select 1 from zad_inventory where user_id = dad and item_name = 'حليب'), 'an update kept حليب';
end $$;
rollback;

-- 6. the neighbour's «حليب» is hers
begin;
insert into zad_inventory (user_id, item_name) values ('00000000-0000-0000-0000-00000000f003', 'حليب');
do $$ begin
  assert exists (select 1 from zad_inventory where user_id = '00000000-0000-0000-0000-00000000f003' and item_name = 'حليب'),
    'another home''s answer renamed the neighbour''s milk';
end $$;
rollback;

-- 7. consumption is learnt under the one name: an observation of «حليب» joins «لبن»'s history
begin;
insert into zad_inventory_observations (user_id, item_name, qty, source, observed_at)
  values ('00000000-0000-0000-0000-00000000f002', 'لبن', 4, 'manual', now() - interval '2 days');
select zad_record_observation('00000000-0000-0000-0000-00000000f002', 'حليب', 2, 'manual');
do $$ begin
  assert (select count(*) from zad_inventory_observations where item_name = 'لبن') = 2, 'the observation kept حليب';
  assert exists (select 1 from zad_consumption where user_id = '00000000-0000-0000-0000-00000000f002'
                   and item_name = 'لبن' and avg_daily_qty > 0), 'no rate under لبن';
  assert not exists (select 1 from zad_consumption where item_name = 'حليب'), 'a rate under حليب';
end $$;
rollback;

-- 8. an account asks only about its own names
begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000f003","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  assert zad_product_canonical('00000000-0000-0000-0000-00000000f003', 'حليب') = 'حليب';
  begin
    perform zad_product_canonical('00000000-0000-0000-0000-00000000f002', 'حليب');
    raise exception 'the neighbour read the family''s answers';
  exception when insufficient_privilege then null; end;
  assert (select count(*) from zad_product_pairs) = 0, 'the neighbour sees the family''s answers';
end $$;
rollback;

\echo product_identity_test: all checks passed
