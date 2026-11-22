-- zad_trend_surge_record (20261123110000): aggregate-only writer, k>=5, server only. Scratch only:
--   psql < supabase/sql/tests/scratch_scaffold.sql ; psql < ...trend_surge_record.sql ; psql < this
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$ declare n int; begin
  n := public.zad_trend_surge_record('2026-11-22', '[{"item":" لبن ","houses":8,"count":20,"baseline":2,"z":12.7},{"item":"رز","houses":4,"count":50,"baseline":1,"z":40}]');
  assert n = 1, 'only the >=5 houses row is written, got ' || n;
  assert (select count(*) from zad_trend_surges) = 1, 'under-5 row stored';
  assert (select item_key from zad_trend_surges) = 'لبن', 'item not normalised';
  perform public.zad_trend_surge_record('2026-11-22', '[{"item":"لبن","houses":9,"count":25,"baseline":2,"z":16}]');
  assert (select count(*) from zad_trend_surges) = 1 and (select houses from zad_trend_surges) = 9, 'rerun must upsert';
  begin
    insert into zad_trend_surges values ('2026-11-22', 'x1', 4, 1, 1, 1); raise exception 'table accepted <5 houses';
  exception when check_violation then null; end;
  begin perform public.zad_trend_surge_record('2026-11-22', '{}'); raise exception 'bad rows kept';
  exception when raise_exception then assert sqlerrm = 'bad_rows', sqlerrm; end;
  assert not exists (select 1 from information_schema.columns where table_name = 'zad_trend_surges' and column_name in ('user_id', 'member_id', 'family_id')), 'identity column present';
  assert not has_function_privilege('authenticated', 'public.zad_trend_surge_record(date,jsonb)', 'execute'), 'customers can write';
  assert not has_function_privilege('anon', 'public.zad_trend_surge_record(date,jsonb)', 'execute');
  assert not has_table_privilege('authenticated', 'public.zad_trend_surges', 'select'), 'customers can read';
end $$;
rollback;
\echo trend_surge_record_test: all checks passed
