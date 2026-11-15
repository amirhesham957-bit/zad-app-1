-- «تصدير بياناتي» (migration 20261115020000), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/export_my_data_scaffold.sql
--   psql < supabase/migrations/20261115020000_export_my_data.sql
--   psql < supabase/migrations/20261115140000_export_hides_admin_chat.sql
--   psql < supabase/sql/tests/export_my_data_test.sql
--
-- Raises on the first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
\o /dev/null
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

\set me '''00000000-0000-0000-0000-0000000000a1'''
\set other '''00000000-0000-0000-0000-0000000000b1'''

insert into auth.users values (:me), (:other);
insert into public.zad_users (id, currency, token) values (:me, 'EGP', 'sekrit-a'), (:other, 'SAR', 'sekrit-b');
insert into public.zad_transactions (user_id, amount, title) values (:me, 50, 'قهوة'), (:me, 20, 'عيش'), (:other, 999, 'مش بتاعي');
insert into public.zad_entitlements values (:me, 'plus', 'play-token-a'), (:other, 'free', 'play-token-b');
insert into public.zad_fcm_tokens (user_id, token) values (:me, 'fcm-a');
insert into public.zad_rate_gate values (:me, 3);
insert into public.zad_support_access_log (user_id, admin_chat, action) values (:me, 987654321, 'lookup');
insert into public.zad_chat_turns (user_id, role, text) select :me::uuid, 'user', 'رسالة ' || g from generate_series(1, 2005) g;
insert into public.zad_chat_turns (user_id, role, text) values (:other, 'user', 'سر الجار');

-- as the signed-in customer, through PostgREST's role
set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :me, 'role', 'authenticated')::text, false);
create temp table out as select public.zad_export_my_data() as j;
reset role;

select pg_temp.check((select j ->> 'user_id' from out) = :me, 'the export is about me');
select pg_temp.check((select jsonb_array_length(j -> 'data' -> 'zad_transactions') from out) = 2, 'my two transactions');
select pg_temp.check(not (select (j -> 'data')::text like '%مش بتاعي%' or (j -> 'data')::text like '%سر الجار%' from out), 'nothing of the neighbour');
select pg_temp.check((select (j -> 'data' -> 'zad_users' -> 0 ->> 'currency') from out) = 'EGP', 'my account row');
select pg_temp.check(not (select (j)::text like '%sekrit%' or j::text like '%play-token%' or j::text like '%fcm-a%' from out), 'no secret column leaks');
select pg_temp.check(not (select j::text like '%987654321%' from out), 'the admin''s chat id is not exported');
select pg_temp.check((select j -> 'data' -> 'zad_support_access_log' -> 0 ->> 'action' from out) = 'lookup', 'but the access itself is');
select pg_temp.check((select j -> 'data' -> 'zad_entitlements' -> 0 ->> 'tier' from out) = 'plus', 'the rest of a row with a secret is kept');
select pg_temp.check(not (select (j -> 'data') ? 'zad_fcm_tokens' or (j -> 'data') ? 'zad_rate_gate' from out), 'internal tables left out');
select pg_temp.check(not (select (j -> 'data') ? 'zad_notes_text_owner' from out), 'only uuid user_id tables');
select pg_temp.check((select jsonb_array_length(j -> 'data' -> 'zad_chat_turns') from out) = 2000, 'capped at 2000 rows');
select pg_temp.check((select (j -> 'data' -> '_truncated') ? 'zad_chat_turns' from out), 'and says it was cut');

-- signed out: nothing
set role authenticated;
select set_config('request.jwt.claims', '{"role":"anon"}', false);
do $$ begin
  perform public.zad_export_my_data();
  raise exception 'FAIL: signed-out call returned data';
exception when insufficient_privilege then null;
end $$;
reset role;
select pg_temp.check(true, 'signed out is refused');
select pg_temp.check(not has_function_privilege('anon', 'public.zad_export_my_data()', 'execute'), 'anon cannot call it');
