-- P3.1 (migration 20261128210000): سؤال الحقيقة اليومي على scratch database:
--
--   psql < supabase/sql/tests/events_ledger_scaffold.sql
--   psql < supabase/migrations/20261121160000_events_ledger.sql
--   psql < supabase/migrations/20261128120000_household_traits.sql
--   psql < supabase/migrations/20261128130000_member_facts.sql
--   psql < supabase/migrations/20261128230000_fact_checkin.sql
--   psql < supabase/sql/tests/fact_checkin_test.sql

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
\set ma '''00000000-0000-0000-0000-00000000aa01'''
insert into auth.users values (:a);
insert into public.zad_household_members (id, user_id, display_name, kind) values (:ma, :a, 'أنا', 'self');
\set QUIET 0

-- مستنتجة بدليل وثقة ≤ ٠٫٨، ومن غير سؤال لسه
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'tea_no_sugar', 'value', 'شاي من غير سكر', 'source', 'inferred', 'confidence', 0.6, 'evidence', '٥ مرات في ٣٠ يوم'), now()) ->> 'ok')::boolean, 'inferred fact stored');
select pg_temp.check((select asked_at is null and denied_at is null from public.zad_member_facts where key = 'tea_no_sugar'), 'new inferred fact is not asked yet');

-- asked
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_asked', jsonb_build_object('member_id', :ma, 'key', 'tea_no_sugar'), now()) ->> 'ok')::boolean, 'fact_asked works');
select pg_temp.check((select asked_at is not null from public.zad_member_facts where key = 'tea_no_sugar'), 'asked_at stamped');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_asked', jsonb_build_object('member_id', :ma, 'key', 'nope'), now()) ->> 'reason' = 'fact_not_found', 'asking an unknown key refused');

-- «آه» = قالها: نفس الصف، source said، ثقة ١
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'tea_no_sugar', 'value', 'شاي من غير سكر', 'source', 'said'), now()) ->> 'ok')::boolean, 'confirm = set said');
select pg_temp.check((select source = 'said' and confidence = 1 from public.zad_member_facts where key = 'tea_no_sugar') and (select count(*) from public.zad_member_facts where key = 'tea_no_sugar') = 1, 'confirmed: said, confidence 1, no duplicate');

-- «لأ» = deny: بيتقفل، denied_at، ومايتستنتجش تاني ١٨٠ يوم
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'likes_okra', 'value', 'بيحب البامية', 'source', 'inferred', 'confidence', 0.5, 'evidence', 'اشتراها ٣ مرات'), now()) ->> 'ok')::boolean, 'second inferred fact');
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_deny', jsonb_build_object('member_id', :ma, 'key', 'likes_okra'), now()) ->> 'ok')::boolean, 'deny works');
select pg_temp.check((select expires_at is not null and denied_at is not null from public.zad_member_facts where key = 'likes_okra'), 'denied: closed and denied_at set');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_deny', jsonb_build_object('member_id', :ma, 'key', 'likes_okra'), now()) ->> 'reason' = 'fact_not_found', 'deny twice refused');
select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'likes_okra', 'value', 'بيحب البامية', 'source', 'inferred', 'confidence', 0.5, 'evidence', 'اشتراها ٤ مرات'), now()) ->> 'reason' = 'fact_denied_recently', 'inferred again within 180 days refused');
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'likes_okra', 'value', 'بيحب البامية', 'source', 'said'), now()) ->> 'ok')::boolean, 'customer saying it himself is always accepted');
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_forget', jsonb_build_object('member_id', :ma, 'key', 'likes_okra'), now()) ->> 'ok')::boolean, 'forget the said one');
update public.zad_member_facts set denied_at = now() - interval '181 days' where key = 'likes_okra' and denied_at is not null;
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'likes_okra', 'value', 'بيحب البامية', 'source', 'inferred', 'confidence', 0.5, 'evidence', 'اشتراها ٤ مرات'), now()) ->> 'ok')::boolean, 'inferred allowed again after 180 days');

-- تغيير قيمة مستنتجة بيصفّر asked_at
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_asked', jsonb_build_object('member_id', :ma, 'key', 'likes_okra'), now()) ->> 'ok')::boolean, 'ask okra');
select pg_temp.check((public.zad_intent_profile(:a, 'profile.fact_set', jsonb_build_object('member_id', :ma, 'key', 'likes_okra', 'value', 'بيحب الملوخية', 'source', 'inferred', 'confidence', 0.5, 'evidence', 'اشتراها ٤ مرات'), now()) ->> 'ok')::boolean, 'change inferred value');
select pg_temp.check((select asked_at is null from public.zad_member_facts where key = 'likes_okra' and expires_at is null), 'changed inferred value must be asked again');

select pg_temp.check(public.zad_intent_profile(:a, 'profile.fact_zzz', jsonb_build_object('member_id', :ma, 'key', 'k'), now()) ->> 'reason' = 'unknown_kind', 'unknown kind refused');
