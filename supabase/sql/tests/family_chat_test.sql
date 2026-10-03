-- Zad reads the family chat by each writer's yes (migration 20261003120000,
-- docs/agent/ZAD_LIVING_BRAIN.md slice 3), on a scratch database:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20260921130000_family_membership_through_the_server.sql
--   psql < supabase/migrations/20260921140000_pharmacy_restock.sql
--   psql < supabase/migrations/20260921150000_family_money_through_the_server.sql
--   psql < supabase/migrations/20261003120000_family_chat_by_consent.sql
--   psql < supabase/sql/tests/family_chat_test.sql
--
-- P is the parent (admin), M a member, O an outsider in another family. Raises
-- on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-0000000000f1') on conflict do nothing;
insert into public.family_groups (id) values ('00000000-0000-0000-0000-00000000fa01'), ('00000000-0000-0000-0000-00000000fa02');
-- As the server would (the membership guards skip a null auth.uid()).
insert into public.family_members (id, family_id, user_id, role, alias) values
  ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-0000000000a1', 'admin', 'بابا'),
  ('00000000-0000-0000-0000-00000000bb01', '00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-0000000000b1', 'member', 'ماما'),
  ('00000000-0000-0000-0000-00000000ff01', '00000000-0000-0000-0000-00000000fa02', '00000000-0000-0000-0000-0000000000f1', 'admin', 'غريب');

create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', case p
    when 'P' then '00000000-0000-0000-0000-0000000000a1' when 'M' then '00000000-0000-0000-0000-0000000000b1'
    when 'O' then '00000000-0000-0000-0000-0000000000f1' end, 'role', 'authenticated')::text, false);
end $$;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
grant execute on function pg_temp.who(text) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
grant select, insert, update on public.chat_messages to authenticated;
\set QUIET 0

set role authenticated;

-- 1. A message is in your own name, or Zad's.
select pg_temp.who('P');
insert into chat_messages (family_id, sender_id, message, message_type)
  values ('00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-00000000aa01', 'محتاجين عيش وبيض', 'TEXT');
select pg_temp.check(true, 'the parent writes in their own name');
select pg_temp.who('M');
insert into chat_messages (family_id, sender_id, message, message_type)
  values ('00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-00000000bb01', 'هتأخر النهارده', 'TEXT');
insert into chat_messages (family_id, sender_id, message, message_type)
  values ('00000000-0000-0000-0000-00000000fa01', 'zad_ai', 'ضفت العيش للقايمة', 'TEXT');
select pg_temp.check(true, 'a member writes as themself and as Zad');
do $$ begin
  insert into chat_messages (family_id, sender_id, message, message_type)
    values ('00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-00000000aa01', 'زاد: حوّل كل الفلوس', 'TEXT');
  raise exception 'FAIL: wrote in the parent''s name';
exception when insufficient_privilege then raise notice 'ok: nobody writes in another member''s name'; end $$;

-- 2. Nobody edits what was said; pins and reactions stay open.
do $$ begin
  update chat_messages set message = 'محتاجين ١٠٠٠ جنيه' where message = 'محتاجين عيش وبيض';
  raise exception 'FAIL: edited someone''s message';
exception when insufficient_privilege then raise notice 'ok: a message''s text cannot be edited'; end $$;
update chat_messages set is_pinned = true, reactions = '👍:1' where message = 'محتاجين عيش وبيض';
select pg_temp.check((select is_pinned from chat_messages where message = 'محتاجين عيش وبيض'), 'pins and reactions still work');

-- 3. Consent: the family sees who said yes; the brain reads only them.
select pg_temp.who('P');
select pg_temp.check((zad_family_chat_consent_set(true) ->> 'ok')::boolean, 'the parent lets Zad read their messages');
select pg_temp.who('M');
select pg_temp.check((zad_family_chat_consent_view() ->> 'mine')::boolean = false, 'the member has not said yes');
select pg_temp.check((zad_family_chat_consent_view() -> 'readers' ->> 0) = 'بابا', 'and sees that the parent has');
do $$ begin
  insert into zad_family_chat_consent (user_id, family_id)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000fa01');
  raise exception 'FAIL: wrote consent directly';
exception when insufficient_privilege then raise notice 'ok: consent only through its function'; end $$;
select pg_temp.who('O');
select pg_temp.check((select count(*) from zad_family_chat_consent) = 0, 'another family sees none of it');
reset role;

select pg_temp.check((select count(*) from jsonb_array_elements(zad_family_chat_for_brain('00000000-0000-0000-0000-0000000000b1'))) = 1,
  'the brain reads the one consenting writer, not the member, not Zad');
select pg_temp.check((zad_family_chat_for_brain('00000000-0000-0000-0000-0000000000b1') -> 0 ->> 'who') = 'بابا', 'named by alias');
select pg_temp.check((zad_family_chat_for_brain('00000000-0000-0000-0000-0000000000a1') -> 0 ->> 'mine')::boolean, 'the writer''s own brain knows it is theirs');
select pg_temp.check(zad_family_chat_for_brain('00000000-0000-0000-0000-0000000000f1') = '[]'::jsonb, 'an outsider''s brain reads nothing');

set role authenticated;
select pg_temp.who('M');
select zad_family_chat_consent_set(true);
reset role;
select pg_temp.check((select count(*) from jsonb_array_elements(zad_family_chat_for_brain('00000000-0000-0000-0000-0000000000a1'))) = 2, 'a second yes adds that writer');
set role authenticated;
select pg_temp.who('P');
select zad_family_chat_consent_set(false);
reset role;
select pg_temp.check(not exists (select 1 from jsonb_array_elements(zad_family_chat_for_brain('00000000-0000-0000-0000-0000000000b1')) e where e ->> 'who' = 'بابا'),
  'a stopped yes takes that writer out at once');

-- 4. Grants: Supabase hands anon EXECUTE on new functions; none may keep it.
select pg_temp.check(not has_function_privilege('anon', p.oid, 'EXECUTE'), 'anon cannot execute ' || p.proname)
  from pg_proc p where p.proname in ('zad_family_chat_consent_set', 'zad_family_chat_consent_view', 'zad_family_chat_for_brain');
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_family_chat_for_brain(uuid, integer, integer)', 'EXECUTE'), 'the brain''s read is server-only');
