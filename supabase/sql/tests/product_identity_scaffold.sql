-- On top of household_shopping_scaffold.sql + 20261011140000: the observation and
-- consumption functions as the repo has them (20260725120000, 20260930000000), for
-- 20261011200000_product_identity.
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/household_shopping_scaffold.sql
--   psql < supabase/migrations/20261011140000_one_household_shopping_list.sql
--   psql < supabase/sql/tests/product_identity_scaffold.sql
--   psql < supabase/migrations/20261011200000_product_identity.sql
--   psql < supabase/sql/tests/product_identity_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create table if not exists public.zad_inventory_observations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_name text not null,
  qty numeric not null check (qty >= 0),
  observed_at timestamptz not null default now(),
  source text not null,
  created_at timestamptz not null default now());
create table if not exists public.zad_consumption (
  user_id uuid, item_name text, avg_daily_qty double precision, sample_count int,
  rate_known boolean, last_computed_at timestamptz);
create unique index if not exists zad_consumption_pk on public.zad_consumption (user_id, item_name);
alter table public.zad_inventory add column if not exists unit text;

create or replace function public.zad_inventory_name_key(p_name text)
 returns text language sql immutable parallel safe
as $function$
  select array_to_string(array(
    select case when w like 'ال%' and length(w) > 2 then substr(w, 3) else w end
      from unnest(regexp_split_to_array(lower(translate(trim(coalesce(p_name, '')), 'أإآةى', 'اااهي')), '\s+')) w
     where w <> ''
  ), ' ');
$function$;

create or replace function public.zad_recompute_consumption(p_user uuid, p_item text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_total_drop double precision;
  v_drops int;
  v_span_days double precision;
  v_distinct_days int;
  v_rate double precision;
  v_last_drop double precision;
  v_cycle_days double precision;
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'not_authorized';
  end if;

  with ordered as (
    select qty, observed_at,
           lag(qty) over (order by observed_at) as prev_qty
      from public.zad_inventory_observations
     where user_id = p_user and item_name = p_item
  ),
  drops as (
    select (prev_qty - qty) as amount, observed_at
      from ordered
     where prev_qty is not null and qty < prev_qty
  ),
  span as (
    select extract(epoch from (max(observed_at) - min(observed_at))) / 86400.0 as days
      from public.zad_inventory_observations
     where user_id = p_user and item_name = p_item
  )
  select coalesce(sum(d.amount), 0), count(*), count(distinct d.observed_at::date),
         (select days from span)
    into v_total_drop, v_drops, v_distinct_days, v_span_days
    from drops d;

  v_drops := coalesce(v_drops, 0);

  if v_drops = 0 or v_total_drop <= 0 then
    return jsonb_build_object('samples', v_drops, 'avg_daily_qty', null, 'rate_known', false);
  end if;

  if v_drops >= 2 and coalesce(v_span_days, 0) >= 1.0 then
    v_rate := v_total_drop / v_span_days;
  else
    -- دورة واحدة: آخر نزلة، من آخر ريستوك قبلها (أو أول قراية) لحد النزلة.
    with ordered as (
      select qty, observed_at,
             lag(qty) over (order by observed_at) as prev_qty
        from public.zad_inventory_observations
       where user_id = p_user and item_name = p_item
    ),
    last_drop as (
      select (prev_qty - qty) as amount, observed_at
        from ordered
       where prev_qty is not null and qty < prev_qty
       order by observed_at desc
       limit 1
    )
    select ld.amount,
           extract(epoch from (ld.observed_at - (
             select max(o.observed_at) from ordered o
              where o.observed_at < ld.observed_at
                and (o.prev_qty is null or o.qty > o.prev_qty)
           ))) / 86400.0
      into v_last_drop, v_cycle_days
      from last_drop ld;

    if v_cycle_days is null or v_cycle_days < 0.5 or coalesce(v_last_drop, 0) <= 0 then
      return jsonb_build_object('samples', v_drops, 'avg_daily_qty', null, 'rate_known', false);
    end if;
    v_rate := v_last_drop / v_cycle_days;
  end if;

  insert into public.zad_consumption
    (user_id, item_name, avg_daily_qty, sample_count, rate_known, last_computed_at)
  values
    (p_user, p_item, v_rate, v_drops, (v_drops >= 3 and v_distinct_days >= 2), now())
  on conflict (user_id, item_name) do update
    set avg_daily_qty    = excluded.avg_daily_qty,
        sample_count     = excluded.sample_count,
        rate_known       = excluded.rate_known,
        last_computed_at = excluded.last_computed_at;

  return jsonb_build_object(
    'samples', v_drops,
    'avg_daily_qty', v_rate,
    'rate_known', (v_drops >= 3 and v_distinct_days >= 2)
  );
end $function$;

create or replace function public.zad_record_observation(
  p_user uuid, p_item text, p_qty numeric, p_source text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'not_authorized';
  end if;

  insert into public.zad_inventory_observations (user_id, item_name, qty, source)
  values (p_user, p_item, p_qty, p_source);

  return public.zad_recompute_consumption(p_user, p_item);
end $$;
