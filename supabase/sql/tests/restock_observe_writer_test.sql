-- zad_restock_observe (20261123080000). Scratch only:
--   psql < supabase/sql/tests/scratch_scaffold.sql ; psql < ...restock_observations.sql ; psql < ...restock_observe_writer.sql ; psql < this
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$ declare r boolean; begin
  r := public.zad_restock_observe('eg', 'كارفور', 'لبن', true, 'flyer', 30.04456, 31.23789);
  assert r, 'first observation should be stored';
  assert (select area_lat from zad_restock_observations) = 30.04 and (select area_lng from zad_restock_observations) = 31.24, 'location not rounded';
  assert (select country from zad_restock_observations) = 'EG', 'country not upper-cased';
  assert not public.zad_restock_observe('EG', 'كارفور', 'لبن', true, 'flyer'), 'duplicate within an hour kept';
  assert public.zad_restock_observe('EG', 'كارفور', 'لبن', false, 'flyer'), 'opposite state should be stored';
  assert not public.zad_restock_observe('EG', 'كارفور', 'لبن', true, 'flyer', null, null, now() - interval '100 days'), 'old observation kept';
  begin perform public.zad_restock_observe('EG', 'كارفور', 'لبن', true, 'friend'); raise exception 'bad source kept';
  exception when raise_exception then assert sqlerrm = 'bad_source', sqlerrm; end;
  begin perform public.zad_restock_observe('egypt', 'كارفور', 'لبن', true, 'flyer'); raise exception 'bad country kept';
  exception when raise_exception then assert sqlerrm = 'bad_country', sqlerrm; end;
  assert not has_function_privilege('authenticated', 'public.zad_restock_observe(text,text,text,boolean,text,numeric,numeric,timestamptz)', 'execute'), 'customers can write';
  assert not has_function_privilege('anon', 'public.zad_restock_observe(text,text,text,boolean,text,numeric,numeric,timestamptz)', 'execute');
end $$;
rollback;
\echo restock_observe_writer_test: all checks passed
