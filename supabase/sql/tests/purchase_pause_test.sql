-- The purchase pause (migration 20261005231147, docs/agent/ZAD_LIVING_BRAIN.md slice 36), on a scratch database:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20260921130000_family_membership_through_the_server.sql
--   psql < supabase/migrations/20260921150000_family_money_through_the_server.sql
--   psql < supabase/migrations/20260928180000_allowance_is_a_credit.sql
--   psql < supabase/migrations/20261005231147_purchase_pause.sql
--   psql < supabase/sql/tests/purchase_pause_test.sql
--
-- P is the parent (admin), C a child. Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000c1') on conflict do nothing;
create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', case p
    when 'P' then '00000000-0000-0000-0000-0000000000a1' when 'C' then '00000000-0000-0000-0000-0000000000c1' end,
    'role', 'authenticated')::text, false);
end $$;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
grant execute on function pg_temp.who(text) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
create table if not exists ctx (k text primary key, v text);
grant all on ctx to authenticated;
create or replace function ctxv(k text) returns uuid language sql as $$ select v::uuid from ctx where ctx.k = $1 $$;
grant execute on function ctxv(text) to authenticated;
\set QUIET 0

-- Setup through the real functions: P makes the family, C joins as a child with 100 to spend.
select pg_temp.who('P'); set role authenticated;
insert into ctx select 'fam', (zad_create_family('بابا')->>'family_id');
insert into ctx select 'code', (select invite_code from family_groups);
reset role; select pg_temp.who('C'); set role authenticated;
select zad_join_family((select v from ctx where k = 'code'), 'يوسف');
reset role;
insert into ctx select 'C', id from family_members where user_id = '00000000-0000-0000-0000-0000000000c1';
select pg_temp.who('P'); set role authenticated;
update family_members set role = 'child' where id = ctxv('C');
select zad_send_allowance(ctxv('C'), 100);
reset role;

create or replace function pg_temp.ask(p_amount int, p_kind text) returns uuid language plpgsql as $$
declare v uuid;
begin
  insert into chat_messages (family_id, sender_id, message, message_type, metadata)
  values (ctxv('fam'), ctxv('C')::text, 'عايز ' || p_amount, 'PURCHASE_REQUEST',
          json_build_object('amount', p_amount, 'status', 'PENDING', 'kind', p_kind)::text)
  returning id into v;
  return v;
end $$;
grant execute on function pg_temp.ask(int, text) to authenticated;

-- 1. Off by default: a purchase is approved at once, as before.
select pg_temp.check((select purchase_pause_hours from family_groups where id = ctxv('fam')) = 0, 'off unless the family turns it on');
select pg_temp.who('C'); set role authenticated;
insert into ctx select 'r1', pg_temp.ask(10, 'purchase');
reset role; select pg_temp.who('P'); set role authenticated;
select pg_temp.check((select zad_decide_purchase_request(ctxv('r1'), true) ->> 'status') = 'APPROVED', 'approved at once while off');

-- 2. Only an admin turns it on.
reset role; select pg_temp.who('C'); set role authenticated;
select pg_temp.check((select zad_set_purchase_pause(true) ->> 'reason') = 'not_an_admin', 'a child cannot switch it');
reset role; select pg_temp.who('P'); set role authenticated;
select pg_temp.check((select (zad_set_purchase_pause(true) ->> 'hours')::int) = 24, 'the admin switches it on');

-- 3. On: a fresh purchase waits; the answer says until when; nothing is debited.
reset role; select pg_temp.who('C'); set role authenticated;
insert into ctx select 'r2', pg_temp.ask(20, 'purchase');
reset role; select pg_temp.who('P'); set role authenticated;
select pg_temp.check((select zad_decide_purchase_request(ctxv('r2'), true) ->> 'reason') = 'cooling_off', 'a fresh purchase waits');
select pg_temp.check((select (zad_decide_purchase_request(ctxv('r2'), true) ->> 'ready_at')::timestamptz
  between now() + interval '23 hours 59 minutes' and now() + interval '24 hours 1 minute'), 'ready 24 hours after it was asked');
select pg_temp.check((select balance from family_members where id = ctxv('C')) = 90, 'nothing debited while it waits');

-- 4. After 24 hours it goes through.
reset role;
update chat_messages set created_at = now() - interval '25 hours' where id = ctxv('r2');
select pg_temp.who('P'); set role authenticated;
select pg_temp.check((select zad_decide_purchase_request(ctxv('r2'), true) ->> 'status') = 'APPROVED', 'approved after the pause');
select pg_temp.check((select balance from family_members where id = ctxv('C')) = 70, 'and debited then');

-- 5. Saying no never waits, and an allowance request is not a purchase.
reset role; select pg_temp.who('C'); set role authenticated;
insert into ctx select 'r3', pg_temp.ask(30, 'purchase');
insert into ctx select 'r4', pg_temp.ask(15, 'allowance');
reset role; select pg_temp.who('P'); set role authenticated;
select pg_temp.check((select zad_decide_purchase_request(ctxv('r3'), false) ->> 'status') = 'REJECTED', 'a no is immediate');
select pg_temp.check((select zad_decide_purchase_request(ctxv('r4'), true) ->> 'status') = 'APPROVED', 'an allowance is not paused');

-- 6. Switching it off lets a waiting purchase through.
select pg_temp.who('C'); set role authenticated;
insert into ctx select 'r5', pg_temp.ask(5, 'purchase');
reset role; select pg_temp.who('P'); set role authenticated;
select pg_temp.check((select zad_decide_purchase_request(ctxv('r5'), true) ->> 'reason') = 'cooling_off', 'waits while on');
select pg_temp.check((select (zad_set_purchase_pause(false) ->> 'hours')::int) = 0, 'the admin switches it off');
select pg_temp.check((select zad_decide_purchase_request(ctxv('r5'), true) ->> 'status') = 'APPROVED', 'goes through once off');
reset role;

-- 7. The column takes only off or 24 hours, and no client writes it directly.
do $$ begin
  update family_groups set purchase_pause_hours = 3;
  raise exception 'FAIL: 3 hours accepted';
exception when check_violation then raise notice 'ok: only 0 or 24'; end $$;
set role anon;
do $$ begin
  perform zad_set_purchase_pause(true);
  raise exception 'FAIL: anon switched it';
exception when insufficient_privilege then raise notice 'ok: anon cannot switch it'; end $$;
reset role;
