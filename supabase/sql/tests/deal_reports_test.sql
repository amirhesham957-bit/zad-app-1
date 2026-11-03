-- «العرض ده غلط» (migration 20261103170000, ZAD_PLAN 4.19), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/deals_scaffold.sql
--   psql < supabase/sql/tests/deal_reports_scaffold.sql
--   psql < supabase/migrations/20261025234500_deals.sql
--   psql < supabase/migrations/20261026183500_deal_buttons.sql
--   psql < supabase/migrations/20261103170000_deal_reports.sql
--   psql < supabase/sql/tests/deal_reports_test.sql
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
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set b '''00000000-0000-0000-0000-0000000000b1'''
\set c '''00000000-0000-0000-0000-0000000000c1'''
\set ma '''00000000-0000-0000-0000-00000000e001'''
\set mb '''00000000-0000-0000-0000-00000000e002'''
\set mc '''00000000-0000-0000-0000-00000000e003'''
\set ml '''00000000-0000-0000-0000-00000000e004'''
insert into auth.users (id) values (:a), (:b), (:c) on conflict do nothing;
insert into public.zad_deals (id, country, store, item_name, price, price_before, currency, source_kind, source_url, confidence, expires_at)
values ('00000000-0000-0000-0000-0000000d0001', 'SA', 'كيو', 'زيت عافية 1.5 لتر', 22, 29, 'SAR', 'search', 'https://q.example/offers', 0.5, now() + interval '3 days'),
       ('00000000-0000-0000-0000-0000000d0002', 'SA', 'بنده', 'رز بسمتي', 40, null, 'SAR', 'youtube', 'https://www.youtube.com/watch?v=abc123', 0.5, now() + interval '3 days');
insert into public.zad_voice_moments (id, user_id, moment, facts) values
  (:ma, :a, 'morning_greeting', '{"taste_deal": {"item": "زيت عافية 1.5 لتر", "store": "كيو", "price": 22, "key": "deal:زيت:كيو", "source": {"kind": "search", "url": "https://q.example/offers", "until": null}}}'),
  (:mb, :b, 'morning_greeting', '{"taste_deal": {"item": "زيت عافيه 1.5 لتر", "store": "كيو", "price": 22, "key": "deal:زيت:كيو", "source": {"kind": "search", "url": "https://q.example/offers", "until": null}}}'),
  (:mc, :c, 'morning_greeting', '{"taste_deal": {"item": "رز بسمتي", "store": "بنده", "price": 40, "key": "deal:رز:بنده", "source": {"kind": "youtube", "url": "https://www.youtube.com/watch?v=abc123", "until": null}}}'),
  (:ml, :c, 'morning_greeting', '{"taste_deal": {"item": "شاي", "store": "العثيم", "price": 9, "key": "deal:شاي:العثيم"}}');

-- 1. One home's report is kept against the stored row, and the deal stays up.
select pg_temp.check((public.zad_deal_report_service(:a, :ma) ->> 'answer') = 'wrong', 'the report is recorded');
select pg_temp.check((select facts -> 'taste_deal' ->> 'answer' = 'wrong' from public.zad_voice_moments where id = :ma), 'the answer is on the moment');
select pg_temp.check((select deal_id = '00000000-0000-0000-0000-0000000d0001' from public.zad_deal_reports where user_id = :a), 'the report points at the stored row');
select pg_temp.check(exists (select 1 from public.zad_deals where id = '00000000-0000-0000-0000-0000000d0001'), 'one home does not take it down');

-- 2. A second tap is already answered, and the same home cannot count twice.
select pg_temp.check((public.zad_deal_report_service(:a, :ma) ->> 'already')::boolean, 'a second tap is already answered');
select pg_temp.check((select count(*) from public.zad_deal_reports where user_id = :a) = 1, 'one report per greeting');

-- 3. A second home (name spelled «عافيه») takes the deal down.
select pg_temp.check((public.zad_deal_report_service(:b, :mb) ->> 'removed')::boolean, 'two homes remove the deal');
select pg_temp.check(not exists (select 1 from public.zad_deals where id = '00000000-0000-0000-0000-0000000d0001'), 'the row is gone');
select pg_temp.check((select count(*) from public.zad_deal_reports where deal_id is null) = 2, 'the reports stay, unlinked');

-- 4. Another deal is untouched; a live-search deal (no source) is only counted.
select pg_temp.check(not (public.zad_deal_report_service(:c, :ml) ->> 'removed')::boolean, 'a live deal removes nothing');
select pg_temp.check((select deal_id is null and source_kind is null from public.zad_deal_reports where moment_id = :ml), 'a live deal links to no row');
select pg_temp.check(exists (select 1 from public.zad_deals where id = '00000000-0000-0000-0000-0000000d0002'), 'the other deal stays');

-- 5. An answered «ضيفه» cannot become a report, and another account cannot report someone's moment.
select pg_temp.check((public.zad_deal_answer_service(:c, :mc, true) ->> 'answer') = 'add', 'add first');
select pg_temp.check((public.zad_deal_report_service(:c, :mc) ->> 'answer') = 'add', 'a report after add changes nothing');
select pg_temp.check((public.zad_deal_report_service(:a, :mc) ->> 'reason') = 'not_found', 'ownership comes from the moment');

-- 6. The measure counts per source.
select pg_temp.check((select shown = 2 and wrong = 2 from public.zad_deal_accuracy(7) where source_kind = 'search'), 'search: 2 shown, 2 wrong');
select pg_temp.check((select shown = 1 and wrong = 0 from public.zad_deal_accuracy(7) where source_kind = 'youtube'), 'youtube: 1 shown, 0 wrong');
select pg_temp.check((select wrong = 1 from public.zad_deal_accuracy(7) where source_kind = 'live'), 'live: 1 wrong');

-- 7. Customers cannot call either door nor read the reports.
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_deal_report_service(uuid, uuid)', 'execute'), 'customers cannot report through the bot''s door');
select pg_temp.check(not has_function_privilege('authenticated', 'public.zad_deal_accuracy(int)', 'execute'), 'customers cannot read the measure');
select pg_temp.check(not has_table_privilege('authenticated', 'public.zad_deal_reports', 'select'), 'customers cannot read the reports');
