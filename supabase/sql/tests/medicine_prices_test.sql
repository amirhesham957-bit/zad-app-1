-- zad_medicine_prices (migration 20261011110000). Scratch database only:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/medicine_prices_test.sql
--
-- Rolls back.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

begin;
\i supabase/migrations/20261011110000_medicine_prices.sql
\i supabase/migrations/20261011110000_medicine_prices.sql

-- The function's upsert, twice for the same medicine in the same country.
insert into public.zad_medicine_prices (country, name_key, name, price_low, price_high, currency, sources)
values ('EG', 'بنادول اكسترا', 'بنادول إكسترا', 60, 75, 'EGP', '[{"title":"x","url":"https://example.com"}]')
on conflict (country, name_key) do update set price_low = excluded.price_low, price_high = excluded.price_high, found_at = now();
insert into public.zad_medicine_prices (country, name_key, name, price_low, price_high, currency, sources)
values ('EG', 'بنادول اكسترا', 'بنادول إكسترا', 65, 80, 'EGP', '[{"title":"y","url":"https://example.org"}]')
on conflict (country, name_key) do update set price_low = excluded.price_low, price_high = excluded.price_high, found_at = now();
-- The same name in another country is another price.
insert into public.zad_medicine_prices (country, name_key, name, price_low, price_high, currency, sources)
values ('SA', 'بنادول اكسترا', 'بنادول إكسترا', 12, 12, 'SAR', '[{"title":"z","url":"https://example.net"}]');

do $$
declare v_bad record;
begin
  if (select count(*) from public.zad_medicine_prices) <> 2 then raise exception 'expected one row per country'; end if;
  if (select price_low from public.zad_medicine_prices where country = 'EG') <> 65 then raise exception 'upsert did not update'; end if;
  if has_table_privilege('authenticated', 'public.zad_medicine_prices', 'select')
     or has_table_privilege('anon', 'public.zad_medicine_prices', 'select') then
    raise exception 'clients can read the prices table';
  end if;
  for v_bad in select * from (values
    ('eg', 0::numeric, 1::numeric, '[{"url":"https://a"}]'::jsonb),   -- lower-case country
    ('EG', 0, 1, '[{"url":"https://a"}]'),                              -- zero price
    ('EG', 5, 4, '[{"url":"https://a"}]'),                              -- high below low
    ('EG', 5, 6, '[]')                                                  -- a price without a source
  ) t(country, low, high, sources) loop
    begin
      insert into public.zad_medicine_prices (country, name_key, name, price_low, price_high, sources)
      values (v_bad.country, 'x' || v_bad.low || v_bad.high, 'x', v_bad.low, v_bad.high, v_bad.sources);
      raise exception 'accepted a bad row: %', row_to_json(v_bad);
    exception when check_violation then null;
    end;
  end loop;
  raise notice 'medicine_prices_test: all passed';
end $$;

rollback;
