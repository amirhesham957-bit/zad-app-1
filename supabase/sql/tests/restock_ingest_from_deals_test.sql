-- zad_restock_ingest_deals (20261123100000). Scratch only; chain in edge-functions.yml LIST.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$ declare n int; begin
  insert into zad_deals (country, store_key, item_key, source_kind, lat, lng, expires_at) values
    ('EG', 'كارفور', 'لبن', 'flyer', 30.04456, 31.23789, now() + interval '3 days'),
    ('EG', 'كارفور', 'لبن', 'flyer', 30.04456, 31.23789, now() + interval '3 days'),
    ('EG', 'سبينس', 'زيت', 'youtube', null, null, now() + interval '3 days'),
    ('EG', 'هايبر', 'رز', 'partner', null, null, now() - interval '1 day'),
    ('EG', 'هايبر', 'سكر', 'receipt', null, null, now() + interval '3 days');
  insert into zad_deals (country, store_key, item_key, source_kind, found_at, expires_at) values ('EG', 'قديم', 'شاي', 'flyer', now() - interval '10 days', now() + interval '3 days');
  n := public.zad_restock_ingest_deals();
  assert n = 2, 'expected the flyer (deduped) and the receipt, got ' || n;
  assert (select count(*) from zad_restock_observations where in_stock) = 2;
  assert (select area_lat from zad_restock_observations where store_key = 'كارفور') = 30.04, 'location not rounded';
  assert not exists (select 1 from zad_restock_observations where source_kind not in ('flyer', 'partner', 'receipt'));
  assert public.zad_restock_ingest_deals() = 0, 'a second run should add nothing';
  assert not has_function_privilege('authenticated', 'public.zad_restock_ingest_deals(integer)', 'execute');
end $$;
rollback;
\echo restock_ingest_from_deals_test: all checks passed
