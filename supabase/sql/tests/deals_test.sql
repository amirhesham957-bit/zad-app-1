-- zad_deals (migration 20261025234500, ZAD_PLAN 4.1/4.2), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/deals_scaffold.sql
--   psql < supabase/migrations/20261025234500_deals.sql
--   psql < supabase/sql/tests/deals_test.sql
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
create or replace function pg_temp.who(p uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, false); end $$;
grant execute on function pg_temp.who(uuid) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
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
\set QUIET 0

-- The door for the sources to come.
set role service_role;
select pg_temp.check((select (public.zad_deal_put(jsonb_build_object(
  'country', 'sa', 'city', 'الرياض', 'store', 'كيو', 'item_name', 'زيت  عافية ١.٥ لتر', 'price', 22, 'price_before', 29,
  'currency', 'sar', 'deal_kind', 'discount', 'valid_until', (now() + interval '3 days')::text,
  'source_kind', 'flyer', 'source_url', 'https://example.com/flyer', 'confidence', 0.9)) ->> 'ok')::boolean),
  'a flyer deal goes in through the door');
select pg_temp.check((select (public.zad_deal_put(jsonb_build_object(
  'country', 'SA', 'city', 'الرياض', 'store', 'كيو', 'item_name', 'زيت عافية ١.٥ لتر', 'price', 21,
  'currency', 'SAR', 'valid_until', (now() + interval '2 days')::text,
  'source_kind', 'flyer', 'source_url', 'https://example.com/flyer2', 'confidence', 0.9)) ->> 'ok')::boolean),
  'a second flyer for the same item is taken');
-- A function's writes are not visible to the statement that called it: every read below is its own statement.
select pg_temp.check((select count(*) from public.zad_deals) = 1 and (select price from public.zad_deals) = 21,
  'the same source, store and item updates its one row');
select pg_temp.check((select expires_at::date = (now() + interval '2 days')::date from public.zad_deals),
  'a deal with an end date expires on it');
select pg_temp.check((select public.zad_deal_put(jsonb_build_object(
  'country', 'SA', 'store', 'بنده', 'item_name', 'رز', 'price', 30, 'currency', 'SAR',
  'source_kind', 'search', 'confidence', 0.5)) ->> 'reason') = 'invalid_input',
  'a deal with no source link is refused');
select pg_temp.check((select public.zad_deal_put(jsonb_build_object(
  'country', 'SA', 'store', 'بنده', 'item_name', 'رز', 'price', 30, 'currency', 'SAR', 'valid_until', '2020-01-01',
  'source_kind', 'search', 'source_url', 'https://example.com', 'confidence', 0.5)) ->> 'reason') = 'already_over',
  'a deal already over is refused');
select pg_temp.check((select public.zad_deal_put(jsonb_build_object(
  'country', 'SA', 'store', 'بنده', 'item_name', 'رز', 'price', 30, 'currency', 'SAR',
  'source_kind', 'receipt', 'confidence', 1)) ->> 'reason') = 'receipts_go_through_the_floor',
  'receipts never go in through the door');
select pg_temp.check((select (public.zad_deal_put(jsonb_build_object(
  'country', 'SA', 'store', 'بنده', 'item_name', 'رز بسمتي', 'price', 30, 'currency', 'SAR',
  'source_kind', 'search', 'source_url', 'https://example.com/s', 'confidence', 0.6)) ->> 'ok')::boolean),
  'a search deal with no end date is taken');
select pg_temp.check((select expires_at::date = (now() + interval '7 days')::date from public.zad_deals where store = 'بنده'),
  'a deal with no end date lives seven days');

-- Receipts: oil at Panda Riyadh from s1, s2 and the s3/s4 family = 3 homes; rice from s1, s2 and the family
-- only (s3 + s4) = 3 homes with one outlier; milk from two homes = below the floor.
reset role;
insert into public.price_index (item_name, price, currency, user_id, location, store_name, source, "timestamp") values
  ('زيت عافية', 20, 'SAR', '00000000-0000-0000-0000-0000000000a1', 'الرياض', 'بنده', 'crowdsource', now() - interval '1 day'),
  ('زيت عافيه', 22, 'SAR', '00000000-0000-0000-0000-0000000000a2', 'الرياض', 'بنده', 'crowdsource', now() - interval '2 days'),
  ('زيت عافية', 21, 'SAR', '00000000-0000-0000-0000-0000000000a3', 'الرياض', 'بنده', 'crowdsource', now() - interval '3 days'),
  ('حليب', 6, 'SAR', '00000000-0000-0000-0000-0000000000a1', 'الرياض', 'بنده', 'crowdsource', now()),
  ('حليب', 6, 'SAR', '00000000-0000-0000-0000-0000000000a3', 'الرياض', 'بنده', 'crowdsource', now()),
  ('حليب', 6, 'SAR', '00000000-0000-0000-0000-0000000000a4', 'الرياض', 'بنده', 'crowdsource', now()),
  ('سكر', 5, 'SAR', '00000000-0000-0000-0000-0000000000a1', 'الرياض', 'بنده', 'crowdsource', now() - interval '10 days'),
  ('سكر', 5, 'SAR', '00000000-0000-0000-0000-0000000000a2', 'الرياض', 'بنده', 'crowdsource', now() - interval '10 days'),
  ('سكر', 5, 'SAR', '00000000-0000-0000-0000-0000000000a3', 'الرياض', 'بنده', 'crowdsource', now() - interval '10 days'),
  ('رز', 30, 'SAR', '00000000-0000-0000-0000-0000000000a1', 'الرياض', 'كارفور', 'crowdsource', now()),
  ('رز', 32, 'SAR', '00000000-0000-0000-0000-0000000000a2', 'الرياض', 'كارفور', 'crowdsource', now()),
  ('رز', 31, 'SAR', '00000000-0000-0000-0000-0000000000a3', 'الرياض', 'كارفور', 'crowdsource', now()),
  ('رز', 300, 'SAR', '00000000-0000-0000-0000-0000000000a4', 'الرياض', 'كارفور', 'crowdsource', now()),
  ('زيت', 80, 'EGP', '00000000-0000-0000-0000-0000000000e1', 'القاهرة', 'خير زمان', 'crowdsource', now());

set role service_role;
select pg_temp.check(public.zad_deals_from_receipts() = 2, 'two items pass the 3-home floor');
select pg_temp.check((select price = 21 and homes = 3 from public.zad_deals where source_kind = 'receipt' and item_key = 'زيت عافيه'),
  'oil is the median of three homes, spelled two ways, one row');
select pg_temp.check((select price = 31 and homes = 3 from public.zad_deals where source_kind = 'receipt' and item_key = 'رز'),
  'the 300 outlier is dropped before the median');
select pg_temp.check(not exists (select 1 from public.zad_deals where item_key in ('حليب', 'سكر')),
  'one family is one home, and older than a week is not published');
select pg_temp.check(not exists (select 1 from public.zad_deals where country = 'EG'), 'one Egyptian home publishes nothing');

-- The floor drops: a home's reports age out, its row leaves on the next run.
reset role;
update public.price_index set "timestamp" = now() - interval '8 days' where item_name = 'رز' and price = 32;
set role service_role;
select pg_temp.check(public.zad_deals_from_receipts() = 1, 'one item still passes the floor');
select pg_temp.check(not exists (select 1 from public.zad_deals where item_key = 'رز'),
  'an item that falls below the floor leaves the table');

-- Customers read their own country only, and nothing expired; they write nothing.
reset role;
update public.zad_deals set expires_at = now() - interval '1 minute' where store = 'كيو';
set role authenticated;
select pg_temp.who('00000000-0000-0000-0000-0000000000a3');
select pg_temp.check((select count(*) from public.zad_deals) = 2, 'a Saudi customer sees Saudi deals, not the expired one');
select pg_temp.who('00000000-0000-0000-0000-0000000000e1');
select pg_temp.check((select count(*) from public.zad_deals) = 0, 'an Egyptian customer sees no Saudi deal');
do $$ begin
  insert into public.zad_deals (country, store, item_name, price, currency, source_kind, source_url, confidence, expires_at)
  values ('EG', 'x', 'xx', 1, 'EGP', 'search', 'https://x', 1, now() + interval '1 day');
  raise exception 'FAIL: a customer wrote a deal';
exception when insufficient_privilege then raise notice 'ok: a customer cannot write a deal';
end $$;
do $$ begin
  perform public.zad_deal_put('{}'::jsonb);
  raise exception 'FAIL: a customer called the door';
exception when insufficient_privilege then raise notice 'ok: a customer cannot call the door';
end $$;
reset role;
