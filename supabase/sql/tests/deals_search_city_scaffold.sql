-- What 20261103234100_deals_search_city.sql reads beyond store_deals_search_scaffold.sql, as live 2026-11-03:
-- the account's coarse point and its trip.
alter table public.zad_users add column if not exists last_lat double precision;
alter table public.zad_users add column if not exists last_lon double precision;
alter table public.zad_users add column if not exists last_location_at timestamptz;
alter table public.zad_users add column if not exists travel_country text;
