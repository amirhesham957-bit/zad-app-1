-- P1.7 (migration 20261128150000), on a scratch database:
--
--   psql < supabase/sql/tests/events_ledger_scaffold.sql
--   psql < supabase/migrations/20261121160000_events_ledger.sql
--   psql < supabase/migrations/20261128120000_household_traits.sql
--   psql < supabase/migrations/20261128130000_member_facts.sql
--   psql < supabase/migrations/20261128150000_events_trace_id.sql
--   psql < supabase/sql/tests/events_trace_id_test.sql
--
-- zad_commit_intent itself is called (kind profile.fact_set: its domain function is in the chain above; the other domains
-- are only reached when their kind is sent). Raises on the first failed check.

\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
create or replace function pg_temp.fails(q text) returns boolean language plpgsql as $$
begin execute q; return false; exception when others then return true; end $$;
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set ma '''00000000-0000-0000-0000-00000000aa01'''

insert into auth.users values (:a);
insert into public.zad_household_members (id, user_id, display_name, kind) values (:ma, :a, 'أنا', 'self');
\set QUIET 0

reset role;
-- ── the column ──
select pg_temp.check(exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'zad_events' and column_name = 'trace_id'),
  'zad_events has trace_id');
select pg_temp.check(pg_temp.fails($q$insert into public.zad_events (user_id, member_id, client_event_id, kind, occurred_at, source, trace_id)
  values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aa01', 'short', 'x.y', now(), 'manual', 'abc')$q$),
  'trace_id shorter than 8 refused by the check');
select pg_temp.check(pg_temp.fails($q$insert into public.zad_events (user_id, member_id, client_event_id, kind, occurred_at, source, trace_id)
  values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aa01', 'long', 'x.y', now(), 'manual', repeat('a', 65))$q$),
  'trace_id longer than 64 refused by the check');

-- ── through the single door ──
select pg_temp.check((public.zad_commit_intent(jsonb_build_object('user_id', :a, 'kind', 'profile.fact_set', 'client_event_id', 'ev-trace-1',
  'source', 'manual', 'member_id', :ma, 'trace_id', 'abcd1234efgh5678',
  'payload', jsonb_build_object('member_id', :ma, 'key', 'allergy', 'value', 'فول سوداني', 'source', 'said'))) ->> 'ok')::boolean,
  'door accepts an intent that carries trace_id');
select pg_temp.check((select trace_id = 'abcd1234efgh5678' from public.zad_events where user_id = :a and client_event_id = 'ev-trace-1'),
  'the event row stores the trace_id from the intent');

select pg_temp.check((public.zad_commit_intent(jsonb_build_object('user_id', :a, 'kind', 'profile.fact_set', 'client_event_id', 'ev-trace-2',
  'source', 'manual', 'member_id', :ma,
  'payload', jsonb_build_object('member_id', :ma, 'key', 'diet', 'value', 'نباتي', 'source', 'said'))) ->> 'ok')::boolean,
  'door accepts an intent with no trace_id');
select pg_temp.check((select trace_id is null from public.zad_events where user_id = :a and client_event_id = 'ev-trace-2'),
  'no trace_id in the intent leaves it null');

select pg_temp.check((public.zad_commit_intent(jsonb_build_object('user_id', :a, 'kind', 'profile.fact_set', 'client_event_id', 'ev-trace-3',
  'source', 'manual', 'member_id', :ma, 'trace_id', 'x',
  'payload', jsonb_build_object('member_id', :ma, 'key', 'color', 'value', 'أزرق', 'source', 'said'))) ->> 'ok')::boolean,
  'a malformed trace_id never blocks the write');
select pg_temp.check((select trace_id is null from public.zad_events where user_id = :a and client_event_id = 'ev-trace-3'),
  'a malformed trace_id is dropped, not stored');

-- ── still append-only ──
select pg_temp.check(pg_temp.fails($q$update public.zad_events set trace_id = 'zzzzzzzz1' where client_event_id = 'ev-trace-2'$q$),
  'zad_events stays append-only (trace_id cannot be edited after the fact)');
