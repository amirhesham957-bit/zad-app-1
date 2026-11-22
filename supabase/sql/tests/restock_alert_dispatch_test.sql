-- zad_restock_alert_candidates (20261123120000): who needs what, rounded location, server only. Scratch only:
--   psql < scratch_scaffold.sql; psql < restock_alert_dispatch_scaffold.sql; psql < the migration; psql < this file
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$ declare r record; n int;
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid(); d uuid := gen_random_uuid();
begin
  insert into auth.users (id) values (a), (b), (c), (d);
  insert into zad_users (id, country, last_lat, last_lon, last_location_at) values
    (a, 'eg', 30.04567, 31.23891, now()),
    (b, 'EG', 30.0, 31.0, now() - interval '30 days'),   -- stale location
    (c, 'EG', null, null, null),                          -- no location
    (d, 'EG', 30.0, 31.0, now());                         -- nothing needed
  insert into zad_inventory (user_id, item_name, quantity, low_stock_threshold) values
    (a, ' لبن ', 0, 2), (a, 'رز', 5, 2), (b, 'سكر', 0, 2), (c, 'زيت', 0, 2), (d, 'شاي', 9, 2);
  insert into zad_shopping_list (user_id, item_name, is_purchased) values (a, 'عدس', false), (a, 'فول', true);

  select * into r from zad_restock_alert_candidates() where user_id = a;
  assert r.country = 'EG', 'country upper-cased';
  assert r.lat = 30.05 and r.lng = 31.24, 'location rounded to 2 decimals, got ' || r.lat || ',' || r.lng;
  assert r.needed = array['عدس', 'لبن'], 'low stock + open list only, trimmed: ' || r.needed::text;
  assert r.sent_today = 0 and not r.muted and not r.broke;
  select count(*) into n from zad_restock_alert_candidates() where user_id in (b, c, d);
  assert n = 0, 'stale/no location and nothing-needed households are excluded, got ' || n;

  insert into zad_restock_alert_log (user_id, item_key) values (a, 'لبن');
  select * into r from zad_restock_alert_candidates() where user_id = a;
  assert r.needed = array['عدس'], 'item alerted in last 3 days is not repeated';
  assert r.sent_today = 1, 'daily counter';

  insert into zad_memory (user_id, subject_kind, suppress_until) values (a, 'restock_alert', now() + interval '1 day');
  insert into zad_broke_mode (user_id, ends_at) values (a, now() + interval '1 day');
  select * into r from zad_restock_alert_candidates() where user_id = a;
  assert r.muted and r.broke, 'snooze and broke mode surface';

  assert not exists (
    select 1 from pg_proc p, unnest(p.proargnames) x
     where p.proname = 'zad_restock_alert_candidates' and x in ('source_kind', 'source', 'member_id', 'family_id', 'buyer')
  ), 'output leaks a source or buyer';
  assert not has_function_privilege('authenticated', 'public.zad_restock_alert_candidates(integer)', 'execute'), 'customers can call';
  assert not has_function_privilege('anon', 'public.zad_restock_alert_candidates(integer)', 'execute');
  assert has_function_privilege('service_role', 'public.zad_restock_alert_candidates(integer)', 'execute');
  assert not has_table_privilege('authenticated', 'public.zad_restock_alert_log', 'select'), 'log readable by customers';
end $$;
rollback;
\echo restock_alert_dispatch_test: all checks passed
