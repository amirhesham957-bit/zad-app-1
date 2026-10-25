-- زاد بيتعلم صيغ البنوك من العملاء (migration 20261025213500, ZAD_PLAN 2.3/3.10), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/bank_formats_scaffold.sql
--   psql < supabase/migrations/20261025213500_bank_formats_learned.sql
--   psql < supabase/sql/tests/bank_formats_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;

-- Three customers in Saudi Arabia, the same Al Rajhi shape with different amounts, shops and dates.
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2'), ('00000000-0000-0000-0000-0000000000a3');
insert into public.zad_users (id, country) values ('00000000-0000-0000-0000-0000000000a1', 'SA'), ('00000000-0000-0000-0000-0000000000a2', 'SA'), ('00000000-0000-0000-0000-0000000000a3', 'SA');
insert into public.zad_notification_ingest_events (id, user_id, package_name, title, body) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1', 'com.google.android.apps.messaging', 'AlRajhiBank', 'شراء عبر نقاط البيع بطاقة: [بطاقة] مبلغ: 45.50 SAR لدى: Panda في: 2026-10-20 18:40'),
  ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000a2', 'com.google.android.apps.messaging', 'AlRajhiBank', 'شراء عبر نقاط البيع بطاقة: [بطاقة] مبلغ: ١٢٠ SAR لدى: Qeu في: 2026-10-21 09:05'),
  ('00000000-0000-0000-0000-0000000000e3', '00000000-0000-0000-0000-0000000000a3', 'com.google.android.apps.messaging', 'AlRajhiBank', 'شراء عبر نقاط البيع بطاقة: [بطاقة] مبلغ: 9.75 SAR لدى: Othaim في: 2026-10-22 21:13');
insert into public.zad_transaction_proposals (id, user_id, source_event_id, source_type, status, txn_kind, bank_name, merchant_name) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1', 'notification_listener', 'awaiting_confirmation', 'expense', 'AlRajhiBank', 'Panda'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000e2', 'notification_listener', 'awaiting_confirmation', 'expense', 'AlRajhiBank', 'Qeu'),
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000e3', 'notification_listener', 'awaiting_confirmation', 'expense', 'AlRajhiBank', 'Othaim');
\set QUIET 0

select pg_temp.check(public.zad_bank_template('تم خصم ٤٥٠ جنيه لدى Carrefour في 20/10', 'Carrefour') = 'تم خصم {n} جنيه لدى {party} في {n}',
  'the shape keeps the words and drops every number and the other party');
select pg_temp.check(public.zad_bank_template('استلمت 75.00 ريال من خالد (أ.ب)', 'خالد (أ.ب)') = 'استلمت {n} ريال من {party}',
  'a party name with regex characters is replaced literally');

select pg_temp.check(public.zad_bank_template('انستاباي لقد استلمت 500 جنيه من ahmed.h99@instapay', null) = 'انستاباي لقد استلمت {n} جنيه من {party}',
  'an InstaPay address is a person, not part of the shape');
select pg_temp.check(public.zad_bank_sender('com.google.android.apps.messaging', 'BDC', 'com.google.android.apps.messaging') = 'bdc',
  'a bank read through the messaging app is named by its sender, not the package');
select pg_temp.check(public.zad_bank_sender('Al Rajhi', 'AlRajhiBank', 'x') = 'al rajhi', 'a real bank name wins');
select pg_temp.check(not public.zad_bank_learnable('org.thunderdog.challegram', 'EA CoinTalk عاجل'), 'a Telegram channel is not a bank');
select pg_temp.check(not public.zad_bank_learnable('com.google.android.apps.messaging', 'ZadSmartBot (2) إشعار بنكي'), 'Zad''s own bot is not a bank');

update public.zad_transaction_proposals set status = 'posted' where id = '00000000-0000-0000-0000-0000000000b1';
select pg_temp.check((select count(*) from public.zad_bank_formats) = 1, 'a confirmed bank proposal records its shape');
select pg_temp.check((select template from public.zad_bank_formats) = 'alrajhibank شراء عبر نقاط البيع بطاقة: [بطاقة] مبلغ: {n} sar لدى: {party} في: {n} {n}'
  or (select template from public.zad_bank_formats) like '%مبلغ: {n} SAR لدى: {party} في: {n} {n}', 'no amount, shop or date is kept');
select pg_temp.check((select template from public.zad_bank_formats) !~ '[0-9]' and (select template from public.zad_bank_formats) !~* 'panda',
  'not a digit and not the shop name in what is stored');
select pg_temp.check((select sender = 'alrajhibank' and market = 'SA' from public.zad_bank_formats), 'the sender and the market are kept');

-- A Telegram message the customer confirmed teaches nothing.
insert into public.zad_notification_ingest_events (id, user_id, package_name, title, body) values
  ('00000000-0000-0000-0000-0000000000e9', '00000000-0000-0000-0000-0000000000a1', 'org.telegram.messenger', 'EA Funded', 'خبر عاجل: الذهب 2400');
insert into public.zad_transaction_proposals (id, user_id, source_event_id, source_type, status, txn_kind) values
  ('00000000-0000-0000-0000-0000000000b9', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e9', 'notification_listener', 'awaiting_confirmation', 'expense');
update public.zad_transaction_proposals set status = 'posted' where id = '00000000-0000-0000-0000-0000000000b9';
select pg_temp.check((select count(*) from public.zad_bank_formats) = 1, 'a chat app''s message is not learned from');

update public.zad_transaction_proposals set status = 'merged' where id = '00000000-0000-0000-0000-0000000000b2';
update public.zad_transaction_proposals set status = 'posted' where id = '00000000-0000-0000-0000-0000000000b3';
select pg_temp.check((select count(*) from public.zad_bank_formats) = 1, 'three customers, three shops, three amounts: one shape');
select pg_temp.check((select users = 3 and money = 3 and top_kind = 'expense' and agreed from public.zad_bank_formats_learned()),
  'three different customers agreeing make it a learned bank shape');
select pg_temp.check((select not agreed from public.zad_bank_formats_learned(4)), 'below the bar it is not learned');

-- One customer changes their mind: their vote is replaced, not added.
update public.zad_transaction_proposals set status = 'rejected' where id = '00000000-0000-0000-0000-0000000000b3';
select pg_temp.check((select users = 3 and money = 2 and not_money = 1 and not agreed from public.zad_bank_formats_learned()),
  'the last answer wins, and 2 of 3 is not agreement');

-- A proposal that is not from a notification, or a bad row, never blocks the confirmation.
insert into public.zad_transaction_proposals (id, user_id, source_event_id, source_type, status) values
  ('00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-0000000000a1', null, 'notification_listener', 'awaiting_confirmation');
update public.zad_transaction_proposals set status = 'posted' where id = '00000000-0000-0000-0000-0000000000b4';
select pg_temp.check((select status from public.zad_transaction_proposals where id = '00000000-0000-0000-0000-0000000000b4') = 'posted',
  'a proposal with no event is confirmed as usual');

-- Deleting an account takes its votes with it.
delete from auth.users where id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.check((select users from public.zad_bank_formats_learned()) = 2, 'a deleted account''s votes are gone');

\echo 'bank_formats: all checks passed'
