-- One pay day from either side (migration 20261010150000). Scratch database only:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/pay_day_both_ways_test.sql
--
-- The two tables in their live columns that matter here, the cycle→profile trigger exactly
-- as 20261001190000 defined it, then the migration.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

drop table if exists public.zad_customer_profile cascade;
drop table if exists public.zad_users cascade;
create table public.zad_users (id uuid primary key, cycle_start_day integer);
create table public.zad_customer_profile (
  user_id uuid primary key, pay_day integer,
  updated_at timestamptz default now(), updated_by text default 'app');

-- 20261001190000, unchanged.
create or replace function public.zad_sync_pay_day_from_cycle()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
begin
  if new.cycle_start_day is not null
     and new.cycle_start_day between 1 and 31
     and new.cycle_start_day is distinct from old.cycle_start_day then
    insert into public.zad_customer_profile (user_id, pay_day, updated_by)
    values (new.id, new.cycle_start_day, 'app')
    on conflict (user_id) do update
      set pay_day = excluded.pay_day, updated_at = now(), updated_by = 'app';
  end if;
  return new;
end;
$function$;
create trigger zad_users_sync_pay_day
  after update of cycle_start_day on public.zad_users
  for each row execute function public.zad_sync_pay_day_from_cycle();

\ir ../../migrations/20261010150000_pay_day_both_ways.sql

do $$
declare
  u uuid := '00000000-0000-0000-0000-0000000000c1';
  fresh uuid := '00000000-0000-0000-0000-0000000000c2';
begin
  -- The owner's split: the cycle on 16, «ملفي» says 30.
  insert into zad_users values (u, 16);
  insert into zad_customer_profile (user_id, pay_day) values (u, 16);
  update zad_customer_profile set pay_day = 30 where user_id = u;
  assert (select cycle_start_day from zad_users where id = u) = 30, 'profile did not move the cycle';
  assert (select pay_day from zad_customer_profile where user_id = u) = 30;

  -- The other way still works, and the echo stops (no loop, one value on both sides).
  update zad_users set cycle_start_day = 25 where id = u;
  assert (select pay_day from zad_customer_profile where user_id = u) = 25;
  assert (select cycle_start_day from zad_users where id = u) = 25;

  -- A first profile row sets the cycle of an account that had none.
  insert into zad_users values (fresh, null);
  insert into zad_customer_profile (user_id, pay_day) values (fresh, 1);
  assert (select cycle_start_day from zad_users where id = fresh) = 1;

  -- Clearing the profile's pay day, or a day out of range, leaves the cycle alone.
  update zad_customer_profile set pay_day = null where user_id = u;
  assert (select cycle_start_day from zad_users where id = u) = 25;
  update zad_customer_profile set pay_day = 40 where user_id = u;
  assert (select cycle_start_day from zad_users where id = u) = 25;
end $$;

select 'pay_day_both_ways_test: all passed' as result;
