-- مراجعة الذاكرة الشهرية (migration 20261027040000, ZAD_PLAN 5.3), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/memory_checks_scaffold.sql
--   psql < supabase/migrations/20261027040000_memory_checks.sql
--   psql < supabase/sql/tests/memory_checks_test.sql
--
-- Raises on the first failed check; each passing one prints "ok:".

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
begin perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, false); end $$;
grant execute on function pg_temp.who(uuid) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
-- 1 Nov 2026 19:00 Cairo = 17:00 UTC. t1 (Telegram): 5 general notes old enough, one fresh, one closed, one
-- superseded, one of another scope. n1: notes but no channel. q1 (Telegram): no general note old enough.
insert into auth.users values
  ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2'), ('00000000-0000-0000-0000-0000000000a3');
insert into public.zad_users (id, currency, country) values
  ('00000000-0000-0000-0000-0000000000a1', 'EGP', 'EG'), ('00000000-0000-0000-0000-0000000000a2', 'EGP', 'EG'),
  ('00000000-0000-0000-0000-0000000000a3', 'EGP', 'EG');
insert into public.telegram_bindings (user_id, chat_id, bound_at) values
  ('00000000-0000-0000-0000-0000000000a1', 1, now()), ('00000000-0000-0000-0000-0000000000a3', 3, now());
insert into public.zad_memory (user_id, scope, note, confidence, created_at, valid_until, superseded_by)
select '00000000-0000-0000-0000-0000000000a1'::uuid, 'general', 'ملاحظة ' || k, 0.6::real, '2026-10-10Z'::timestamptz, null::timestamptz, null::uuid from generate_series(1, 5) k
union all select '00000000-0000-0000-0000-0000000000a1', 'general', 'جديدة', 0.6, '2026-10-30Z', null, null
union all select '00000000-0000-0000-0000-0000000000a1', 'general', 'مقفولة', 0.6, '2026-10-01Z', '2026-10-20Z', null
union all select '00000000-0000-0000-0000-0000000000a1', 'general', 'قديمة اتحل محلها', 0.6, '2026-10-01Z', null, gen_random_uuid()
union all select '00000000-0000-0000-0000-0000000000a1', 'proactive_dismissal', 'رفض تنبيه', 0.4, '2026-10-01Z', null, null
union all select '00000000-0000-0000-0000-0000000000a2', 'general', 'من غير قناة', 0.6, '2026-10-01Z', null, null
union all select '00000000-0000-0000-0000-0000000000a3', 'general', 'جديدة بس', 0.6, '2026-10-30Z', null, null;
\set QUIET 0

select pg_temp.check(public.zad_enqueue_memory_checks('2026-11-01 16:00Z') = 0, 'not before 19:00 local');
select pg_temp.check(public.zad_enqueue_memory_checks('2026-11-01 17:00Z') = 1, 'one home asked: a channel, and notes a week old or more');
select pg_temp.check((select count(*) = 3 from public.zad_memory_checks where user_id = '00000000-0000-0000-0000-0000000000a1'), 'a sample of 3');
select pg_temp.check((select bool_and(note like 'ملاحظة %') from public.zad_memory_checks), 'only live general notes a week old: not fresh, closed, superseded or another scope');
select pg_temp.check((select array_agg(position order by position) = array[1, 2, 3] from public.zad_memory_checks), 'numbered 1 to 3');
select pg_temp.check((select count(distinct task_id) = 1 and bool_and(t.kind = 'memory_check') from public.zad_memory_checks c join public.agent_tasks t on t.id = c.task_id),
  'one memory_check task carries all three');
select pg_temp.check(public.zad_enqueue_memory_checks('2026-11-02 17:00Z') = 0, 'not again within 28 days');

select pg_temp.check(public.zad_memory_check_answer_service('00000000-0000-0000-0000-0000000000a3',
  (select id from public.zad_memory_checks where position = 1), true) ->> 'reason' = 'not_found', 'another home cannot answer');
select pg_temp.check(public.zad_memory_check_answer_service('00000000-0000-0000-0000-0000000000a1',
  (select id from public.zad_memory_checks where position = 1), true) = '{"ok": true, "answer": "yes", "position": 1}', '«صح» is recorded');
select pg_temp.check((select (evidence_count, confidence::numeric(3,1)) = (2, 0.7) from public.zad_memory m
  join public.zad_memory_checks c on c.memory_id = m.id where c.position = 1), '«صح» strengthens the note');
select pg_temp.check(public.zad_memory_check_answer_service('00000000-0000-0000-0000-0000000000a1',
  (select id from public.zad_memory_checks where position = 2), false) ->> 'answer' = 'no', '«مش صح» is recorded');
select pg_temp.check((select m.valid_until is not null and m.valid_until <= now() from public.zad_memory m
  join public.zad_memory_checks c on c.memory_id = m.id where c.position = 2), '«مش صح» closes the note (kept, not deleted)');
select pg_temp.check(public.zad_memory_check_answer_service('00000000-0000-0000-0000-0000000000a1',
  (select id from public.zad_memory_checks where position = 1), false) ->> 'already' = 'true', 'one answer per note');

select pg_temp.check(public.zad_memory_accuracy() = '{"no": 1, "yes": 1, "asked": 3, "enough": false, "yes_pct": 50, "answered": 2}',
  'accuracy: 3 asked, 2 answered, 50% right, under 5 answers not enough');
select pg_temp.who('00000000-0000-0000-0000-0000000000a1');
select pg_temp.check(public.zad_memory_accuracy() is null, 'a customer cannot read everyone''s accuracy');
select pg_temp.check((public.zad_memory_accuracy('00000000-0000-0000-0000-0000000000a1') ->> 'asked')::int = 3, 'but can read their own');
select pg_temp.check(public.zad_memory_accuracy('00000000-0000-0000-0000-0000000000a3') is null, 'not another home''s');
select set_config('request.jwt.claims', '{}', false);

-- 29 days on: notes now a week old join in (a3 qualifies too); nothing asked in the last 90 days or closed comes back.
select pg_temp.check(public.zad_enqueue_memory_checks('2026-11-30 17:00Z') = 2, 'a month on, the next sample for both homes');
select pg_temp.check((select array_agg(note order by note) from public.zad_memory_checks
  where user_id = '00000000-0000-0000-0000-0000000000a1' and asked_at = '2026-11-30 17:00Z')
  = (select array_agg(m.note order by m.note) from public.zad_memory m
      where m.user_id = '00000000-0000-0000-0000-0000000000a1' and m.scope = 'general' and m.superseded_by is null
        and (m.valid_until is null or m.valid_until > '2026-11-30 17:00Z')
        and m.id not in (select memory_id from public.zad_memory_checks where asked_at = '2026-11-01 17:00Z')),
  'the second sample is exactly the live notes not asked in the first');
select pg_temp.check((select count(*) = count(distinct memory_id) from public.zad_memory_checks), 'no note asked twice within 90 days');
