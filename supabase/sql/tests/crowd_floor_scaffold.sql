-- On top of household_list_brain_scaffold.sql + 20261011150000: zad_cheapest_prices as the
-- repo has it (20260921160000), for 20261011250000_crowd_floor.
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/household_shopping_scaffold.sql
--   psql < supabase/migrations/20261011140000_one_household_shopping_list.sql
--   psql < supabase/sql/tests/household_list_brain_scaffold.sql
--   psql < supabase/migrations/20261011150000_brain_sees_the_household_list.sql
--   psql < supabase/sql/tests/crowd_floor_scaffold.sql
--   psql < supabase/migrations/20261011250000_crowd_floor.sql
--   psql < supabase/sql/tests/crowd_floor_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

alter table public.price_index add column if not exists client_report_id uuid;
alter table public.price_index add column if not exists item_category text;

create or replace function public.zad_cheapest_prices(
  p_currency text,
  p_location text default null,
  p_days int default 14,
  p_limit int default 20
)
returns table (
  item_name text,
  min_price double precision,
  avg_price double precision,
  reports int,
  cheapest_location text,
  cheapest_store text,
  last_reported timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with recent as (
    select lower(btrim(regexp_replace(p.item_name, '\s+', ' ', 'g'))) as item_key,
           btrim(p.item_name) as item_name, p.price, p.location, p.store_name, p."timestamp" as reported_at
    from public.price_index p
    where p.source = 'crowdsource'
      and p.currency = p_currency
      and p.price > 0
      and p."timestamp" > now() - make_interval(days => greatest(1, least(coalesce(p_days, 14), 60)))
      and (p_location is null or btrim(p_location) = '' or p.location ilike '%' || btrim(p_location) || '%')
  ),
  stats as (
    select item_key, min(price) as min_price, avg(price) as avg_price, count(*)::int as reports, max(reported_at) as last_reported
    from recent group by item_key
  ),
  cheapest as (
    select distinct on (item_key) item_key, item_name, location, store_name
    from recent order by item_key, price asc, reported_at desc
  )
  select c.item_name, s.min_price, round(s.avg_price::numeric, 2)::double precision, s.reports,
         c.location, c.store_name, s.last_reported
  from stats s join cheapest c using (item_key)
  order by s.reports desc, s.last_reported desc
  limit greatest(1, least(coalesce(p_limit, 20), 50));
$function$;
