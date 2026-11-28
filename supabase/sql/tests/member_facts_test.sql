-- P2.3 (migration 20261128130000), on a scratch database:
--
--   psql < supabase/sql/tests/events_ledger_scaffold.sql
--   psql < supabase/migrations/20261121160000_events_ledger.sql
--   psql < supabase/migrations/20261128120000_household_traits.sql
--   psql < supabase/migrations/20261128130000_member_facts.sql
--   psql < supabase/sql/tests/member_facts_test.sql
--
-- zad_intent_profile is called directly (the door's own dispatch needs every earlier domain migration). Raises on the first failed check.

\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
grant select on public.zad_household_members to authenticated;
grant select on public.zad_member_facts to authenticated;
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
create or replace function pg_temp.who(p uuid) returns void language plpgsql as $$
begin reset role; perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, false); set role authenticated; end $$;
create or replace function pg_temp.fails(q text) returns boolean language plpgsql as $$
begin execute q; return false; exception when others then return true; end $$;
grant execute on function pg_temp.who(uuid) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
grant execute on function pg_temp.fails(text) to authenticated;
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set b '''00000000-0000-0000-0000-0000000000b1'''
\set ma '''00000000-0000-0000-0000-00000000aa01'''
\set mb '''00000000-0000-0000-0000-00000000bb01'''

insert into auth.users values (:a), (:b);
insert into public.zad_household_members (id, user_id, display_name, kind) values
  (:ma, :a, 'أنا', 'self'), (:mb, :b, 'بابا', 'self');
\set QUIET 0

-- ── set ──
reset role;
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'allergy', 'value', 'فول سوداني', 'source', 'said'), now()) ->> 'ok')::boolean,
  'owner sets a fact through the door');
select pg_temp.check((select count(*) from public.zad_member_facts where member_id = :ma and key = 'allergy' and expires_at is null and confidence = 1 and source = 'said') = 1,
  'said fact defaults to confidence 1');
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'allergy', 'value', 'لبن', 'source', 'observed', 'confidence', 0.9), now()) ->> 'ok')::boolean,
  'setting the same key again works');
select pg_temp.check((select count(*) from public.zad_member_facts where member_id = :ma and key = 'allergy') = 1, 'set again replaces, no duplicate');
select pg_temp.check((select value = 'لبن' and source = 'observed' and confidence = 0.9 and updated_at >= created_at from public.zad_member_facts where member_id = :ma and key = 'allergy'),
  'value, source, confidence replaced');

-- ── القواعد ──
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'mood', 'value', 'متعب', 'source', 'inferred', 'confidence', 0.6), now()) ->> 'reason' = 'inferred_needs_evidence',
  'inferred without evidence refused');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'mood', 'value', 'متعب', 'source', 'inferred', 'confidence', 0.95, 'evidence', 'قال تعبان'), now()) ->> 'reason' = 'inferred_needs_evidence',
  'inferred with confidence above 0.8 refused');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'mood', 'value', 'متعب', 'source', 'inferred', 'evidence', 'قال تعبان'), now()) ->> 'reason' = 'inferred_needs_evidence',
  'inferred without confidence refused');
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'mood', 'value', 'متعب', 'source', 'inferred', 'confidence', 0.8, 'evidence', 'قال تعبان'), now()) ->> 'ok')::boolean,
  'inferred with confidence 0.8 and evidence accepted');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'x', 'value', 'y', 'source', 'guess'), now()) ->> 'reason' = 'bad_source', 'bad source refused');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', '', 'value', 'y', 'source', 'said'), now()) ->> 'reason' = 'fact_invalid', 'empty key refused');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', repeat('k', 61), 'value', 'y', 'source', 'said'), now()) ->> 'reason' = 'fact_invalid', 'key over 60 refused');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'x', 'value', '  ', 'source', 'said'), now()) ->> 'reason' = 'fact_invalid', 'empty value refused');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'x', 'value', repeat('v', 501), 'source', 'said'), now()) ->> 'reason' = 'fact_invalid', 'value over 500 refused');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'x', 'value', 'y', 'source', 'said', 'confidence', 1.5), now()) ->> 'reason' = 'fact_invalid', 'confidence above 1 refused');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :mb, 'key', 'x', 'value', 'y', 'source', 'said'), now()) ->> 'reason' = 'member_not_in_household',
  'member of another household refused');

-- ── forget ──
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_forget', jsonb_build_object('member_id', :ma, 'key', 'nope'), now()) ->> 'reason' = 'fact_not_found', 'forgetting an unknown key refused');
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_forget', jsonb_build_object('member_id', :ma, 'key', 'allergy'), now()) ->> 'ok')::boolean, 'forget works');
select pg_temp.check((select expires_at is not null and expires_at <= now() from public.zad_member_facts where member_id = :ma and key = 'allergy'), 'forget sets expires_at to now');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_forget', jsonb_build_object('member_id', :ma, 'key', 'allergy'), now()) ->> 'reason' = 'fact_not_found', 'forgetting twice refused');
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'allergy', 'value', 'سمك', 'source', 'said'), now()) ->> 'ok')::boolean, 'key can be set again after forgetting');
select pg_temp.check((select count(*) from public.zad_member_facts where member_id = :ma and key = 'allergy') = 2, 'history kept: forgotten row plus new one');

-- ── RLS ──
select pg_temp.who(:a);
select pg_temp.check((select count(*) from public.zad_member_facts) = 3, 'owner reads own facts');
select pg_temp.who(:b);
select pg_temp.check((select count(*) from public.zad_member_facts) = 0, 'other user reads nothing');

-- ── الكتابة المباشرة مقفولة ──
select pg_temp.who(:a);
select pg_temp.check(pg_temp.fails($q$insert into public.zad_member_facts (user_id, member_id, key, value, source) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aa01', 'k', 'v', 'said')$q$), 'owner direct insert refused');
select pg_temp.check(pg_temp.fails($q$update public.zad_member_facts set value = 'z'$q$), 'owner direct update refused');
select pg_temp.check(pg_temp.fails($q$delete from public.zad_member_facts$q$), 'owner direct delete refused');
select pg_temp.who(:b);
select pg_temp.check(pg_temp.fails($q$insert into public.zad_member_facts (user_id, member_id, key, value, source) values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000bb01', 'k', 'v', 'said')$q$), 'other user direct insert refused');
select pg_temp.check(pg_temp.fails($q$update public.zad_member_facts set value = 'z'$q$), 'other user direct update refused');

-- ── قيود الجدول (كسوبر يوزر) ──
reset role;
select pg_temp.check(pg_temp.fails($q$insert into public.zad_member_facts (user_id, member_id, key, value, source) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aa01', 'k', 'v', 'nope')$q$), 'bad source enum refused');
select pg_temp.check(pg_temp.fails($q$insert into public.zad_member_facts (user_id, member_id, key, value, source, confidence) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aa01', 'k', 'v', 'said', 1.5)$q$), 'confidence over 1 refused');
select pg_temp.check(pg_temp.fails($q$insert into public.zad_member_facts (user_id, member_id, key, value, source) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aa01', '', 'v', 'said')$q$), 'empty key refused');
select pg_temp.check(pg_temp.fails($q$insert into public.zad_member_facts (user_id, member_id, key, value, source) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000bb01', 'k', 'v', 'said')$q$), 'member of another user refused (composite fk)');
select pg_temp.check(pg_temp.fails($q$insert into public.zad_member_facts (user_id, member_id, key, value, source) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aa01', 'allergy', 'v', 'said')$q$), 'partial unique index: one current per member+key');
