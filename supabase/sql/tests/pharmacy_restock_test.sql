-- zad_pharmacy_restock (migration 20260921140000), as real accounts on a scratch
-- database — see scratch_scaffold.sql for how to run it. Each block rolls back;
-- the two fixture rows stay.

\set ON_ERROR_STOP on

-- Scratch databases only: these files write rows. A real Supabase database has a
-- storage schema; refuse before touching anything.
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

insert into auth.users values ('00000000-0000-0000-0000-00000000000a'), ('00000000-0000-0000-0000-00000000000b');
insert into zad_pharmacy_items (id, user_id, name, unit, remaining_quantity)
values ('11111111-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'Concor 5', 'قرص', 3),
       ('22222222-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000b', 'بانادول', 'قرص', 7);

begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;
do $$
declare r jsonb; a uuid := '00000000-0000-0000-0000-00000000000a'; b uuid := '00000000-0000-0000-0000-00000000000b';
begin
  -- 1. restock own medicine
  r := zad_pharmacy_restock(a, 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 30);
  assert (r->>'ok')::bool and not (r->>'duplicate')::bool, r::text;
  assert (r->'item'->>'remaining_quantity')::int = 33, r::text;
  -- 2. same restock id again: nothing added
  r := zad_pharmacy_restock(a, 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 30);
  assert (r->>'duplicate')::bool and (r->'item'->>'remaining_quantity')::int = 33, r::text;
  -- 3. a new medicine lands with its stock, not the column default + stock
  r := zad_pharmacy_restock(a, 'aaaaaaaa-0000-0000-0000-000000000002', '33333333-0000-0000-0000-000000000003', 20, 'أوجمنتين', 'قرص', 'مضاد حيوي');
  assert (r->>'created')::bool and (r->'item'->>'remaining_quantity')::int = 20, r::text;
  assert r->'item'->>'category' = 'مضاد حيوي', r::text;
  -- 3b. replaying the creation adds nothing
  r := zad_pharmacy_restock(a, 'aaaaaaaa-0000-0000-0000-000000000002', '33333333-0000-0000-0000-000000000003', 20, 'أوجمنتين', 'قرص', 'مضاد حيوي');
  assert (r->>'duplicate')::bool and (r->'item'->>'remaining_quantity')::int = 20, r::text;
  -- 4. a "new" medicine whose name the account already has goes to that row
  r := zad_pharmacy_restock(a, 'aaaaaaaa-0000-0000-0000-000000000003', '44444444-0000-0000-0000-000000000004', 10, '  concor 5 ', null, null);
  assert not (r->>'created')::bool and r->'item'->>'id' = '11111111-0000-0000-0000-000000000001', r::text;
  assert (r->'item'->>'remaining_quantity')::int = 43, r::text;
  -- 4b. and its replay is answered from the row it really went to
  r := zad_pharmacy_restock(a, 'aaaaaaaa-0000-0000-0000-000000000003', '44444444-0000-0000-0000-000000000004', 10, '  concor 5 ', null, null);
  assert (r->>'duplicate')::bool and r->'item'->>'id' = '11111111-0000-0000-0000-000000000001', r::text;
  -- 5. someone else's medicine id: not found, and their count untouched
  r := zad_pharmacy_restock(a, 'aaaaaaaa-0000-0000-0000-000000000004', '22222222-0000-0000-0000-000000000002', 50);
  assert r->>'reason' = 'not_found', r::text;
  r := zad_pharmacy_restock(a, 'aaaaaaaa-0000-0000-0000-000000000005', '22222222-0000-0000-0000-000000000002', 50, 'بانادول', null, null);
  -- Their id is taken: nothing is inserted under it, and A has no row of that name.
  assert r->>'reason' = 'not_found', r::text;
  -- 6. posing as another user
  begin
    r := zad_pharmacy_restock(b, 'aaaaaaaa-0000-0000-0000-000000000006', '22222222-0000-0000-0000-000000000002', 5);
    raise exception 'posing as b was allowed';
  exception when insufficient_privilege then null;
  end;
  -- 7. bad quantities
  assert zad_pharmacy_restock(a, gen_random_uuid(), '11111111-0000-0000-0000-000000000001', 0)->>'reason' = 'invalid_input';
  assert zad_pharmacy_restock(a, gen_random_uuid(), '11111111-0000-0000-0000-000000000001', 10001)->>'reason' = 'invalid_input';
  -- 8. unknown id, no name
  assert zad_pharmacy_restock(a, gen_random_uuid(), gen_random_uuid(), 1)->>'reason' = 'not_found';
  -- 9. the log is A's only
  assert (select count(*) from zad_pharmacy_restocks) = 3, (select count(*) from zad_pharmacy_restocks)::text;
  raise notice 'AS A: all checks passed';
end $$;
rollback;

-- anon cannot call it at all
begin;
set local role anon;
do $$ begin
  perform zad_pharmacy_restock('00000000-0000-0000-0000-00000000000a', gen_random_uuid(), '11111111-0000-0000-0000-000000000001', 1);
  raise exception 'anon was allowed';
exception when insufficient_privilege then raise notice 'AS ANON: refused';
end $$;
rollback;

-- the service role can restock for a user
begin;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
do $$ declare r jsonb; begin
  r := zad_pharmacy_restock('00000000-0000-0000-0000-00000000000b', gen_random_uuid(), '22222222-0000-0000-0000-000000000002', 5);
  assert (r->'item'->>'remaining_quantity')::int = 12, r::text;
  raise notice 'AS SERVICE ROLE: ok';
end $$;
rollback;
select id, remaining_quantity from zad_pharmacy_items order by id;
