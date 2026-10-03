-- Memory with entities and time (migration 20261003100000, docs/agent/ZAD_LIVING_BRAIN.md
-- slice 1), on a scratch database — see memory_scaffold.sql for the order to run in.
-- U (a1) owns the notes, O (f1) is another account. Raises on the first failed check;
-- every passing one prints "ok:".

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

insert into auth.users values ('00000000-0000-0000-0000-0000000000f1') on conflict do nothing;
\set u1 '''00000000-0000-0000-0000-0000000000a1'''
\set u2 '''00000000-0000-0000-0000-0000000000f1'''
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond,false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

-- 1. insert temp, refuse expired
select pg_temp.check(zad_memory_upsert(:u1, 'general', 'أخويا أحمد قاعد عندنا في البيت', 0.6, null, now() + interval '3 days') = 'inserted', 'temp fact inserted');
select pg_temp.check(zad_memory_upsert(:u1, 'general', 'كان عندنا ضيوف الأسبوع اللي فات', 0.6, null, now() - interval '1 day') = 'expired', 'past valid_until refused');
select pg_temp.check(not exists (select 1 from zad_memory where note like 'كان عندنا ضيوف%'), 'expired not written');
-- 2. strengthen keeps the known expiry
select pg_temp.check(zad_memory_upsert(:u1, 'general', 'أخويا أحمد قاعد عندنا في البيت', 0.6) = 'strengthened', 'repeat strengthens');
select pg_temp.check((select valid_until > now() + interval '2 days' from zad_memory where note = 'أخويا أحمد قاعد عندنا في البيت'), 'expiry kept on undated repeat');
-- 3. conflict then resolve: old closed, new inherits entities
select pg_temp.check(zad_memory_upsert(:u1, 'general', 'بيحب يشرب القهوة كل يوم الصبح', 0.7) = 'inserted', 'coffee inserted');
select pg_temp.check(zad_memory_attach_entities(:u1, (select id from zad_memory where note = 'بيحب يشرب القهوة كل يوم الصبح'),
  '[{"kind":"item","name":"قهوة","key":"قهوه"},{"kind":"person","name":"ماما","key":"ماما"},{"kind":"bogus","name":"x","key":"x"},{"kind":"place","name":"البيت","key":"البيت"}]'::jsonb) = 2, 'attach: bad kind skipped, only first 3 elements read');
select pg_temp.check(zad_memory_upsert(:u1, 'general', 'مش بيحب يشرب القهوة كل يوم الصبح', 0.7) = 'conflict', 'negation is conflict');
select pg_temp.check((zad_memory_conflict(:u1, 'general', 'مش بيحب يشرب القهوة كل يوم الصبح') ->> 'note') = 'بيحب يشرب القهوة كل يوم الصبح', 'conflict finds the live note');
select pg_temp.check((zad_memory_resolve_conflict(:u1, (select id from zad_memory where note = 'بيحب يشرب القهوة كل يوم الصبح'), 'general', 'مش بيحب يشرب القهوة كل يوم الصبح', 0.6) ->> 'ok')::boolean, 'resolve ok');
select pg_temp.check((select superseded_by = (select id from zad_memory where note = 'مش بيحب يشرب القهوة كل يوم الصبح') and valid_until <= now() from zad_memory where note = 'بيحب يشرب القهوة كل يوم الصبح'), 'old closed and points at new');
select pg_temp.check((select count(*) from zad_memory_mentions where memory_id = (select id from zad_memory where note = 'مش بيحب يشرب القهوة كل يوم الصبح')) = 2, 'new inherits the old note entities');
select pg_temp.check(exists (select 1 from zad_memory_links where relation = 'contradicts'), 'contradicts link kept');
-- 4. the closed note is history: conflict ignores it, re-saying it inserts a fresh row
select pg_temp.check(zad_memory_conflict(:u1, 'general', 'بيحب يشرب القهوة كل يوم الصبح') ->> 'note' = 'مش بيحب يشرب القهوة كل يوم الصبح', 'conflict is against the live one only');
select pg_temp.check(zad_memory_upsert(:u1, 'general', 'بيحب يشرب القهوة كل يوم الصبح', 0.6) = 'conflict', 'saying the closed belief again is a conflict with the live one, not a revival');
-- 5. live_notes: superseded and expired out, about in
update zad_memory set valid_from = now() - interval '10 days', valid_until = now() - interval '1 day' where note = 'أخويا أحمد قاعد عندنا في البيت';
select pg_temp.check((select count(*) from zad_memory_live_notes(:u1, 20)) = 2, 'live = backfilled old + new coffee note');
select pg_temp.check((select valid_from::date = created_at::date from zad_memory where note = 'ملاحظة قديمة من الشهر اللي فات'), 'old rows start when they were written');
select pg_temp.check((select about from zad_memory_live_notes(:u1, 20) where note like 'مش بيحب%') @> array['ماما','قهوة'] and (select cardinality(about) from zad_memory_live_notes(:u1, 20) where note like 'مش بيحب%') = 2, 'about carries entity names');
-- 6. recall by entity name, whole word only
select pg_temp.check((select count(*) from zad_memory_recall_entities(:u1, 'هي ماما عامله ايه', 8)) = 1, 'recall by person name');
select pg_temp.check((select count(*) from zad_memory_recall_entities(:u1, 'ماماتهم عاملين ايه', 8)) = 0, 'no partial-word match');
select pg_temp.check((select count(*) from zad_memory_recall_entities(:u1, 'وقهوه | قهوه', 8)) = 1, 'stripped-prefix variant matches');
-- 7. ownership: another user's note cannot be attached
insert into zad_memory(user_id, note) values (:u2, 'ملاحظة بتاعة عميل تاني خالص');
select pg_temp.check(zad_memory_attach_entities(:u1, (select id from zad_memory where user_id = :u2), '[{"kind":"person","name":"ماما","key":"ماما"}]') = 0, 'foreign note refused');
select pg_temp.check((select count(*) from zad_memory_entities where user_id = :u1 and kind = 'person') = 1, 'entity deduped by key');
-- 8. find_contradictions ignores closed notes
select pg_temp.check(not exists (select 1 from zad_memory_find_contradictions(:u1)), 'no contradiction reported against history');
-- 9. prune drops history first
insert into zad_memory(user_id, note, confidence, evidence_count) select :u2, 'ملاحظة رقم ' || g, 0.9, 5 from generate_series(1, 58) g;
insert into zad_memory(user_id, note, confidence, evidence_count, valid_from, valid_until) values (:u2, 'حقيقة قوية بس انتهت', 1.0, 9, now() - interval '5 days', now() - interval '1 day');
insert into zad_memory(user_id, note, confidence, evidence_count) values (:u2, 'ملاحظة ضعيفة بس لسه حية', 0.1, 1);
select zad_memory_prune();
select pg_temp.check((select count(*) from zad_memory where user_id = :u2) = 60, 'prune keeps 60');
select pg_temp.check(not exists (select 1 from zad_memory where note = 'حقيقة قوية بس انتهت'), 'expired strong note pruned before a weak live one');
select pg_temp.check(exists (select 1 from zad_memory where note = 'ملاحظة ضعيفة بس لسه حية'), 'weak live note kept');
-- 10. RLS and grants
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', false);
select pg_temp.check((select count(*) from zad_memory_entities) = 0, 'another user sees none of my entities');
select pg_temp.check((select count(*) from zad_memory_live_notes('00000000-0000-0000-0000-0000000000a1', 20)) = 0, 'live_notes refuses another user');
do $$ begin
  insert into zad_memory_entities(user_id, kind, name, name_key) values ('00000000-0000-0000-0000-0000000000f1', 'person', 'x', 'x');
  raise exception 'FAIL: client wrote an entity';
exception when insufficient_privilege then raise notice 'ok: client cannot write entities'; end $$;
do $$ begin
  perform zad_memory_attach_entities('00000000-0000-0000-0000-0000000000f1', gen_random_uuid(), '[]');
  raise exception 'FAIL: client called attach';
exception when insufficient_privilege then raise notice 'ok: attach is server-only'; end $$;
do $$ begin
  perform zad_memory_upsert('00000000-0000-0000-0000-0000000000a1', 'general', 'محاولة كتابة باسم حد تاني');
  raise exception 'FAIL: upsert for another user';
exception when raise_exception then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'ok: upsert refuses another user';
end $$;
select pg_temp.check(zad_memory_upsert('00000000-0000-0000-0000-0000000000f1', 'general', 'العميل التاني بيحب الشاي بالنعناع', 0.5) = 'inserted', 'client upsert for self with 4 named-style args still resolves');
reset role;
set role anon;
do $$ begin
  perform zad_memory_upsert('00000000-0000-0000-0000-0000000000f1', 'general', 'anon محاولة');
  raise exception 'FAIL: anon upsert';
exception when insufficient_privilege then raise notice 'ok: anon cannot upsert'; end $$;
reset role;
select pg_temp.check((select count(*) from pg_proc where proname = 'zad_memory_upsert') = 1, 'exactly one upsert overload');
-- Supabase's default privileges hand anon EXECUTE on every new function; the
-- ones that pass a null auth.uid() through must have taken it back.
select pg_temp.check(not has_function_privilege('anon', p.oid, 'EXECUTE'), 'anon cannot execute ' || p.proname)
  from pg_proc p where p.proname in ('zad_memory_upsert', 'zad_memory_attach_entities', 'zad_memory_live_notes', 'zad_memory_recall_entities');
select pg_temp.check(not has_table_privilege('authenticated', 'public.zad_memory_entities', 'INSERT,UPDATE,DELETE,TRUNCATE'), 'client cannot change entities in any way');
select pg_temp.check(not has_table_privilege('anon', 'public.zad_memory_mentions', 'SELECT'), 'anon cannot read mentions');
