-- P2.2 (migration 20261128120000), on a scratch database:
--
--   psql < supabase/sql/tests/events_ledger_scaffold.sql
--   psql < supabase/migrations/20261121160000_events_ledger.sql
--   psql < supabase/migrations/20261128120000_household_traits.sql
--   psql < supabase/sql/tests/household_traits_test.sql
--
-- zad_intent_trait is called directly (the door's own dispatch needs every earlier domain migration). Raises on the first failed check.

\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
grant select on public.zad_household_members to authenticated;
grant select on public.zad_household_traits to authenticated;
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

-- ── الباب: set ──
reset role;
select pg_temp.check((public.zad_intent_trait(:a, 'trait.set', jsonb_build_object('member_id', :ma, 'trait', 'breadwinner', 'source', 'said'), now()) ->> 'ok')::boolean,
  'owner sets a trait through the door');
select pg_temp.check((select count(*) from public.zad_household_traits where member_id = :ma and trait = 'breadwinner' and ends_on is null and source = 'said' and starts_on = current_date) = 1,
  'row is open, source said, starts today');
select pg_temp.check(public.zad_intent_trait(:a, 'trait.set', jsonb_build_object('member_id', :ma, 'trait', 'breadwinner', 'source', 'said'), now()) ->> 'reason' = 'trait_already_open',
  'second open of the same trait is refused');
select pg_temp.check(public.zad_intent_trait(:a, 'trait.set', jsonb_build_object('member_id', :ma, 'trait', 'flying', 'source', 'said'), now()) ->> 'reason' = 'invalid_trait',
  'unknown trait refused');
select pg_temp.check(public.zad_intent_trait(:a, 'trait.set', jsonb_build_object('member_id', :ma, 'trait', 'elder', 'source', 'guess'), now()) ->> 'reason' = 'bad_source',
  'bad source refused');
select pg_temp.check(public.zad_intent_trait(:a, 'trait.set', jsonb_build_object('member_id', :mb, 'trait', 'elder', 'source', 'said'), now()) ->> 'reason' = 'member_not_in_household',
  'member of another household refused');
select pg_temp.check(public.zad_intent_trait(:a, 'trait.end', jsonb_build_object('member_id', :ma, 'trait', 'elder'), now()) ->> 'reason' = 'trait_not_open',
  'ending a trait that is not open is refused');

-- ── الباب: end ثم فتح من جديد ──
select pg_temp.check((public.zad_intent_trait(:a, 'trait.end', jsonb_build_object('member_id', :ma, 'trait', 'breadwinner'), now()) ->> 'ok')::boolean,
  'end works');
select pg_temp.check((select ends_on from public.zad_household_traits where member_id = :ma and trait = 'breadwinner') = current_date, 'end closes today');
select pg_temp.check((public.zad_intent_trait(:a, 'trait.set', jsonb_build_object('member_id', :ma, 'trait', 'breadwinner', 'source', 'observed'), now()) ->> 'ok')::boolean,
  'trait can be opened again after it ended');
select pg_temp.check((select count(*) from public.zad_household_traits where member_id = :ma and trait = 'breadwinner') = 2, 'history kept: two rows');
select pg_temp.check(public.zad_intent_trait(:a, 'trait.end', jsonb_build_object('member_id', :ma, 'trait', 'breadwinner', 'ends_on', '2000-01-01'), now()) ->> 'reason' = 'trait_date_invalid',
  'end before start refused');

-- ── RLS: القراءة للصاحب بس ──
select pg_temp.who(:a);
select pg_temp.check((select count(*) from public.zad_household_traits) = 2, 'owner reads own traits');
select pg_temp.who(:b);
select pg_temp.check((select count(*) from public.zad_household_traits) = 0, 'other user reads nothing');

-- ── الكتابة المباشرة مقفولة ──
select pg_temp.who(:a);
select pg_temp.check(pg_temp.fails($q$insert into public.zad_household_traits (user_id, member_id, trait, source) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aa01', 'elder', 'said')$q$),
  'owner direct insert refused');
select pg_temp.check(pg_temp.fails($q$update public.zad_household_traits set source = 'inferred'$q$), 'owner direct update refused');
select pg_temp.check(pg_temp.fails($q$delete from public.zad_household_traits$q$), 'owner direct delete refused');
select pg_temp.who(:b);
select pg_temp.check(pg_temp.fails($q$insert into public.zad_household_traits (user_id, member_id, trait, source) values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000bb01', 'elder', 'said')$q$),
  'other user direct insert refused');
select pg_temp.check(pg_temp.fails($q$update public.zad_household_traits set source = 'inferred'$q$), 'other user direct update refused');

-- ── قيود الجدول نفسها (كسوبر يوزر) ──
reset role;
select pg_temp.check(pg_temp.fails($q$insert into public.zad_household_traits (user_id, member_id, trait, source) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aa01', 'nope', 'said')$q$), 'bad trait enum refused');
select pg_temp.check(pg_temp.fails($q$insert into public.zad_household_traits (user_id, member_id, trait, source) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aa01', 'elder', 'nope')$q$), 'bad source enum refused');
select pg_temp.check(pg_temp.fails($q$insert into public.zad_household_traits (user_id, member_id, trait, source) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000bb01', 'elder', 'said')$q$), 'member of another user refused (composite fk)');
select pg_temp.check(pg_temp.fails($q$insert into public.zad_household_traits (user_id, member_id, trait, source, starts_on, ends_on) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aa01', 'elder', 'said', '2026-02-02', '2026-02-01')$q$), 'ends_on before starts_on refused');
select pg_temp.check(pg_temp.fails($q$insert into public.zad_household_traits (user_id, member_id, trait, source) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aa01', 'breadwinner', 'said')$q$), 'partial unique index: one open per member+trait');
