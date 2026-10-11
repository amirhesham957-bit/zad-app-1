-- «دول نفس الحاجة؟» answered (20261011210000). Family: mom f001, dad f002 (fa001); neighbour f003.
-- See product_merge_scaffold.sql for the order.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- The household as the audit found it: milk twice, under two names.
insert into zad_inventory (user_id, item_name, quantity, unit, category, expiry_date, created_at) values
  ('00000000-0000-0000-0000-00000000f001', 'حليب', 2, 'لتر', 'عام', (current_date - 3)::text, now() - interval '5 days'),
  ('00000000-0000-0000-0000-00000000f002', 'لبن', 1, 'لتر', 'الألبان', (current_date + 5)::text, now() - interval '1 day'),
  ('00000000-0000-0000-0000-00000000f003', 'حليب', 7, 'لتر', null, null, now());
insert into zad_shopping_list (user_id, item_name, quantity, is_purchased) values
  ('00000000-0000-0000-0000-00000000f001', 'حليب', 1, false),
  ('00000000-0000-0000-0000-00000000f002', 'لبن', 2, false),
  ('00000000-0000-0000-0000-00000000f001', 'حليب', 1, true);
insert into zad_inventory_observations (user_id, item_name, qty, source, observed_at) values
  ('00000000-0000-0000-0000-00000000f002', 'حليب', 4, 'manual', now() - interval '2 days'),
  ('00000000-0000-0000-0000-00000000f002', 'لبن', 2, 'manual', now());
insert into zad_consumption (user_id, item_name, avg_daily_qty, sample_count, rate_known)
  values ('00000000-0000-0000-0000-00000000f002', 'حليب', 0.5, 1, false);

-- 1. the brain records mom's «أيوه، سمّيها لبن»
begin;
set local role service_role;
do $$
declare r jsonb;
begin
  r := zad_product_merge_for('00000000-0000-0000-0000-00000000f001', 'لبن', 'حليب');
  assert (r->>'ok')::bool, r::text;
  assert (r->>'pantry_rows_merged')::int = 1 and (r->>'list_lines_merged')::int = 1, r::text;
end $$;
reset role;
do $$
declare fam text := '00000000-0000-0000-0000-0000000fa001';
begin
  -- pantry: one «لبن» for the home, both purchases added up, the specific category kept,
  -- and the stock that is not waste was not logged as waste
  assert (select count(*) from zad_inventory where family_id::text = fam and item_name in ('لبن', 'حليب')) = 1,
    'pantry rows: ' || (select string_agg(item_name || ' ' || quantity, ', ') from zad_inventory where family_id::text = fam);
  assert (select item_name = 'لبن' and quantity = 3 and category = 'الألبان'
            from zad_inventory where family_id::text = fam and item_name = 'لبن'), 'the kept row is wrong';
  assert (select expiry_date from zad_inventory where family_id::text = fam and item_name = 'لبن') = (current_date - 3)::text,
    'not the earliest expiry among rows with stock';
  assert not exists (select 1 from zad_waste_log), 'a moved item was logged as waste';
  -- the neighbour's milk is hers
  assert exists (select 1 from zad_inventory where user_id = '00000000-0000-0000-0000-00000000f003' and item_name = 'حليب' and quantity = 7);
  -- list: one open «لبن» with both quantities; the bought line renamed
  assert (select count(*) from zad_shopping_list where not is_purchased and family_id::text = fam
            and item_name in ('لبن', 'حليب')) = 1, 'two open lines left';
  assert (select quantity from zad_shopping_list where not is_purchased and family_id::text = fam and item_name = 'لبن') = 3;
  assert not exists (select 1 from zad_shopping_list where item_name = 'حليب' and family_id::text = fam), 'a حليب line left';
  -- observations and the rate: one history under «لبن», dad's rate recomputed from both readings
  assert (select count(*) from zad_inventory_observations where item_name = 'لبن') = 2;
  assert not exists (select 1 from zad_consumption where item_name = 'حليب'), 'the old rate stayed';
  assert (select avg_daily_qty from zad_consumption where user_id = '00000000-0000-0000-0000-00000000f002' and item_name = 'لبن') > 0,
    'no rate under لبن';
  -- the answer stands: dad's next «حليب» is «لبن»
  insert into zad_inventory (user_id, item_name, quantity, unit) values ('00000000-0000-0000-0000-00000000f002', 'حليب', 1, 'كرتونة');
  assert exists (select 1 from zad_inventory where user_id = '00000000-0000-0000-0000-00000000f002' and item_name = 'لبن' and unit = 'كرتونة');
end $$;
rollback;

-- 2. «لأ، حاجتين مختلفين» is remembered and changes nothing; nonsense is refused
begin;
set local role service_role;
do $$
declare r jsonb;
begin
  r := zad_product_not_same_for('00000000-0000-0000-0000-00000000f002', 'لبن', 'لبن رايب');
  assert (r->>'ok')::bool, r::text;
  assert zad_product_merge_for('00000000-0000-0000-0000-00000000f002', 'الحليب', 'حليب')->>'reason' = 'invalid_input',
    'a name merged with itself';
end $$;
reset role;
do $$ begin
  assert (select verdict from zad_product_pairs where family_id = '00000000-0000-0000-0000-0000000fa001') = 'different';
  assert exists (select 1 from zad_inventory where item_name = 'حليب' and user_id = '00000000-0000-0000-0000-00000000f001'),
    'a «different» answer renamed something';
end $$;
rollback;

-- 3. from the app: dad answers for himself; nobody answers as someone else
begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000f002","role":"authenticated"}', true);
set local role authenticated;
do $$
declare r jsonb;
begin
  r := zad_product_merge('لبن', 'حليب');
  assert (r->>'ok')::bool, r::text;
  begin
    perform zad_product_merge_for('00000000-0000-0000-0000-00000000f003', 'لبن', 'حليب');
    raise exception 'an account merged the neighbour''s pantry';
  exception when insufficient_privilege then null; end;
end $$;
rollback;

\echo product_merge_test: all checks passed
