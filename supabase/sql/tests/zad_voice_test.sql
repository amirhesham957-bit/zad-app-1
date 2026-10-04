-- Zad's voice is the customer's explicit choice (migration 20261004090000,
-- docs/agent/ZAD_LIVING_BRAIN.md §8), on a scratch database:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20260914012000_customer_profile.sql
--   psql < supabase/migrations/20260928190000_who_you_care_for.sql
--   psql < supabase/migrations/20261004090000_zad_voice_choice.sql
--   psql < supabase/sql/tests/zad_voice_test.sql
--
-- A is the customer, B someone else. Raises on the first failed check; each
-- passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1')
  on conflict do nothing;
create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', case p
    when 'A' then '00000000-0000-0000-0000-0000000000a1' when 'B' then '00000000-0000-0000-0000-0000000000b1' end,
    'role', 'authenticated')::text, false);
end $$;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
grant execute on function pg_temp.who(text) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
\set QUIET 0

set role authenticated;

-- 1. A new profile has no choice: the default (a girl's voice) is the reader's to apply.
select pg_temp.who('A');
insert into zad_customer_profile (user_id, gender, cares_for) values ('00000000-0000-0000-0000-0000000000a1', 'male', '{parents}');
select pg_temp.check((select zad_voice from zad_customer_profile where user_id = '00000000-0000-0000-0000-0000000000a1') is null,
  'no voice is chosen for the customer — not from gender either');

-- 2. The customer chooses, and changes their mind.
update zad_customer_profile set zad_voice = 'male' where user_id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.check((select zad_voice from zad_customer_profile where user_id = '00000000-0000-0000-0000-0000000000a1') = 'male',
  'the customer picks a boy''s voice');
update zad_customer_profile set zad_voice = 'female' where user_id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.check((select zad_voice from zad_customer_profile where user_id = '00000000-0000-0000-0000-0000000000a1') = 'female',
  'and back to a girl''s');

-- 3. Only the two voices.
do $$ begin
  update zad_customer_profile set zad_voice = 'robot' where user_id = '00000000-0000-0000-0000-0000000000a1';
  raise exception 'FAIL: stored a voice that does not exist';
exception when check_violation then raise notice 'ok: only female or male'; end $$;

-- 4. Nobody chooses someone else's voice.
select pg_temp.who('B');
update zad_customer_profile set zad_voice = 'male' where user_id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.who('A');
select pg_temp.check((select zad_voice from zad_customer_profile where user_id = '00000000-0000-0000-0000-0000000000a1') = 'female',
  'another account cannot change the customer''s voice');
select pg_temp.who('B');
select pg_temp.check(not exists (select 1 from zad_customer_profile where user_id = '00000000-0000-0000-0000-0000000000a1'),
  'nor read it');

reset role;
