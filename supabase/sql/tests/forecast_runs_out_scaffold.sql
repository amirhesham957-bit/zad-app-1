-- What 20261026233000_forecast_runs_out.sql reads beyond forecasts_scaffold.sql, as live 2026-10-26.
create table public.zad_home_state (
  user_id uuid primary key, state jsonb not null default '{}'::jsonb, computed_at timestamptz
);
create table public.zad_inventory_observations (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text not null,
  qty numeric not null, observed_at timestamptz not null default now(), source text not null
);
create or replace function public.zad_inventory_name_key(p_name text)
 returns text language sql immutable parallel safe
as $function$
  select array_to_string(array(
    select case when w like 'ال%' and length(w) > 2 then substr(w, 3) else w end
      from unnest(regexp_split_to_array(lower(translate(trim(coalesce(p_name, '')), 'أإآةى', 'اااهي')), '\s+')) w
     where w <> ''
  ), ' ');
$function$;
