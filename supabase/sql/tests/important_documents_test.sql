-- The documents guard (migration 20261005153017, docs/agent/ZAD_LIVING_BRAIN.md slice 32), on a scratch database:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261005153017_important_documents.sql
--   psql < supabase/sql/tests/important_documents_test.sql
--
-- A and B are two accounts. Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1') on conflict do nothing;
create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', case p
    when 'A' then json_build_object('sub', '00000000-0000-0000-0000-0000000000a1', 'role', 'authenticated')::text
    when 'B' then json_build_object('sub', '00000000-0000-0000-0000-0000000000b1', 'role', 'authenticated')::text
    else '' end, false);
end $$;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
grant execute on function pg_temp.who(text) to authenticated, anon;
grant execute on function pg_temp.check(boolean, text) to authenticated, anon;
\set QUIET 0

set role authenticated;
select pg_temp.who('A');

-- 1. The customer's own documents go in; holder empty = the customer.
insert into zad_documents (user_id, kind, expires_on) values ('00000000-0000-0000-0000-0000000000a1', 'passport', '2027-03-15');
insert into zad_documents (user_id, kind, holder, expires_on) values ('00000000-0000-0000-0000-0000000000a1', 'passport', 'سلمى', '2026-12-01');
insert into zad_documents (user_id, kind, label, expires_on) values ('00000000-0000-0000-0000-0000000000a1', 'other', 'كارنيه النادي', '2026-11-01');
select pg_temp.check((select count(*) from zad_documents) = 3, 'three documents stored');

-- 2. One row per (kind, holder, label): a renewal is an upsert on that key, not a second passport.
insert into zad_documents (user_id, kind, expires_on) values ('00000000-0000-0000-0000-0000000000a1', 'passport', '2037-03-14')
  on conflict on constraint zad_documents_one_per_holder do update set expires_on = excluded.expires_on;
select pg_temp.check((select expires_on from zad_documents where kind = 'passport' and holder = '') = '2037-03-14'
  and (select count(*) from zad_documents) = 3, 'a renewal replaces the date');

-- 3. Nonsense is refused by the table itself.
do $$ begin
  insert into zad_documents (user_id, kind, expires_on) values ('00000000-0000-0000-0000-0000000000a1', 'credit_card', '2027-01-01');
  raise exception 'FAIL: unknown kind accepted';
exception when check_violation then raise notice 'ok: only the known kinds'; end $$;
do $$ begin
  insert into zad_documents (user_id, kind, expires_on) values ('00000000-0000-0000-0000-0000000000a1', 'other', '2027-01-01');
  raise exception 'FAIL: unnamed other accepted';
exception when check_violation then raise notice 'ok: «other» needs a name'; end $$;
do $$ begin
  insert into zad_documents (user_id, kind, holder, expires_on) values ('00000000-0000-0000-0000-0000000000a1', 'residence', ' عمر ', '2027-01-01');
  raise exception 'FAIL: untrimmed holder accepted';
exception when check_violation then raise notice 'ok: holder is trimmed, so the key cannot split'; end $$;
do $$ begin
  insert into zad_documents (user_id, kind, expires_on) values ('00000000-0000-0000-0000-0000000000a1', 'residence', '1990-01-01');
  raise exception 'FAIL: absurd date accepted';
exception when check_violation then raise notice 'ok: absurd dates refused'; end $$;

-- 4. Nobody else reads, edits, deletes or adds for A.
select pg_temp.who('B');
select pg_temp.check((select count(*) from zad_documents) = 0, 'another account sees nothing');
update zad_documents set expires_on = '2030-01-01';
delete from zad_documents;
do $$ begin
  insert into zad_documents (user_id, kind, expires_on) values ('00000000-0000-0000-0000-0000000000a1', 'national_id', '2027-01-01');
  raise exception 'FAIL: B wrote into A''s documents';
exception when insufficient_privilege then raise notice 'ok: no writing into another account'; end $$;
select pg_temp.who('A');
select pg_temp.check((select count(*) from zad_documents) = 3
  and (select expires_on from zad_documents where holder = 'سلمى') = '2026-12-01', 'B changed and deleted nothing');

-- 5. A can't move a document to B either.
do $$ begin
  update zad_documents set user_id = '00000000-0000-0000-0000-0000000000b1' where holder = 'سلمى';
  raise exception 'FAIL: moved a document to another account';
exception when insufficient_privilege then raise notice 'ok: a document stays with its owner'; end $$;

-- 6. The owner deletes their own.
delete from zad_documents where kind = 'other';
select pg_temp.check((select count(*) from zad_documents) = 2, 'the owner deletes');
reset role;

-- 7. anon has nothing at all.
set role anon;
do $$ begin
  perform 1 from zad_documents;
  raise exception 'FAIL: anon read documents';
exception when insufficient_privilege then raise notice 'ok: anon cannot read'; end $$;
reset role;

-- 8. No column for a document number or a picture — the guard only needs the date.
select pg_temp.check((select array_agg(column_name::text order by column_name) from information_schema.columns
  where table_schema = 'public' and table_name = 'zad_documents')
  = array['created_at', 'expires_on', 'holder', 'id', 'kind', 'label', 'user_id'], 'only kind, holder, label and date');
