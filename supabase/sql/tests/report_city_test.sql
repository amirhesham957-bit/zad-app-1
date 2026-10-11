-- 20261011260000: a report with no city takes the account's own from «ملفي». Order:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20260921160000_price_reports_through_the_server.sql
--   psql < supabase/migrations/20261011180000_price_reports_from_the_server.sql
--   psql < supabase/sql/tests/report_city_test.sql   (adds the profile table, applies 20261011260000)

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create table if not exists public.zad_customer_profile (user_id uuid primary key, city text);
insert into auth.users values ('00000000-0000-0000-0000-0000000000e1'), ('00000000-0000-0000-0000-0000000000e2') on conflict do nothing;
insert into public.zad_users (id, currency) values ('00000000-0000-0000-0000-0000000000e1', 'EGP'), ('00000000-0000-0000-0000-0000000000e2', 'EGP')
  on conflict (id) do update set currency = excluded.currency;
insert into public.zad_customer_profile values ('00000000-0000-0000-0000-0000000000e1', '  الإسكندرية ') on conflict do nothing;

\i supabase/migrations/20261011260000_report_city_from_profile.sql

begin;
set local role service_role;
do $$
declare r jsonb;
begin
  -- a receipt line with no city: the profile's
  r := zad_report_price_for('00000000-0000-0000-0000-0000000000e1', gen_random_uuid(), 'لبن', 30, null, null, 'كارفور');
  assert (select location from price_index where id = (r->>'id')::bigint) = 'الإسكندرية', r::text;
  -- a city given is kept
  r := zad_report_price_for('00000000-0000-0000-0000-0000000000e1', gen_random_uuid(), 'عيش', 5, null, 'القاهرة', 'خير زمان');
  assert (select location from price_index where id = (r->>'id')::bigint) = 'القاهرة';
  -- no profile city: none, as before
  r := zad_report_price_for('00000000-0000-0000-0000-0000000000e2', gen_random_uuid(), 'لبن', 31, null, null, 'بنده');
  assert (select location from price_index where id = (r->>'id')::bigint) is null;
  -- the same item at the same shop again is a correction, the city and all
  r := zad_report_price_for('00000000-0000-0000-0000-0000000000e1', gen_random_uuid(), 'لبن', 29, null, null, 'كارفور');
  assert (r->>'updated')::bool, r::text;
end $$;
rollback;

\echo report_city_test: all checks passed
