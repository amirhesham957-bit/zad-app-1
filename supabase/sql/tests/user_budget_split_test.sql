-- P2.5b: zad_user_budget (migration 20261128210000) on a scratch database. Chain:
--   scratch_scaffold, view_rpcs_scaffold, visibility_matrix_scaffold, user_budget_split_scaffold (that order: this scaffold
--   seeds the family and zad_users rows, so the backfill is exercised), 20261001130000, 20261127140000, 20261127150000, 20261128190000,
--   20261128210000, then this file.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
create or replace function pg_temp.who(p uuid) returns void language plpgsql as $$
begin reset role; perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, false); set role authenticated; end $$;
grant execute on function pg_temp.who(uuid) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set b '''00000000-0000-0000-0000-0000000000b1'''
\set k '''00000000-0000-0000-0000-0000000000d1'''
\set o '''00000000-0000-0000-0000-0000000000e1'''
\set QUIET 0

-- the matrix scaffold inserted the rows before the migration: the backfill copied them.
select pg_temp.check((select count(*) from public.zad_user_budget) = 4, 'backfill: a row per zad_users row');
select pg_temp.check((select monthly_limit from public.zad_user_budget where user_id = :a) = 5000, 'backfill: monthly_limit copied');

-- a write to zad_users is mirrored (insert and update).
reset role;
insert into public.zad_users (id, monthly_limit, emergency_fund_balance, cycle_start_day) values (gen_random_uuid(), 1, 2, 5);
select pg_temp.check((select count(*) from public.zad_user_budget) = 5, 'mirror: insert');
update public.zad_users set monthly_limit = 6000, emergency_fund_balance = 90, cycle_start_day = 27 where id = :a;
select pg_temp.check((select monthly_limit from public.zad_user_budget where user_id = :a) = 6000
  and (select emergency_fund_balance from public.zad_user_budget where user_id = :a) = 90
  and (select cycle_start_day from public.zad_user_budget where user_id = :a) = 27, 'mirror: update');

-- who reads what.
select pg_temp.who(:b);
select pg_temp.check((select count(*) from public.zad_user_budget) = 1 and (select user_id from public.zad_user_budget) = :b, 'an adult reads only their own row');
select pg_temp.who(:a);
select pg_temp.check((select count(*) from public.zad_user_budget where user_id = :k) = 1, 'the guardian reads their child''s row');
select pg_temp.who(:k);
select pg_temp.check((select count(*) from public.zad_user_budget) = 0, 'the child reads no budget row, not even their own');
select pg_temp.who(:o);
select pg_temp.check((select count(*) from public.zad_user_budget where user_id in (:a, :k)) = 0, 'a stranger reads none of this family');

-- no client writes.
select pg_temp.who(:b);
do $$ begin
  begin update public.zad_user_budget set monthly_limit = 1 where user_id = '00000000-0000-0000-0000-0000000000b1'; perform pg_temp.check(false, 'client write refused');
  exception when insufficient_privilege then perform pg_temp.check(true, 'client write refused'); end;
end $$;
reset role;
\echo user_budget_split: all checks passed
