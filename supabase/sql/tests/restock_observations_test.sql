-- zad_restock_observations (20261123030000): no person in the row, server only, pruned. Scratch only:
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/restock_observations_test.sql
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$ declare n int; begin
  insert into zad_restock_observations (country, store_key, item_key, in_stock, source_kind) values ('EG', 'كارفور', 'لبن', true, 'receipt');
  insert into zad_restock_observations (country, store_key, item_key, in_stock, source_kind, observed_at) values ('EG', 'كارفور', 'لبن', false, 'flyer', now() - interval '100 days');
  begin
    insert into zad_restock_observations (country, store_key, item_key, in_stock, source_kind) values ('EG', 'كارفور', 'لبن', true, 'friend');
    raise exception 'an unknown source was kept';
  exception when check_violation then null; end;
  begin
    insert into zad_restock_observations (country, store_key, item_key, in_stock, source_kind) values ('egypt', 'كارفور', 'لبن', true, 'receipt');
    raise exception 'a bad country was kept';
  exception when check_violation then null; end;
  assert not exists (select 1 from information_schema.columns where table_name = 'zad_restock_observations' and column_name in ('user_id', 'family_id', 'member_id')), 'a person column exists';
  assert not has_table_privilege('authenticated', 'public.zad_restock_observations', 'select'), 'customers can read';
  assert not has_table_privilege('anon', 'public.zad_restock_observations', 'insert');
  select public.zad_restock_obs_prune() into n;
  assert n = 1, 'prune should drop only the old row, got ' || n;
  assert (select count(*) from zad_restock_observations) = 1;
end $$;
rollback;
\echo restock_observations_test: all checks passed
