-- ZAD_OR_PLAN م٢.١: «أنا» لكل حساب، والحدث بفرد من نفس البيت، ومايتعدلش، ومايتكتبش من الموبايل، ويمشي مع حسابه.
\set ON_ERROR_STOP on
create or replace function pg_temp.check(cond boolean, what text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAILED: %', what; end if; end $$;
create or replace function pg_temp.fails(q text, what text) returns void language plpgsql as $$
begin
  begin execute q; exception when others then return; end;
  raise exception 'FAILED (should have been refused): %', what;
end $$;

-- ١) الحسابات الموجودة خدت «أنا»، باسمها أو «أنا».
select pg_temp.check((select display_name from zad_household_members where user_id = '11111111-1111-1111-1111-111111111111' and kind = 'self') = 'أمير', 'existing account got its self row with its name');
select pg_temp.check((select display_name from zad_household_members where user_id = '22222222-2222-2222-2222-222222222222' and kind = 'self') = 'أنا', 'nameless account is «أنا»');
-- حساب جديد بياخده من التريجر، ومرة واحدة بس.
insert into auth.users values ('33333333-3333-3333-3333-333333333333');
insert into zad_users values ('33333333-3333-3333-3333-333333333333', 'سارة');
select pg_temp.check((select count(*) from zad_household_members where user_id = '33333333-3333-3333-3333-333333333333') = 1, 'new account: one self row');
select pg_temp.check(zad_self_member('33333333-3333-3333-3333-333333333333') = (select id from zad_household_members where user_id = '33333333-3333-3333-3333-333333333333'), 'zad_self_member is idempotent');
select pg_temp.fails($$insert into zad_household_members (user_id, display_name, kind) values ('33333333-3333-3333-3333-333333333333', 'تاني', 'self')$$, 'second self row');
-- اسم أطول من ٦٠ مايوقّعش تسجيل الحساب.
insert into auth.users values ('44444444-4444-4444-4444-444444444444');
insert into zad_users values ('44444444-4444-4444-4444-444444444444', repeat('ا', 80));
select pg_temp.check((select length(display_name) from zad_household_members where user_id = '44444444-4444-4444-4444-444444444444') = 60, 'long name trimmed, signup not broken');

-- ٢) حدث بفرد من نفس البيت: ماشي. بفرد من بيت تاني: مرفوض.
insert into zad_events (user_id, member_id, client_event_id, kind, payload, occurred_at, source, confidence)
values ('11111111-1111-1111-1111-111111111111', zad_self_member('11111111-1111-1111-1111-111111111111'), 'c-1', 'expense.logged', '{"amount":50}', now(), 'manual', 1);
select pg_temp.fails($$insert into zad_events (user_id, member_id, client_event_id, kind, occurred_at, source)
  values ('11111111-1111-1111-1111-111111111111', zad_self_member('22222222-2222-2222-2222-222222222222'), 'c-x', 'expense.logged', now(), 'manual')$$, 'member from another household');
select pg_temp.fails($$insert into zad_events (user_id, member_id, client_event_id, kind, occurred_at, source)
  values ('11111111-1111-1111-1111-111111111111', zad_self_member('11111111-1111-1111-1111-111111111111'), 'c-1', 'expense.logged', now(), 'manual')$$, 'same client_event_id twice');
select pg_temp.fails($$insert into zad_events (user_id, member_id, client_event_id, kind, occurred_at, source)
  values ('11111111-1111-1111-1111-111111111111', zad_self_member('11111111-1111-1111-1111-111111111111'), 'c-2', 'Expense Logged!', now(), 'manual')$$, 'kind is a dotted slug');
select pg_temp.fails($$insert into zad_events (user_id, member_id, client_event_id, kind, occurred_at, source)
  values ('11111111-1111-1111-1111-111111111111', zad_self_member('11111111-1111-1111-1111-111111111111'), 'c-3', 'expense.logged', now(), 'hearsay')$$, 'source from the list');

-- ٣) مايتعدلش ومايتمسحش.
select pg_temp.fails($$update zad_events set payload = '{"amount":5000}' where client_event_id = 'c-1'$$, 'update refused');
select pg_temp.fails($$delete from zad_events where client_event_id = 'c-1'$$, 'delete refused');
select pg_temp.check((select payload ->> 'amount' from zad_events where client_event_id = 'c-1') = '50', 'event unchanged');

-- ٤) الموبايل (authenticated): بيقرا بتاعه بس، ومابيكتبش.
grant select on zad_events, zad_household_members to authenticated;
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
select pg_temp.check((select count(*) from zad_events) = 0, 'another account sees none of my events');
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
select pg_temp.check((select count(*) from zad_events) = 1, 'I see my event');
select pg_temp.fails($$insert into zad_events (user_id, member_id, client_event_id, kind, occurred_at, source)
  values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'c-9', 'expense.logged', now(), 'manual')$$, 'client insert refused');
select pg_temp.fails($$insert into zad_household_members (user_id, display_name, kind) values ('11111111-1111-1111-1111-111111111111', 'ابني', 'child')$$, 'client member insert refused');
select pg_temp.fails($$select zad_self_member('11111111-1111-1111-1111-111111111111')$$, 'client cannot call zad_self_member');
reset role;

-- ٥) الحساب لما يتمسح: أفراده وأحداثه بيمشوا معاه من غير ما الحارس يوقف المسح.
delete from auth.users where id = '11111111-1111-1111-1111-111111111111';
select pg_temp.check(not exists (select 1 from zad_events where user_id = '11111111-1111-1111-1111-111111111111'), 'events left with the account');
select pg_temp.check(not exists (select 1 from zad_household_members where user_id = '11111111-1111-1111-1111-111111111111'), 'members left with the account');

select 'events_ledger: all checks passed';
