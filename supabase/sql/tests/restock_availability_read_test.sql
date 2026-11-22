-- zad_restock_availability (20261123070000): read-only, no person, server only. Scratch only:
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261123030000_restock_observations.sql
--   psql < supabase/migrations/20261123070000_restock_availability_read.sql
--   psql < supabase/sql/tests/restock_availability_read_test.sql
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$ declare r record; n int; begin
  insert into zad_restock_observations (country, store_key, item_key, in_stock, source_kind, observed_at, area_lat, area_lng)
    values ('EG', 'كارفور', 'لبن', true, 'receipt', now() - interval '2 days', 30.04, 31.23),
           ('EG', 'كارفور', 'لبن', false, 'flyer', now() - interval '100 days', 30.04, 31.23),
           ('EG', 'هايبر', 'لبن', false, 'partner', now(), null, null),
           ('EG', 'كارفور', 'رز', true, 'receipt', now(), 30.04, 31.23),
           ('SA', 'كارفور', 'لبن', true, 'receipt', now(), 24.71, 46.67);
  select count(*) into n from zad_restock_availability('eg', 'لبن');
  assert n = 2, 'country+item filter and 90d cap: expected 2, got ' || n;
  select * into r from zad_restock_availability('EG', 'لبن') where store_key = 'كارفور';
  assert r.in_stock and r.age_days between 1.99 and 2.01, 'age in days';
  assert r.area_lat = 30.04, 'approximate area kept';
  select count(*) into n from zad_restock_availability('EG', 'لبن', 1);
  assert n = 1, 'max age is honoured, got ' || n;
  select count(*) into n from zad_restock_availability('EG', 'لبن', 100000);
  assert n = 2, 'max age is capped at 90 days';
  assert not exists (
    select 1 from pg_proc p, unnest(p.proargnames) a
     where p.proname = 'zad_restock_availability' and a in ('id', 'source_kind', 'user_id', 'family_id', 'member_id')
  ), 'output leaks a person or source';
  assert not has_function_privilege('authenticated', 'public.zad_restock_availability(text,text,integer)', 'execute'), 'customers can call';
  assert not has_function_privilege('anon', 'public.zad_restock_availability(text,text,integer)', 'execute');
end $$;
rollback;
\echo restock_availability_read_test: all checks passed
