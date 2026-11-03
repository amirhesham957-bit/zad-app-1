-- The weekly search per city (migration 20261103234100, ZAD_PLAN 4.3), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/deals_scaffold.sql
--   psql < supabase/sql/tests/store_deals_search_scaffold.sql
--   psql < supabase/sql/tests/deals_search_city_scaffold.sql
--   psql < supabase/migrations/20261025234500_deals.sql
--   psql < supabase/migrations/20261026013500_store_deals_search.sql
--   psql < supabase/migrations/20261026171500_deal_seed_stores.sql
--   psql < supabase/migrations/20261102201700_deals_youtube.sql
--   psql < supabase/migrations/20261103150000_deals_instagram.sql
--   psql < supabase/migrations/20261103234100_deals_search_city.sql
--   psql < supabase/sql/tests/deals_search_city_test.sql
--
-- Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
-- Saudi homes: r1 and r2 in Riyadh, j1 in Jeddah, n1 with no city, k1 whose stored city is from another country.
insert into auth.users values
  ('00000000-0000-0000-0000-0000000000b1'), ('00000000-0000-0000-0000-0000000000b2'),
  ('00000000-0000-0000-0000-0000000000c1'), ('00000000-0000-0000-0000-0000000000d1'),
  ('00000000-0000-0000-0000-0000000000f1') on conflict do nothing;
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000b1', 'SAR', 'SA'), ('00000000-0000-0000-0000-0000000000b2', 'SAR', 'SA'),
  ('00000000-0000-0000-0000-0000000000c1', 'SAR', 'SA'), ('00000000-0000-0000-0000-0000000000d1', 'SAR', 'SA'),
  ('00000000-0000-0000-0000-0000000000f1', 'SAR', 'SA');
insert into public.zad_user_city (user_id, country, city) values
  ('00000000-0000-0000-0000-0000000000b1', 'SA', 'الرياض'), ('00000000-0000-0000-0000-0000000000b2', 'SA', 'الرياض'),
  ('00000000-0000-0000-0000-0000000000c1', 'SA', 'جدة'), ('00000000-0000-0000-0000-0000000000f1', 'EG', 'القاهرة');

-- «بنده» on a receipt in Riyadh, in Jeddah and from the home with no city.
insert into public.price_index (item_name, price, currency, user_id, source, store_name) values
  ('زيت', 20, 'SAR', '00000000-0000-0000-0000-0000000000b1', 'crowdsource', 'بنده'),
  ('رز', 30, 'SAR', '00000000-0000-0000-0000-0000000000c1', 'crowdsource', 'بنده'),
  ('سكر', 9, 'SAR', '00000000-0000-0000-0000-0000000000d1', 'crowdsource', 'بنده'),
  ('شاي', 12, 'SAR', '00000000-0000-0000-0000-0000000000f1', 'crowdsource', 'مخبز الأمل');
-- «مخبز النخيل» paid from the bank by one home in Riyadh and one in Jeddah: two homes in the country.
insert into public.zad_transactions (user_id, currency, merchant_name, is_expense, txn_kind, transfer_to) values
  ('00000000-0000-0000-0000-0000000000b1', 'SAR', 'مخبز النخيل', true, 'expense', null),
  ('00000000-0000-0000-0000-0000000000c1', 'SAR', 'مخبز النخيل', true, 'expense', null);
\set QUIET 0

create temporary table t as select * from public.zad_deal_search_targets(50);

select pg_temp.check((select count(*) from t where store = 'بنده' and country = 'SA' and city = 'الرياض') = 1
  and (select count(*) from t where store = 'بنده' and country = 'SA' and city = 'جدة') = 1,
  'a store is searched once in each city its customers live in');
select pg_temp.check((select count(*) from t where store = 'بنده' and country = 'SA' and city = '') = 1,
  'a customer with no known city is still served by the country-wide search');
select pg_temp.check(exists (select 1 from t where store = 'مخبز الأمل' and city = ''),
  'a city stored for another country counts as no city');
select pg_temp.check((select count(*) from t where store = 'مخبز النخيل') = 2,
  'two homes paying a merchant still counts across the country, then it is searched in each of their cities');
select pg_temp.check(exists (select 1 from t where store = 'كيو' and city = 'الرياض' and homes = 2),
  'the seed stores are searched in a city with two homes');
select pg_temp.check(not exists (select 1 from t where store = 'كيو' and city = 'جدة'),
  'a city with one home is served by the country-wide search for the seed stores');
select pg_temp.check(exists (select 1 from t where store = 'كيو' and city = ''),
  'the seed stores are still searched country-wide');
select pg_temp.check(not exists (select 1 from public.zad_deal_source_targets(50, 'youtube') where city <> ''),
  'YouTube stays country-wide');

-- Searched in Riyadh this week: Riyadh waits, Jeddah and the country still get their turn.
insert into public.zad_deal_search_log (country, city, store_key, hits, put)
values ('SA', 'الرياض', public.zad_inventory_name_key('بنده'), 3, 1);
select pg_temp.check(not exists (select 1 from public.zad_deal_search_targets(50) where store = 'بنده' and city = 'الرياض'),
  'a store searched in a city this week is not searched there again');
select pg_temp.check((select count(*) from public.zad_deal_search_targets(50) where store = 'بنده') = 2,
  'searching one city does not use up another city''s turn');
-- A fresh search row for Jeddah makes Jeddah wait too.
select public.zad_deal_put(jsonb_build_object(
  'country', 'SA', 'city', 'جدة', 'store', 'بنده', 'item_name', 'زيت', 'price', 20, 'currency', 'SAR',
  'source_kind', 'search', 'source_url', 'https://example.sa/panda-jeddah', 'confidence', 0.5));
select pg_temp.check(not exists (select 1 from public.zad_deal_search_targets(50) where store = 'بنده' and city = 'جدة'),
  'a store with fresh search rows in a city is not searched there again');
select pg_temp.check(exists (select 1 from public.zad_deal_search_targets(50) where store = 'بنده' and city = ''),
  'the country-wide search still has its turn');

-- Who needs a city: a fresh point and no city, or a city older than 30 days or from another country.
update public.zad_users set last_lat = 24.71362, last_lon = 46.67531, last_location_at = now() - interval '1 day';
update public.zad_user_city set found_at = now() - interval '40 days' where user_id = '00000000-0000-0000-0000-0000000000c1';
update public.zad_users set travel_country = 'AE' where id = '00000000-0000-0000-0000-0000000000b2';
create temporary table needing as select * from public.zad_users_needing_city(50);
select pg_temp.check((select array_agg(user_id::text order by user_id) from needing) = array[
    '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000f1'],
  'a city is looked for when unknown, older than 30 days or from another country — not on a trip, not when recent');
select pg_temp.check((select bool_and(lat = 24.71 and lon = 46.68 and country = 'SA') from needing),
  'only the coarse point leaves the database');
update public.zad_users set last_location_at = now() - interval '8 days' where id = '00000000-0000-0000-0000-0000000000d1';
select pg_temp.check(not exists (select 1 from public.zad_users_needing_city(50) where user_id = '00000000-0000-0000-0000-0000000000d1'),
  'an old point is not asked about');
select pg_temp.check((select count(*) from public.zad_users_needing_city(1)) = 1, 'the limit holds');

set role authenticated;
do $$ begin
  perform 1 from public.zad_user_city;
  raise exception 'FAIL: a customer read zad_user_city';
exception when insufficient_privilege then
  raise notice 'ok: only the server reads the cities';
end $$;
do $$ begin
  insert into public.zad_user_city (user_id, country, city) values ('00000000-0000-0000-0000-0000000000d1', 'SA', 'أي كلام');
  raise exception 'FAIL: a customer wrote a city';
exception when insufficient_privilege then
  raise notice 'ok: a customer cannot write a city into the search';
end $$;
do $$ begin
  perform public.zad_users_needing_city(10);
  raise exception 'FAIL: a customer called zad_users_needing_city';
exception when insufficient_privilege then
  raise notice 'ok: only the server reads who needs a city';
end $$;
reset role;
