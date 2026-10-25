-- Tables zad_home_state_touch (20261025012500) is attached to, on top of scratch_scaffold.sql. Only the columns it reads.
alter table public.zad_users add column country text, add column travel_country text, add column last_lat double precision;
create table public.zad_transactions (id uuid primary key default gen_random_uuid(), user_id uuid, amount numeric);
create table public.zad_inventory (id uuid primary key default gen_random_uuid(), user_id uuid, family_id uuid, item_name text, quantity numeric);
-- Users that exist before the migration get a row from it.
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1'), ('00000000-0000-0000-0000-0000000000c1');
insert into public.zad_users (id, currency) values ('00000000-0000-0000-0000-0000000000a1', 'EGP');
