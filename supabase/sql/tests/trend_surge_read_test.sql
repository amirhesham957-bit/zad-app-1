-- zad_trend_surges_read (20261123130000): read-only, k>=5, server only. Scratch only:
--   psql < scratch_scaffold.sql ; psql < ...trend_surge_record.sql ; psql < ...trend_surge_read.sql ; psql < this
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$ declare r record; n int; begin
  perform public.zad_trend_surge_record('2026-11-22', '[{"item":"لبن","houses":8,"count":20,"baseline":2,"z":12.7},{"item":"رز","houses":6,"count":30,"baseline":2,"z":19}]');
  perform public.zad_trend_surge_record('2026-11-21', '[{"item":"عيش","houses":9,"count":30,"baseline":2,"z":19}]');
  select count(*) into n from public.zad_trend_surges_read('2026-11-22');
  assert n = 2, 'only that day, got ' || n;
  select * into r from public.zad_trend_surges_read('2026-11-22', 10) limit 1;
  assert r.item_key = 'رز', 'highest z first, got ' || r.item_key;
  select count(*) into n from public.zad_trend_surges_read('2026-11-22', 1);
  assert n = 1, 'limit ignored';
  assert (select count(*) from public.zad_trend_surges_read('2020-01-01')) = 0, 'empty day';
  assert not has_function_privilege('authenticated', 'public.zad_trend_surges_read(date,integer)', 'execute'), 'customers can read';
  assert not has_function_privilege('anon', 'public.zad_trend_surges_read(date,integer)', 'execute');
  assert has_function_privilege('service_role', 'public.zad_trend_surges_read(date,integer)', 'execute');
end $$;
rollback;
\echo trend_surge_read_test: all checks passed
