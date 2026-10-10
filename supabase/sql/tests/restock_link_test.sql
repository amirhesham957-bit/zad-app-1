-- A pantry item that runs out writes one restock_link task (migration 20261011120000).
-- Scratch database only:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/restock_link_test.sql   -- stand-ins, then the migration
--
-- The two tables carry only the columns the trigger reads and writes.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated; end if;
end $$;

drop table if exists public.agent_tasks, public.zad_inventory;
create table public.agent_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  task_description text not null,
  status text not null default 'pending',
  scheduled_for timestamptz not null default now(),
  kind text not null default 'reminder',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.zad_inventory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  item_name text,
  quantity numeric
);

\i /m/20261011120000_restock_link.sql

create or replace function pg_temp.check(ok boolean, what text) returns void language plpgsql as $$
begin
  if not coalesce(ok, false) then raise exception 'FAILED: %', what; end if;
  raise notice 'ok: %', what;
end $$;

insert into public.zad_inventory (id, user_id, item_name, quantity) values
  ('00000000-0000-0000-0000-0000000000a1', '11111111-1111-1111-1111-111111111111', 'حليب', 2),
  ('00000000-0000-0000-0000-0000000000a2', '11111111-1111-1111-1111-111111111111', 'قهوة «تركي»', 1),
  ('00000000-0000-0000-0000-0000000000a3', '11111111-1111-1111-1111-111111111111', 'شامبو', 1),
  ('00000000-0000-0000-0000-0000000000b1', '22222222-2222-2222-2222-222222222222', 'رز', 0);

-- A drop that leaves some writes nothing.
update public.zad_inventory set quantity = 1 where id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.check((select count(*) from public.agent_tasks) = 0, 'a drop that leaves some writes nothing');

-- Running out writes one task, a quarter of an hour ahead.
update public.zad_inventory set quantity = 0 where id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.check((select count(*) from public.agent_tasks where kind = 'restock_link') = 1, 'running out writes one task');
select pg_temp.check((select task_description from public.agent_tasks) = 'حليب', 'the task names the item');
select pg_temp.check((select scheduled_for - created_at from public.agent_tasks) = interval '15 minutes', 'sent a quarter of an hour later');

-- What runs out meanwhile joins the same task, cleaned of «» and once only.
update public.zad_inventory set quantity = 0 where id = '00000000-0000-0000-0000-0000000000a2';
update public.zad_inventory set quantity = 3 where id = '00000000-0000-0000-0000-0000000000a1';
update public.zad_inventory set quantity = 0 where id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.check((select count(*) from public.agent_tasks) = 1, 'still one task');
select pg_temp.check((select task_description from public.agent_tasks) = E'حليب\nقهوة  تركي', 'items gathered once each, «» removed');

-- Already at zero, or going below, is not running out again.
update public.zad_inventory set quantity = -1 where id = '00000000-0000-0000-0000-0000000000b1';
select pg_temp.check((select count(*) from public.agent_tasks where user_id = '22222222-2222-2222-2222-222222222222') = 0, 'zero to below zero writes nothing');

-- Once sent, nothing more that day.
update public.agent_tasks set status = 'done';
update public.zad_inventory set quantity = 0 where id = '00000000-0000-0000-0000-0000000000a3';
select pg_temp.check((select count(*) from public.agent_tasks) = 1, 'one message a day');

-- A cancelled one (nothing essential) does not count.
update public.agent_tasks set status = 'cancelled';
update public.zad_inventory set quantity = 1 where id = '00000000-0000-0000-0000-0000000000a3';
update public.zad_inventory set quantity = 0 where id = '00000000-0000-0000-0000-0000000000a3';
select pg_temp.check((select count(*) from public.agent_tasks where status = 'pending' and task_description = 'شامبو') = 1, 'a cancelled task does not block the next');

-- A failure inside the trigger never blocks the pantry.
alter table public.agent_tasks add constraint no_tasks check (false) not valid;
update public.zad_inventory set quantity = 5 where id = '00000000-0000-0000-0000-0000000000b1';
delete from public.agent_tasks;
update public.zad_inventory set quantity = 0 where id = '00000000-0000-0000-0000-0000000000b1';
select pg_temp.check((select quantity from public.zad_inventory where id = '00000000-0000-0000-0000-0000000000b1') = 0, 'the pantry update lands even when the task cannot be written');
