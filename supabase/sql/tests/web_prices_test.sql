-- zad_web_prices (20261011270000): a sourced price only, server only. Scratch only:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/web_prices_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\i supabase/migrations/20261011270000_web_prices.sql

begin;
do $$ begin
  insert into zad_web_prices (country, name_key, name, price_low, price_high, currency, sources)
    values ('EG', 'لبن', 'لبن', 30, 34, 'EGP', '[{"title":"x","url":"https://x"}]');
  begin
    insert into zad_web_prices (country, name_key, name, price_low, price_high, sources)
      values ('EG', 'عيش', 'عيش', 5, 5, '[]');
    raise exception 'a price with no source was kept';
  exception when check_violation then null; end;
  begin
    insert into zad_web_prices (country, name_key, name, price_low, price_high, sources)
      values ('EG', 'رز', 'رز', 40, 30, '[{"title":"x","url":"https://x"}]');
    raise exception 'a range upside down was kept';
  exception when check_violation then null; end;
  assert not has_table_privilege('authenticated', 'public.zad_web_prices', 'select'), 'customers can read the cache';
  assert not has_table_privilege('anon', 'public.zad_web_prices', 'select');
end $$;
rollback;

\echo web_prices_test: all checks passed
