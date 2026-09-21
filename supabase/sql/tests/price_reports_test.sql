-- Crowd price reports through the server (migration 20260921160000), as real accounts
-- on a scratch database — see scratch_scaffold.sql for how to run it. Each block rolls
-- back; the fixture accounts stay.

\set ON_ERROR_STOP on

-- Scratch databases only: these files write rows. A real Supabase database has a
-- storage schema; refuse before touching anything.
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

insert into auth.users values ('00000000-0000-0000-0000-0000000000e1'), ('00000000-0000-0000-0000-0000000000e2')
  on conflict do nothing;
insert into public.zad_users (id, currency) values ('00000000-0000-0000-0000-0000000000e1', 'EGP'),
  ('00000000-0000-0000-0000-0000000000e2', null) on conflict do nothing;

begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e1","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  r jsonb; me uuid := '00000000-0000-0000-0000-0000000000e1';
  first_id bigint;
begin
  -- 1. a report lands, in the account's currency whatever the phone says
  r := zad_report_price('aaaaaaaa-0000-0000-0000-00000000e001', '  طماطم   بلدي ', 12.5, 'SAR', 'القاهرة', 'خير زمان', 'خضار');
  assert (r->>'ok')::bool and r->>'currency' = 'EGP', r::text;
  first_id := (r->>'id')::bigint;
  assert (select item_name from price_index where id = first_id) = 'طماطم بلدي';
  assert (select source from price_index where id = first_id) = 'crowdsource';
  -- 2. its replay adds nothing
  r := zad_report_price('aaaaaaaa-0000-0000-0000-00000000e001', 'طماطم بلدي', 12.5, null, 'القاهرة', 'خير زمان', null);
  assert (r->>'duplicate')::bool and (r->>'id')::bigint = first_id, r::text;
  -- 3. the same item, store and city again is a correction, not a second voice
  r := zad_report_price('aaaaaaaa-0000-0000-0000-00000000e002', 'طماطم  بلدي', 11, null, 'القاهرة', 'خير زمان', null);
  assert (r->>'updated')::bool and (r->>'id')::bigint = first_id, r::text;
  assert (select count(*) from price_index) = 1;
  assert (select price from price_index where id = first_id) = 11;
  -- 4. another store is another report
  r := zad_report_price('aaaaaaaa-0000-0000-0000-00000000e003', 'طماطم بلدي', 10, null, 'القاهرة', 'كارفور', null);
  assert (r->>'ok')::bool and not coalesce((r->>'updated')::bool, false), r::text;
  -- 5. bad input is refused, with a reason
  assert zad_report_price(gen_random_uuid(), 'x', 5)->>'reason' = 'invalid_input';
  assert zad_report_price(gen_random_uuid(), 'لبن', 0)->>'reason' = 'invalid_input';
  assert zad_report_price(gen_random_uuid(), 'لبن', 2000000)->>'reason' = 'invalid_input';
  assert zad_report_price(gen_random_uuid(), 'لبن', 5, null, null, repeat('م', 61))->>'reason' = 'invalid_input';
  -- 6. no direct writes of any kind
  begin
    insert into price_index (item_name, price, currency, source) values ('سكر', 1, 'EGP', 'usda');
    raise exception 'direct insert without a user was allowed';
  exception when insufficient_privilege then null; end;
  begin
    insert into price_index (item_name, price, currency, source, user_id) values ('سكر', 1, 'EGP', 'crowdsource', me);
    raise exception 'direct insert as self was allowed';
  exception when insufficient_privilege then null; end;
  begin
    update price_index set price = 0.01 where id = first_id;
    raise exception 'direct update was allowed';
  exception when insufficient_privilege then null; end;
  -- 7. 30 new reports an hour
  for i in 1..28 loop
    r := zad_report_price(gen_random_uuid(), 'صنف ' || i, 1);
    assert (r->>'ok')::bool, r::text;
  end loop;
  r := zad_report_price(gen_random_uuid(), 'صنف زيادة', 1);
  assert r->>'reason' = 'too_many', r::text;
  -- ...but a correction of an existing one still goes through
  r := zad_report_price(gen_random_uuid(), 'صنف 1', 2);
  assert (r->>'updated')::bool, r::text;
  raise notice 'AS REPORTER: all checks passed';
end $$;
rollback;

-- Another account: reads only its own rows; the aggregates work and name nobody.
begin;
reset role;
insert into price_index (item_name, price, currency, user_id, location, store_name, source)
values ('طماطم', 10, 'EGP', '00000000-0000-0000-0000-0000000000e1', 'القاهرة', 'كارفور', 'crowdsource'),
       ('طماطم', 12, 'EGP', '00000000-0000-0000-0000-0000000000e1', 'الجيزة', 'خير زمان', 'crowdsource'),
       ('لبن', 30, 'EGP', '00000000-0000-0000-0000-0000000000e2', 'القاهرة', null, 'crowdsource');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare r record; n int;
begin
  select count(*) into n from price_index;
  assert n = 1, 'sees ' || n || ' rows, not only its own';
  select * into r from zad_cheapest_prices('EGP') where item_name = 'طماطم';
  assert r.min_price = 10 and r.reports = 2 and r.cheapest_store = 'كارفور', r::text;
  select count(*) into n from zad_price_leaderboard('EGP');
  assert n = 2, n::text;
  select * into r from zad_price_leaderboard('EGP') where is_me;
  assert r.reports = 1 and r.rank = 2, r::text;
  -- an account with no currency of its own uses the phone's, and must send a real one
  assert zad_report_price(gen_random_uuid(), 'عيش', 5, 'egp')->>'currency' = 'EGP';
  assert zad_report_price(gen_random_uuid(), 'عيش فينو', 5, 'جنيه')->>'reason' = 'invalid_currency';
  raise notice 'AS ANOTHER ACCOUNT: all checks passed';
end $$;
rollback;

-- Nobody signed in: nothing to read, nothing to call.
begin;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
do $$ begin
  begin
    perform zad_report_price(gen_random_uuid(), 'لبن', 5, 'EGP');
    raise exception 'anon reported a price';
  exception when insufficient_privilege then null; end;
  begin
    perform * from zad_cheapest_prices('EGP');
    raise exception 'anon read the cheapest prices';
  exception when insufficient_privilege then null; end;
  begin
    insert into price_index (item_name, price, currency, source) values ('سكر', 1, 'EGP', 'usda');
    raise exception 'anon inserted a reference price';
  exception when insufficient_privilege then null; end;
  if (select count(*) from price_index) <> 0 then raise exception 'anon can read reports'; end if;
  raise notice 'AS ANON: refused';
end $$;
rollback;
