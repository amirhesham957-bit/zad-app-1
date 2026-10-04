-- Family polls (migration 20261004130000, docs/agent/ZAD_LIVING_BRAIN.md slice 24),
-- on a scratch database:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20260921130000_family_membership_through_the_server.sql
--   psql < supabase/migrations/20260921140000_pharmacy_restock.sql
--   psql < supabase/migrations/20260921150000_family_money_through_the_server.sql
--   psql < supabase/migrations/20261003120000_family_chat_by_consent.sql
--   psql < supabase/migrations/20261004130000_family_polls.sql
--   psql < supabase/sql/tests/family_polls_test.sql
--
-- P is the parent (admin), M a member, K a child, O an outsider. Raises on the
-- first failed check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-0000000000c1'), ('00000000-0000-0000-0000-0000000000f1') on conflict do nothing;
insert into public.family_groups (id) values ('00000000-0000-0000-0000-00000000fa01'), ('00000000-0000-0000-0000-00000000fa02');
insert into public.family_members (id, family_id, user_id, role, alias) values
  ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-0000000000a1', 'admin', 'بابا'),
  ('00000000-0000-0000-0000-00000000bb01', '00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-0000000000b1', 'member', 'ماما'),
  ('00000000-0000-0000-0000-00000000cc01', '00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-0000000000c1', 'child', 'عمر'),
  ('00000000-0000-0000-0000-00000000ff01', '00000000-0000-0000-0000-00000000fa02', '00000000-0000-0000-0000-0000000000f1', 'admin', 'غريب');
create or replace function pg_temp.who(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', case p
    when 'P' then '00000000-0000-0000-0000-0000000000a1' when 'M' then '00000000-0000-0000-0000-0000000000b1'
    when 'K' then '00000000-0000-0000-0000-0000000000c1' when 'O' then '00000000-0000-0000-0000-0000000000f1' end,
    'role', 'authenticated')::text, false);
end $$;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
grant execute on function pg_temp.who(text) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
grant select, insert, update on public.chat_messages to authenticated;
\set QUIET 0

set role authenticated;

-- 1. A poll is a question with 2–6 options and no votes yet.
select pg_temp.who('M');
insert into chat_messages (id, family_id, sender_id, message, message_type, metadata)
  values ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-00000000bb01',
          '📊 نسافر فين في الإجازة؟', 'POLL', '{"question":"نسافر فين في الإجازة؟","options":["الساحل","الأقصر","البيت"],"votes":{}}');
select pg_temp.check(true, 'a member opens a poll');
do $$ begin
  insert into chat_messages (family_id, sender_id, message, message_type, metadata)
    values ('00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-00000000bb01', '📊 x', 'POLL',
            '{"question":"x","options":["أ","ب"],"votes":{"00000000-0000-0000-0000-00000000aa01":0}}');
  raise exception 'FAIL: a poll arrived with votes already in it';
exception when sqlstate '22023' then raise notice 'ok: no ready-made votes'; end $$;
do $$ begin
  insert into chat_messages (family_id, sender_id, message, message_type, metadata)
    values ('00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-00000000bb01', '📊 x', 'POLL',
            '{"question":"x","options":["أ"]}');
  raise exception 'FAIL: a one-option poll';
exception when sqlstate '22023' then raise notice 'ok: at least two options'; end $$;

-- 2. Everyone votes for themself, and can change it; nobody writes another's vote.
select pg_temp.who('P');
select pg_temp.check((zad_family_poll_vote('00000000-0000-0000-0000-0000000000d1', 1) ->> 'ok')::boolean, 'the parent votes');
select pg_temp.who('M');
select pg_temp.check((zad_family_poll_vote('00000000-0000-0000-0000-0000000000d1', 0) ->> 'votes')::int = 2, 'the member votes');
select pg_temp.check((zad_family_poll_vote('00000000-0000-0000-0000-0000000000d1', 1) ->> 'votes')::int = 2, 'and changes their mind');
select pg_temp.who('K');
select pg_temp.check((zad_family_poll_vote('00000000-0000-0000-0000-0000000000d1', 0) ->> 'ok')::boolean, 'the child votes too');
select pg_temp.check((zad_family_poll_vote('00000000-0000-0000-0000-0000000000d1', 7) ->> 'reason') = 'bad_option', 'no option 8');
do $$ begin
  update chat_messages set metadata = '{"question":"x","options":["أ","ب"],"votes":{"00000000-0000-0000-0000-00000000aa01":0}}'
   where id = '00000000-0000-0000-0000-0000000000d1';
  raise exception 'FAIL: rewrote the votes';
exception when insufficient_privilege then raise notice 'ok: votes are not rewritten from the app'; end $$;
select pg_temp.who('O');
select pg_temp.check((zad_family_poll_vote('00000000-0000-0000-0000-0000000000d1', 0) ->> 'reason') = 'not_in_family', 'an outsider cannot vote');

-- 3. Closing: the child cannot; the parent can; the result counts and is announced by Zad.
select pg_temp.who('K');
select pg_temp.check((zad_family_poll_close('00000000-0000-0000-0000-0000000000d1') ->> 'reason') = 'not_allowed', 'a child cannot close it');
select pg_temp.who('P');
select pg_temp.check((zad_family_poll_close('00000000-0000-0000-0000-0000000000d1') -> 'result' ->> 'winner')::int = 1, 'الأقصر wins 2 to 1');
select pg_temp.check((select (metadata::jsonb -> 'result' ->> 'consensus')::boolean from chat_messages where id = '00000000-0000-0000-0000-0000000000d1'),
  'both adults chose it: consensus');
select pg_temp.check((select message from chat_messages where sender_id = 'zad_ai' order by created_at desc limit 1)
  = '📊 نتيجة «نسافر فين في الإجازة؟»: الأقصر (2 من 3 صوت) — الكبار كلهم متفقين ✅', 'Zad announces the result');
select pg_temp.who('M');
select pg_temp.check((zad_family_poll_vote('00000000-0000-0000-0000-0000000000d1', 0) ->> 'reason') = 'closed', 'no votes after closing');
select pg_temp.check((zad_family_poll_close('00000000-0000-0000-0000-0000000000d1') ->> 'already')::boolean, 'closing twice changes nothing');

-- 4. A tie has no winner; adults split means no consensus.
insert into chat_messages (id, family_id, sender_id, message, message_type, metadata)
  values ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-00000000bb01',
          '📊 أكل الجمعة؟', 'POLL', '{"question":"أكل الجمعة؟","options":["مشويات","بيتزا"],"votes":{}}');
select zad_family_poll_vote('00000000-0000-0000-0000-0000000000d2', 0);
select pg_temp.who('P');
select zad_family_poll_vote('00000000-0000-0000-0000-0000000000d2', 1);
select pg_temp.who('M');
select pg_temp.check((zad_family_poll_close('00000000-0000-0000-0000-0000000000d2') -> 'result' ->> 'winner') is null, 'a tie has no winner');
reset role;

-- 5. Due polls close on their own (the hourly job). Written as the server would (no auth.uid()).
select set_config('request.jwt.claims', '{}', false);
insert into chat_messages (id, family_id, sender_id, message, message_type, metadata)
  values ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-00000000fa01', 'zad_ai', '📊 تمرين؟', 'POLL',
          format('{"question":"تمرين؟","options":["أيوه","لأ"],"votes":{},"closes_at":"%s"}', now() - interval '1 hour'));
select pg_temp.check(public.zad_family_polls_close_due() = 1, 'the due poll closes');
select pg_temp.check((select (metadata::jsonb ->> 'closed')::boolean from chat_messages where id = '00000000-0000-0000-0000-0000000000d3'), 'and is marked closed');

-- 6. The public key cannot call any of it.
set role anon;
do $$ begin
  perform zad_family_poll_vote('00000000-0000-0000-0000-0000000000d1', 0);
  raise exception 'FAIL: anon voted';
exception when insufficient_privilege then raise notice 'ok: anon cannot vote'; end $$;
reset role;
