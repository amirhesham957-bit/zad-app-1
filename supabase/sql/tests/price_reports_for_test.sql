-- zad_report_price_for (20261011180000): the server reports for an account, with the very
-- rules the app's zad_report_price has. Run after price_reports_test.sql's setup:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20260921160000_price_reports_through_the_server.sql
--   psql < supabase/migrations/20261011180000_price_reports_from_the_server.sql
--   psql < supabase/sql/tests/price_reports_test.sql        (the app's path, unchanged)
--   psql < supabase/sql/tests/price_reports_for_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- Who may call it.
do $$ begin
  assert not has_function_privilege('anon', 'public.zad_report_price_for(uuid, uuid, text, numeric, text, text, text, text)', 'execute');
  assert not has_function_privilege('authenticated', 'public.zad_report_price_for(uuid, uuid, text, numeric, text, text, text, text)', 'execute'),
    'a signed-in account could report as anyone';
  assert has_function_privilege('service_role', 'public.zad_report_price_for(uuid, uuid, text, numeric, text, text, text, text)', 'execute');
  assert not has_function_privilege('authenticated', 'private.zad_report_price_impl(uuid, uuid, text, numeric, text, text, text, text)', 'execute');
  assert has_function_privilege('authenticated', 'public.zad_report_price(uuid, text, numeric, text, text, text, text)', 'execute'),
    'the app lost zad_report_price';
end $$;

begin;
set local role service_role;
do $$
declare r jsonb; me uuid := '00000000-0000-0000-0000-0000000000e1';
begin
  -- 1. a Telegram receipt line lands as the account's, in the account's currency
  r := zad_report_price_for(me, 'bbbbbbbb-0000-0000-0000-00000000e001', 'لبن جهينة', 31.5, null, null, 'كارفور المعادي', 'ألبان');
  assert (r->>'ok')::bool and r->>'currency' = 'EGP', r::text;
  assert (select user_id from price_index where id = (r->>'id')::bigint) = me;
  assert (select source from price_index where id = (r->>'id')::bigint) = 'crowdsource';
  -- 2. the same photo sent again corrects, it does not add a second voice
  r := zad_report_price_for(me, 'bbbbbbbb-0000-0000-0000-00000000e002', 'لبن جهينة', 32, null, null, 'كارفور المعادي', null);
  assert (r->>'updated')::bool, r::text;
  -- 3. the same bounds
  assert zad_report_price_for(me, gen_random_uuid(), 'x', 5)->>'reason' = 'invalid_input';
  -- 4. no account, no report
  begin
    perform zad_report_price_for(null, gen_random_uuid(), 'لبن', 5);
    raise exception 'a report with no account was taken';
  exception when insufficient_privilege then null; end;
end $$;
rollback;

\echo price_reports_for_test: all checks passed
