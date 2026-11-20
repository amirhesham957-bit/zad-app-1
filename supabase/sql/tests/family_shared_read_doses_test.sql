-- 20261116060000: a family member who granted 'medicines' shows their doses to the viewer, read only.
-- Chain: scratch_scaffold, worlds_scaffold, 20261001130000_family_shares_by_consent, 20261116060000, this file.
-- P viewer (admin), M member who grants, N member who never grants, O outsider in another family.
\set ON_ERROR_STOP on

\set QUIET 1
insert into auth.users (id) values
  ('00000000-0000-4000-8000-0000000000b1'), ('00000000-0000-4000-8000-0000000000b2'),
  ('00000000-0000-4000-8000-0000000000b3'), ('00000000-0000-4000-8000-0000000000b4');
insert into family_groups (id) values ('00000000-0000-4000-8000-00000000fa01'), ('00000000-0000-4000-8000-00000000fa02');
insert into family_members (family_id, user_id, role) values
  ('00000000-0000-4000-8000-00000000fa01', '00000000-0000-4000-8000-0000000000b1', 'admin'),
  ('00000000-0000-4000-8000-00000000fa01', '00000000-0000-4000-8000-0000000000b2', 'member'),
  ('00000000-0000-4000-8000-00000000fa01', '00000000-0000-4000-8000-0000000000b3', 'member'),
  ('00000000-0000-4000-8000-00000000fa02', '00000000-0000-4000-8000-0000000000b4', 'admin');
insert into zad_pharmacy_items (id, user_id, name, remaining_quantity, daily_dose_count, units_per_dose) values
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000b2', 'كونكور', 10, 1, 1),
  ('00000000-0000-4000-8000-0000000000e3', '00000000-0000-4000-8000-0000000000b3', 'بنادول', 10, 1, 1);
insert into zad_pharmacy_doses (user_id, item_id, scheduled_at, taken_at, status) values
  ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-4000-8000-0000000000e2', now() - interval '2 hours', now() - interval '2 hours', 'taken'),
  ('00000000-0000-4000-8000-0000000000b3', '00000000-0000-4000-8000-0000000000e3', now() - interval '2 hours', now() - interval '2 hours', 'taken');

create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', case p
    when 'P' then '00000000-0000-4000-8000-0000000000b1' when 'M' then '00000000-0000-4000-8000-0000000000b2'
    when 'N' then '00000000-0000-4000-8000-0000000000b3' when 'O' then '00000000-0000-4000-8000-0000000000b4' end,
    'role', 'authenticated')::text, false);
end $$;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
grant execute on function pg_temp.who(text) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
\set QUIET 0

set role authenticated;

-- Before any consent: nothing.
select pg_temp.who('P');
select pg_temp.check((select count(*) from zad_pharmacy_doses) = 0, 'no consent, no doses');

-- P asks both members; only M says yes.
select pg_temp.check((zad_family_request_share('00000000-0000-4000-8000-0000000000b2', array['medicines']) ->> 'requested')::int = 1, 'P asks M');
select pg_temp.check((zad_family_request_share('00000000-0000-4000-8000-0000000000b3', array['medicines']) ->> 'requested')::int = 1, 'P asks N');
select pg_temp.who('M');
select pg_temp.check((zad_family_answer_share((select id from zad_family_shares where owner_id = '00000000-0000-4000-8000-0000000000b2' and scope = 'medicines'), true) ->> 'ok')::boolean, 'M agrees');
select pg_temp.who('P');
select pg_temp.check((select count(*) from zad_pharmacy_doses where user_id = '00000000-0000-4000-8000-0000000000b2') = 1, 'viewer reads the granting member doses');
select pg_temp.check((select count(*) from zad_pharmacy_doses where user_id = '00000000-0000-4000-8000-0000000000b3') = 0, 'not granted: 0 rows');
select pg_temp.check((select count(*) from zad_pharmacy_doses) = 1, 'and nothing else');

-- Read only for the viewer.
do $$ begin
  insert into zad_pharmacy_doses (user_id, item_id, status) values ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-4000-8000-0000000000e2', 'taken');
  raise exception 'FAIL: viewer inserted a dose';
exception when insufficient_privilege or check_violation then raise notice 'ok: viewer cannot insert'; end $$;
do $$ declare n int; begin
  update zad_pharmacy_doses set status = 'skipped' where user_id = '00000000-0000-4000-8000-0000000000b2'; get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: viewer updated % doses', n; end if; raise notice 'ok: viewer cannot update';
end $$;
do $$ declare n int; begin
  delete from zad_pharmacy_doses where user_id = '00000000-0000-4000-8000-0000000000b2'; get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: viewer deleted % doses', n; end if; raise notice 'ok: viewer cannot delete';
end $$;

-- An outsider in another family sees nothing.
select pg_temp.who('O');
select pg_temp.check((select count(*) from zad_pharmacy_doses) = 0, 'outsider: 0 rows');

-- The owner still reads and writes their own.
select pg_temp.who('M');
select pg_temp.check((select count(*) from zad_pharmacy_doses) = 1, 'owner reads own');
insert into zad_pharmacy_doses (user_id, item_id, scheduled_at, status) values ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-4000-8000-0000000000e2', now(), 'taken');
select pg_temp.check((select count(*) from zad_pharmacy_doses) = 2, 'owner writes own');
update zad_pharmacy_doses set status = 'skipped' where user_id = '00000000-0000-4000-8000-0000000000b2' and taken_at is null;
select pg_temp.check((select count(*) from zad_pharmacy_doses where status = 'skipped') = 1, 'owner updates own');

-- Revoking closes it again.
select pg_temp.check((zad_family_revoke_share((select id from zad_family_shares where owner_id = '00000000-0000-4000-8000-0000000000b2' and scope = 'medicines')) ->> 'ok')::boolean, 'M revokes');
select pg_temp.who('P');
select pg_temp.check((select count(*) from zad_pharmacy_doses) = 0, 'after revoke: 0 rows');
reset role;
select 'family_shared_read_doses_test OK' as result;
