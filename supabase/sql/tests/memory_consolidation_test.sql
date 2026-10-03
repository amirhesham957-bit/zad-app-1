-- The nightly review's gate and marker (migration 20261003130000,
-- docs/agent/ZAD_LIVING_BRAIN.md slice 4), on a scratch database — see
-- memory_consolidation_scaffold.sql for the order. Raises on the first failed
-- check; each passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
\set u '''00000000-0000-0000-0000-0000000000a1'''
insert into auth.users values (:u) on conflict do nothing;
insert into public.zad_users (id, currency) values (:u, 'EGP') on conflict (id) do nothing;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
\set QUIET 0

-- Two messages from the customer today: not worth a model call.
insert into zad_chat_turns (user_id, role, text, created_at) values
  (:u, 'user', 'أخويا أحمد جاي من السفر', now() - interval '5 hours'),
  (:u, 'assistant', 'حمد الله على سلامته', now() - interval '5 hours' + interval '1 second'),
  (:u, 'user', 'هيقعد عندنا لحد الجمعة', now() - interval '4 hours'),
  -- Older than a day: never read.
  (:u, 'user', 'كلام من امبارح بدري', now() - interval '30 hours');
select pg_temp.check(zad_memory_consolidation_due(:u, 3) = '[]'::jsonb, 'two messages today: no review');

insert into zad_chat_turns (user_id, role, text, created_at) values
  (:u, 'user', 'وماما مسافرة لحد الخميس', now() - interval '3 hours');
select pg_temp.check(jsonb_array_length(zad_memory_consolidation_due(:u, 3)) = 4, 'three messages: the day''s four turns, not yesterday''s');
select pg_temp.check((zad_memory_consolidation_due(:u, 3) -> 0 ->> 'text') = 'أخويا أحمد جاي من السفر', 'oldest first');

-- Marked up to the last turn read: the same turns are not reviewed twice.
select zad_memory_mark_consolidated(:u, (select max(created_at) from zad_chat_turns where user_id = :u));
select pg_temp.check(zad_memory_consolidation_due(:u, 3) = '[]'::jsonb, 'after the mark, nothing new to review');
insert into zad_chat_turns (user_id, role, text, created_at) values
  (:u, 'user', 'رسالة جديدة بعد المراجعة', now() - interval '1 minute');
select pg_temp.check(zad_memory_consolidation_due(:u, 1) -> 0 ->> 'text' = 'رسالة جديدة بعد المراجعة', 'only what came after');

-- The mark never moves back, and ignores a time in the future.
select zad_memory_mark_consolidated(:u, now() - interval '10 hours');
select pg_temp.check((select memory_consolidated_at > now() - interval '4 hours' from zad_users where id = :u), 'an earlier mark does not move it back');
select zad_memory_mark_consolidated(:u, now() + interval '1 day');
select pg_temp.check((select memory_consolidated_at < now() from zad_users where id = :u), 'a mark in the future is ignored');

-- Server only: Supabase hands anon and authenticated EXECUTE on every new function.
select pg_temp.check(not has_function_privilege(r, p.oid, 'EXECUTE'), r || ' cannot execute ' || p.proname)
  from pg_proc p cross join unnest(array['anon', 'authenticated']) r
 where p.proname in ('zad_memory_consolidation_due', 'zad_memory_mark_consolidated');
