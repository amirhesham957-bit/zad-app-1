-- zad_deal_search_targets (migration 20261026013500, ZAD_PLAN 4.3), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/deals_scaffold.sql
--   psql < supabase/sql/tests/store_deals_search_scaffold.sql
--   psql < supabase/migrations/20261025234500_deals.sql
--   psql < supabase/migrations/20261026013500_store_deals_search.sql
--   psql < supabase/sql/tests/store_deals_search_test.sql
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
-- Saudi homes s1..s4 (s3 and s4 one family), an Egyptian e1.
insert into auth.users values
  ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2'),
  ('00000000-0000-0000-0000-0000000000a3'), ('00000000-0000-0000-0000-0000000000a4'),
  ('00000000-0000-0000-0000-0000000000e1') on conflict do nothing;
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000a1', 'SAR', 'SA'), ('00000000-0000-0000-0000-0000000000a2', 'SAR', 'SA'),
  ('00000000-0000-0000-0000-0000000000a3', 'SAR', 'sa'), ('00000000-0000-0000-0000-0000000000a4', 'SAR', 'SA'),
  ('00000000-0000-0000-0000-0000000000e1', 'EGP', 'EG');
insert into public.family_groups (id) values ('00000000-0000-0000-0000-00000000f001');
insert into public.family_members (family_id, user_id) values
  ('00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-0000000000a3'),
  ('00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-0000000000a4');

-- A receipt from one Egyptian home: a printed receipt names a shop, one home is enough.
insert into public.price_index (item_name, price, currency, user_id, source, store_name) values
  ('رز', 40, 'EGP', '00000000-0000-0000-0000-0000000000e1', 'crowdsource', 'كارفور'),
  ('سكر', 30, 'EGP', '00000000-0000-0000-0000-0000000000e1', 'crowdsource', 'كارفور'),
  ('زيت', 80, 'EGP', '00000000-0000-0000-0000-0000000000e1', 'crowdsource', 'خير زمان');
-- An old receipt, out of the 60 days.
insert into public.price_index (item_name, price, currency, user_id, source, store_name, "timestamp") values
  ('رز', 40, 'EGP', '00000000-0000-0000-0000-0000000000e1', 'crowdsource', 'سعودي ماركت', now() - interval '90 days');

-- Bank: «بنده» paid by two homes, «أحمد محمد» by one home only, «العثيمين» by one family (s3 + s4 = one home),
-- a transfer named after a store, and an income.
insert into public.zad_transactions (user_id, currency, merchant_name, is_expense, txn_kind, transfer_to) values
  ('00000000-0000-0000-0000-0000000000a1', 'SAR', 'بنده', true, 'expense', null),
  ('00000000-0000-0000-0000-0000000000a2', 'SAR', 'بنده ', true, 'expense', null),
  ('00000000-0000-0000-0000-0000000000a1', 'SAR', 'أحمد محمد', true, 'expense', null),
  ('00000000-0000-0000-0000-0000000000a1', 'SAR', 'أحمد محمد', true, 'expense', null),
  ('00000000-0000-0000-0000-0000000000a3', 'SAR', 'العثيمين', true, 'expense', null),
  ('00000000-0000-0000-0000-0000000000a4', 'SAR', 'العثيمين', true, 'expense', null),
  ('00000000-0000-0000-0000-0000000000a1', 'SAR', 'نون', true, 'expense', 'wallet'),
  ('00000000-0000-0000-0000-0000000000a2', 'SAR', 'نون', true, 'expense', 'wallet'),
  ('00000000-0000-0000-0000-0000000000a1', 'SAR', 'شركة الراتب', false, 'income', null),
  ('00000000-0000-0000-0000-0000000000a2', 'SAR', 'شركة الراتب', false, 'income', null);
\set QUIET 0

create temporary table t as select * from public.zad_deal_search_targets(10);

select pg_temp.check((select count(*) from t where store = 'كارفور' and country = 'EG' and currency = 'EGP') = 1,
  'a store from one home''s receipt is searched, in its country and currency');
select pg_temp.check((select homes from t where store = 'بنده') = 2 and (select country from t where store = 'بنده') = 'SA',
  'a merchant two homes paid is searched once for the country');
select pg_temp.check(not exists (select 1 from t where store = 'أحمد محمد'),
  'a name only one home paid never goes to a search engine');
select pg_temp.check(not exists (select 1 from t where store = 'العثيمين'),
  'two members of one family are one home');
-- «نون» is on the seed list from 20261026171500 (homes 0): a transfer still never makes a home its customer.
select pg_temp.check(not exists (select 1 from t where store = 'نون' and homes > 0), 'transfers are left out');
select pg_temp.check(not exists (select 1 from t where store = 'شركة الراتب'), 'income is left out');
select pg_temp.check(not exists (select 1 from t where store = 'سعودي ماركت'), 'a receipt older than 60 days is left out');
select pg_temp.check((select store from t limit 1) = 'بنده', 'the store most homes share comes first');
select pg_temp.check((select count(*) from public.zad_deal_search_targets(1)) = 1, 'the limit holds');

-- A store searched this week waits for next week.
select public.zad_deal_put(jsonb_build_object(
  'country', 'SA', 'store', 'بنده', 'item_name', 'زيت', 'price', 20, 'currency', 'SAR',
  'source_kind', 'search', 'source_url', 'https://example.sa/panda', 'confidence', 0.5));
select pg_temp.check(not exists (select 1 from public.zad_deal_search_targets(10) where store = 'بنده'),
  'a store with fresh search rows is not searched again');
update public.zad_deals set found_at = now() - interval '7 days' where store = 'بنده';
select pg_temp.check(exists (select 1 from public.zad_deal_search_targets(10) where store = 'بنده'),
  'after six days it is searched again');

set role authenticated;
do $$ begin
  perform public.zad_deal_search_targets(10);
  raise exception 'FAIL: a customer called zad_deal_search_targets';
exception when insufficient_privilege then
  raise notice 'ok: only the server reads the targets';
end $$;
reset role;
