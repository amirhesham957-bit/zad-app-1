-- zad_deal_seed_stores + zad_deal_search_log (migration 20261026171500, ZAD_PLAN 4.16), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/deals_scaffold.sql
--   psql < supabase/sql/tests/store_deals_search_scaffold.sql
--   psql < supabase/migrations/20261025234500_deals.sql
--   psql < supabase/migrations/20261026013500_store_deals_search.sql
--   psql < supabase/migrations/20261026171500_deal_seed_stores.sql
--   psql < supabase/sql/tests/deal_seed_stores_test.sql
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
-- One Egyptian home with a receipt from «كارفور» (also on the seed list) and «باريون» (not on it).
insert into auth.users values ('00000000-0000-0000-0000-0000000000e1') on conflict do nothing;
insert into public.zad_users (id, currency, country) values ('00000000-0000-0000-0000-0000000000e1', 'EGP', 'EG');
insert into public.price_index (item_name, price, currency, user_id, source, store_name) values
  ('رز', 40, 'EGP', '00000000-0000-0000-0000-0000000000e1', 'crowdsource', 'كارفور'),
  ('زيت', 80, 'EGP', '00000000-0000-0000-0000-0000000000e1', 'crowdsource', 'باريون');
\set QUIET 0

create temporary table t as select * from public.zad_deal_search_targets(50);

select pg_temp.check((select count(*) from t where country = 'SA')
    = (select count(*) from public.zad_deal_seed_stores where country = 'SA' and active)
  and (select count(*) from t where country = 'SA') >= 15,
  'with no Saudi customer at all, every Saudi store on the list is searched');
select pg_temp.check(exists (select 1 from t where country = 'SA' and store = 'كيتا'), 'كيتا is on the Saudi list');
select pg_temp.check(exists (select 1 from t where country = 'SA' and store = 'كيو' and currency = 'SAR'),
  'كيو is searched in Saudi Arabia, in riyals');
select pg_temp.check((select count(*) from t where country = 'EG' and store = 'كارفور') = 1,
  'a store on the list that customers also buy from is searched once');
select pg_temp.check((select array_agg(store order by ord) from (select store, row_number() over () as ord from t) x where ord <= 2)
  @> array['باريون', 'كارفور'],
  'the stores customers buy from come before the list');
select pg_temp.check(not exists (
    select 1 from public.zad_deal_seed_stores where kind not in ('grocery', 'delivery', 'marketplace')),
  'every listed store is a grocery, a delivery app or a marketplace');

-- Searched this week with no deal found: it waits for next week, and the next store gets its turn.
insert into public.zad_deal_search_log (country, store_key, hits, put)
values ('SA', public.zad_inventory_name_key('كيو'), 0, 0);
select pg_temp.check(not exists (select 1 from public.zad_deal_search_targets(50) where store = 'كيو'),
  'a store searched this week with nothing found is not searched again');
update public.zad_deal_search_log set searched_at = now() - interval '7 days';
select pg_temp.check(exists (select 1 from public.zad_deal_search_targets(50) where store = 'كيو'),
  'a week later it is searched again');

-- A store taken off the list stops being searched.
update public.zad_deal_seed_stores set active = false where country = 'SA' and store = 'لولو';
select pg_temp.check(not exists (select 1 from public.zad_deal_search_targets(50) where store = 'لولو'),
  'an inactive store is left out');

select pg_temp.check((select count(*) from public.zad_deal_search_targets(3)) = 3, 'the limit holds');
