-- أرضية الجمهور (20261011250000). Family fa001 = mom f001 + dad f002 (one home); f003 and f004 are
-- two more homes. See crowd_floor_scaffold.sql for the order.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- 1. two homes are not a market price; a third makes one; an outlier does not move it
begin;
insert into price_index (item_name, price, currency, user_id, source, store_name, "timestamp") values
  ('لبن', 30, 'EGP', '00000000-0000-0000-0000-00000000f001', 'crowdsource', 'كارفور', now() - interval '1 day'),
  ('لبن', 31, 'EGP', '00000000-0000-0000-0000-00000000f002', 'crowdsource', 'بنده', now() - interval '1 day'),
  ('لبن', 32, 'EGP', '00000000-0000-0000-0000-00000000f003', 'crowdsource', 'سعودي', now() - interval '1 day'),
  ('عيش', 5, 'EGP', '00000000-0000-0000-0000-00000000f001', 'crowdsource', 'كارفور', now() - interval '1 day'),
  ('عيش', 6, 'EGP', '00000000-0000-0000-0000-00000000f003', 'crowdsource', 'سعودي', now() - interval '1 day');
do $$ begin
  assert not exists (select 1 from zad_cheapest_prices('EGP')), 'two homes shown as a market price';
end $$;
insert into price_index (item_name, price, currency, user_id, source, store_name, "timestamp") values
  ('لبن', 29, 'EGP', '00000000-0000-0000-0000-00000000f004', 'crowdsource', 'هايبر وان', now() - interval '2 hours'),
  ('لبن', 300, 'EGP', '00000000-0000-0000-0000-00000000f003', 'crowdsource', 'جملة', now() - interval '1 hour');
do $$
declare r record;
begin
  select * into r from zad_cheapest_prices('EGP') where item_name = 'لبن';
  assert found, 'three homes not shown';
  assert r.min_price = 29 and r.cheapest_store = 'هايبر وان', r::text;
  assert r.reports = 4 and r.avg_price = 30.5, 'the outlier counted: ' || r::text;
  assert not exists (select 1 from zad_cheapest_prices('EGP') where item_name = 'عيش'), 'عيش from two homes shown';
end $$;
rollback;

-- 2. «هيخلص إمتى؟» quotes a cheapest price only from three homes
begin;
insert into price_index (item_name, price, currency, user_id, source, store_name, "timestamp") values
  ('لبن', 25, 'EGP', '00000000-0000-0000-0000-00000000f003', 'crowdsource', 'سعودي', now() - interval '1 day'),
  ('لبن', 27, 'EGP', '00000000-0000-0000-0000-00000000f002', 'crowdsource', 'بنده', now() - interval '1 day');
select _agent_predicted_shortage_for_user('00000000-0000-0000-0000-00000000f001');
do $$ begin
  assert (select task_description from agent_tasks where kind = 'predicted_shortage') not like '%أرخص سعر%',
    'a price quoted from two homes';
end $$;
delete from agent_tasks;
insert into price_index (item_name, price, currency, user_id, source, store_name, "timestamp") values
  ('لبن', 28, 'EGP', '00000000-0000-0000-0000-00000000f004', 'crowdsource', 'هايبر وان', now() - interval '1 day');
select _agent_predicted_shortage_for_user('00000000-0000-0000-0000-00000000f001');
do $$ begin
  assert (select task_description from agent_tasks where kind = 'predicted_shortage') like '%أرخص سعر متسجّل 25.00 EGP في «سعودي»%',
    (select task_description from agent_tasks where kind = 'predicted_shortage');
end $$;
rollback;

\echo crowd_floor_test: all checks passed
