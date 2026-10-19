-- ZAD_PLAN ٣.٨: الكميات بكسور (migration 20261020110000). Run after both purchase scaffolds and the
-- four purchase migrations (CI: job sql-tests).

\set ON_ERROR_STOP on

insert into auth.users values ('00000000-0000-0000-0000-0000000000f1');

select set_config('request.jwt.claims', '{"role":"service_role"}', false);
set role service_role;
do $$
declare r jsonb;
begin
  -- Half a kilo of rice is half a kilo, not one.
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-0000000000f1', jsonb_build_object(
    'id', '41111111-1111-1111-1111-111111111111', 'title', 'بقالة', 'source_type', 'telegram',
    'lines', jsonb_build_array(
      jsonb_build_object('name', 'رز', 'quantity', 0.5, 'unit', 'كجم', 'to', 'pantry'),
      jsonb_build_object('name', 'زيت', 'quantity', 1.5, 'unit', 'لتر', 'to', 'pantry'),
      jsonb_build_object('name', 'مية', 'quantity', 6, 'unit', 'إزازة', 'to', 'pantry'),
      jsonb_build_object('name', 'بنادول', 'quantity', 2.4, 'to', 'pharmacy'))));
  assert r ->> 'ok' = 'true', r::text;

  -- Another half kilo tops the same row up to one.
  r := public.zad_record_purchase_service('00000000-0000-0000-0000-0000000000f1', jsonb_build_object(
    'id', '41111111-1111-1111-1111-111111111112', 'title', 'بقالة', 'source_type', 'telegram',
    'lines', jsonb_build_array(jsonb_build_object('name', 'رز', 'quantity', 0.5, 'unit', 'كجم', 'to', 'pantry'))));
  assert (r -> 'pantry' ->> 'topped_up')::int = 1, r::text;
end $$;
reset role;

do $$ begin
  assert (select quantity from public.zad_inventory where item_name = 'رز') = 1.000,
    'rice: ' || (select quantity::text from public.zad_inventory where item_name = 'رز');
  assert (select quantity from public.zad_inventory where item_name = 'زيت') = 1.500, 'oil kept its half';
  assert (select quantity from public.zad_inventory where item_name = 'مية') = 6, 'whole counts stay whole';
  -- The learner saw the real amounts.
  assert exists (select 1 from public.zad_inventory_observations where item_name = 'رز' and qty = 0.5),
    'the first reading was half a kilo';
  -- Pills stay whole.
  assert (select quantity from public.zad_pharmacy_restocks limit 1) = 2, 'pharmacy counts pills';
end $$;

select 'quantity_fractions_test: ok';
