-- The memory heals itself (migration 20261113050000, ZAD_PLAN 10.2b), on a scratch database. Needs pgvector,
-- like memory_time_entities_test.sql — not in CI's plain postgres:
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg pgvector/pgvector:pg17
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/memory_scaffold.sql
--   psql < supabase/migrations/20261003100000_memory_entities_and_time.sql
--   psql < supabase/migrations/20261113050000_memory_heals.sql
--   psql < supabase/sql/tests/memory_heals_test.sql
--
-- U (a1) owns the notes, O (f1) is another account. Raises on the first failed check.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000f1')
  on conflict do nothing;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

-- The five shapes measured on the live project 13/11: two reworded repeats, two different facts, one other account.
insert into public.zad_memory (id, user_id, scope, note, confidence, evidence_count, created_at) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'general',
   'العميل يلتزم بسداد قسط شهري للسيارة بقيمة 3000 ريال.', 0.6, 2, now() - interval '10 days'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1', 'general',
   'العميل لديه التزام مالي شهري ثابت بقيمة 3000 ريال خاص بقسط السيارة.', 0.5, 1, now() - interval '5 days'),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a1', 'general',
   'عيد ميلاد العميل: 19 يوليو', 0.7, 1, now() - interval '9 days'),
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a1', 'general',
   'عيد ميلاد ابني: 19 أغسطس', 0.7, 1, now() - interval '4 days'),
  ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-0000000000a1', 'general',
   'القبض يوم 25 من كل شهر', 0.6, 1, now() - interval '8 days'),
  ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-0000000000a1', 'general',
   'القبض بقى يوم 1 من كل شهر', 0.6, 1, now() - interval '1 day'),
  ('10000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-0000000000f1', 'general',
   'العميل يلتزم بسداد قسط شهري للسيارة بقيمة 3000 ريال.', 0.6, 1, now() - interval '3 days');

-- 1. Candidates: the account's own pairs, older first, nothing of the other account's.
create temp table c as select * from zad_memory_review_candidates('00000000-0000-0000-0000-0000000000a1');
select pg_temp.check((select count(*) from c) >= 1, 'similar notes in one scope are candidates');
select pg_temp.check(exists (select 1 from c where older_id = '10000000-0000-0000-0000-000000000001'
                                             and newer_id = '10000000-0000-0000-0000-000000000002'),
  'the reworded repeat is a candidate, older first');
select pg_temp.check(not exists (select 1 from c where older_id = '10000000-0000-0000-0000-000000000009'
                                                  or newer_id = '10000000-0000-0000-0000-000000000009'),
  'another account''s note is never a candidate');

-- 2. same: the older merges into the newer — evidence adds up, the higher confidence stays, nothing is deleted.
select pg_temp.check((zad_memory_heal('00000000-0000-0000-0000-0000000000a1',
  '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'same') ->> 'ok') = 'true', 'same applies');
select pg_temp.check((select superseded_by from zad_memory where id = '10000000-0000-0000-0000-000000000001')
  = '10000000-0000-0000-0000-000000000002', 'the older repeat now points at the newer');
select pg_temp.check((select evidence_count from zad_memory where id = '10000000-0000-0000-0000-000000000002') = 3,
  'evidence adds up (2 + 1)');
select pg_temp.check((select confidence from zad_memory where id = '10000000-0000-0000-0000-000000000002') = 0.6::real,
  'the higher confidence stays');
select pg_temp.check((select count(*) from zad_memory where user_id = '00000000-0000-0000-0000-0000000000a1'
  and id::text like '10000000-%') = 6,
  'nothing is deleted');

-- 3. update: the older becomes history with a contradicts link.
select zad_memory_heal('00000000-0000-0000-0000-0000000000a1',
  '10000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000006', 'update');
select pg_temp.check((select superseded_by from zad_memory where id = '10000000-0000-0000-0000-000000000005')
  = '10000000-0000-0000-0000-000000000006', 'the old pay day is history');
select pg_temp.check((select confidence from zad_memory where id = '10000000-0000-0000-0000-000000000005') < 0.6::real,
  'history loses confidence');
select pg_temp.check(exists (select 1 from zad_memory_links where relation = 'contradicts'
  and from_id = '10000000-0000-0000-0000-000000000006' and to_id = '10000000-0000-0000-0000-000000000005'),
  'an update keeps a contradicts link');

-- 4. distinct: both stay live, and the pair is not asked about again.
select zad_memory_heal('00000000-0000-0000-0000-0000000000a1',
  '10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000004', 'distinct');
select pg_temp.check((select count(*) from zad_memory where id in ('10000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000004') and superseded_by is null) = 2, 'different facts both stay');
select pg_temp.check(not exists (select 1 from zad_memory_review_candidates('00000000-0000-0000-0000-0000000000a1', 8, 0)
  where older_id = '10000000-0000-0000-0000-000000000003' and newer_id = '10000000-0000-0000-0000-000000000004'),
  'a reviewed pair is not a candidate again');

-- 5. Once a week: a review in the last 7 days means no candidates at all.
select pg_temp.check((select count(*) from zad_memory_review_candidates('00000000-0000-0000-0000-0000000000a1')) = 0,
  'one review a week per account');

-- 6. Refusals: another account's note, a bad verdict, two scopes, a note already superseded.
select pg_temp.check((zad_memory_heal('00000000-0000-0000-0000-0000000000a1',
  '10000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000004', 'same') ->> 'reason') = 'unknown_note',
  'another account''s note cannot be merged');
select pg_temp.check((select superseded_by from zad_memory where id = '10000000-0000-0000-0000-000000000009') is null,
  'and it is untouched');
select pg_temp.check((zad_memory_heal('00000000-0000-0000-0000-0000000000a1',
  '10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000004', 'delete') ->> 'reason') = 'bad_verdict',
  'an unknown verdict is refused');
select pg_temp.check((zad_memory_heal('00000000-0000-0000-0000-0000000000a1',
  '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000004', 'same') ->> 'reason') = 'unknown_note',
  'a note already merged is not merged again');
update zad_memory set scope = 'dismissal' where id = '10000000-0000-0000-0000-000000000003';
select pg_temp.check((zad_memory_heal('00000000-0000-0000-0000-0000000000a1',
  '10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000004', 'same') ->> 'reason') = 'different_scope',
  'two scopes are never merged');

-- 7. The customer cannot call either function or read the reviews.
set role authenticated;
do $$ begin
  perform zad_memory_heal('00000000-0000-0000-0000-0000000000a1',
    '10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000004', 'same');
  raise exception 'FAIL: a customer could call zad_memory_heal';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  perform 1 from public.zad_memory_reviews;
  raise exception 'FAIL: a customer could read zad_memory_reviews';
exception when insufficient_privilege then null;
end $$;
reset role;
select pg_temp.check(true, 'the customer can call neither function nor read the reviews');
