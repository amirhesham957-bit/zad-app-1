-- التصحيح بيبقى درس (migration 20261025061500, ZAD_PLAN 3.11), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/corrections_lessons_scaffold.sql
--   psql < supabase/migrations/20261019210000_eval_results.sql
--   psql < supabase/migrations/20261025021500_eval_nightly.sql
--   psql < supabase/migrations/20261025061500_corrections_lessons.sql
--   psql < supabase/sql/tests/corrections_lessons_test.sql

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
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set b '''00000000-0000-0000-0000-0000000000b1'''
insert into public.zad_transactions (id, user_id, category, title, merchant_name) values
  ('00000000-0000-0000-0000-00000000c001', :a, 'مطاعم', 'دفع بطاقة 4111222233334444', 'كارفور المعادي'),
  ('00000000-0000-0000-0000-00000000c002', :a, 'أخرى', 'محل ahmed@mail.com', null);
insert into public.zad_insights (id, user_id, status, title) values ('00000000-0000-0000-0000-00000000d001', :a, 'pending', 'الرز هيخلص');
\set QUIET 0

-- The app changes a category: the customer's own JWT, so it is a correction.
set role authenticated;
select pg_temp.who(:a);
update public.zad_transactions set category = 'بقالة' where id = '00000000-0000-0000-0000-00000000c001';
update public.zad_transactions set category = 'محلات' where id = '00000000-0000-0000-0000-00000000c002';
update public.zad_insights set status = 'dismissed', dismiss_reason = 'wrong_data' where id = '00000000-0000-0000-0000-00000000d001';
insert into public.zad_product_pairs (user_id, a_key, b_key, verdict) values (:a, 'لبن جهينة', 'حليب جهينة', 'same');
reset role;
select pg_temp.check((select count(*) from public.zad_corrections where kind = 'category') = 2, 'an app category change is a lesson');
select pg_temp.check((select subject = 'كارفور المعادي' and wrong = 'مطاعم' and right_answer = 'بقالة' from public.zad_corrections where wrong = 'مطاعم'),
  'the merchant is the subject, with the wrong and the right category');
select pg_temp.check((select subject from public.zad_corrections where wrong = 'أخرى') = 'محل', 'an email is redacted out of the subject');
select pg_temp.check(public.zad_redact_lesson('بطاقة ٤١١١٢٢٢٢ و https://x.y/z') = 'بطاقة # و', 'long numbers and links are redacted');
select pg_temp.check((select right_answer = 'wrong_data' and kind = 'alert' from public.zad_corrections where subject = 'الرز هيخلص'), 'a dismissed card is a lesson');
select pg_temp.check((select right_answer = 'same' and wrong = 'different' from public.zad_corrections where kind = 'same_item'), '«the same item» is a lesson');

-- The server recategorising (no JWT) is not a correction; the chat path records one itself.
select set_config('request.jwt.claims', '{"role":"service_role"}', false);
update public.zad_transactions set category = 'أكل' where id = '00000000-0000-0000-0000-00000000c001';
select pg_temp.check((select count(*) from public.zad_corrections where kind = 'category') = 2, 'a server-side change is not a lesson');
select pg_temp.check(public.zad_record_correction(:a, 'category', 'كارفور المعادي', 'أكل', 'بقالة', 'chat'), 'the chat path records one');
select pg_temp.check(not public.zad_record_correction(:a, 'category', 'كارفور', 'بقالة', 'بقالة'), 'the same answer twice is no correction');
select pg_temp.check(not public.zad_record_correction(:a, 'mood', 'x', 'a', 'b'), 'an unknown kind is refused');

-- Tonight's lessons: the newest per subject, none recorded after the night began.
select pg_temp.check((select count(*) from public.zad_eval_lesson_cases(now() + interval '1 second', 30)) = 2, 'one lesson per subject');
select pg_temp.check((select right_answer from public.zad_eval_lesson_cases(now() + interval '1 second', 30) where subject = 'كارفور المعادي') = 'بقالة', 'the newest answer wins');
select pg_temp.check((select count(*) from public.zad_eval_lesson_cases(now() - interval '1 hour', 30)) = 0, 'lessons after the night began wait for tomorrow');

-- Lessons are measured apart from green/red.
insert into public.zad_eval_nights (day, run_id, next_offset, total, finished_at) values ('2026-10-10', '00000000-0000-0000-0000-0000000e0001', null, 2, now());
insert into public.zad_eval_results (run_id, case_id, category, pass) values
  ('00000000-0000-0000-0000-0000000e0001', 'log_coffee', 'log', true),
  ('00000000-0000-0000-0000-0000000e0001', 'q_balance', 'question', true),
  ('00000000-0000-0000-0000-0000000e0001', 'lesson_1', 'lesson', false),
  ('00000000-0000-0000-0000-0000000e0001', 'lesson_2', 'lesson', false);
select pg_temp.check((public.zad_eval_verdict('2026-10-10') ->> 'green')::boolean, 'failing lessons do not turn the night red');
select pg_temp.check((public.zad_eval_verdict('2026-10-10') ->> 'lessons_ran')::int = 2 and (public.zad_eval_verdict('2026-10-10') ->> 'ran')::int = 2,
  'and are counted on their own');
select pg_temp.check(not has_table_privilege('authenticated', 'public.zad_corrections', 'select'), 'customers cannot read the lessons');
