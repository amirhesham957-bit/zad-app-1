-- الحراس المرشّحين (20261011240000). Order:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/guardian_outcomes_scaffold.sql
--   psql < supabase/migrations/20261011230000_guardian_outcomes.sql
--   psql < supabase/sql/tests/guardian_proposals_test.sql   (adds the admin check and the health table,
--        applies 20261011240000, checks)

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create table if not exists public.dashboard_admins (user_id uuid primary key);
create or replace function public.is_dashboard_admin() returns boolean language sql stable security definer
  set search_path = public as $$ select exists (select 1 from public.dashboard_admins where user_id = auth.uid()) $$;
create table if not exists public.zad_brain_health_alerts (
  alert_date date, kind text, total_runs int, bad_runs int, bad_pct int, top_error text,
  created_at timestamptz default now(), primary key (alert_date, kind));
insert into public.dashboard_admins values ('00000000-0000-0000-0000-0000000000a2') on conflict do nothing;

\i supabase/migrations/20261011240000_guardian_proposals.sql

begin;
-- 22 digests to a1 in the last month, none answered; 25 medicine follow-ups, none answered
insert into agent_tasks (user_id, kind, status, updated_at)
select '00000000-0000-0000-0000-0000000000a1', 'home_weekly_digest', 'done', now() - interval '2 days' - (g || ' hours')::interval
  from generate_series(1, 22) g;
insert into agent_tasks (user_id, kind, status, updated_at)
select '00000000-0000-0000-0000-0000000000a1', 'med_followup', 'done', now() - interval '2 days' - (g || ' hours')::interval
  from generate_series(1, 25) g;
do $$
declare r jsonb;
begin
  r := zad_guardian_nightly();
  assert (r->>'judged')::int = 47 and (r->>'proposed')::int = 1, r::text;
  assert (select subject from zad_guardian_proposals where kind = 'pause_kind') = 'home_weekly_digest';
  assert not exists (select 1 from zad_guardian_proposals where subject = 'med_followup'), 'medicine proposed for a pause';
  r := zad_guardian_nightly();
  assert (r->>'proposed')::int = 0, 'proposed twice';
  -- nothing changes for someone else until the owner says so
  assert not _agent_proactive_suppressed('00000000-0000-0000-0000-0000000000a2', 'home_weekly_digest'),
    'a proposal acted before approval';
end $$;

-- a non-admin cannot decide; the admin can
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  perform zad_guardian_proposal_decide((select id from zad_guardian_proposals limit 1), true);
  raise exception 'a customer approved a guardian';
exception when insufficient_privilege then null;
end $$;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
do $$
declare r jsonb;
begin
  assert (select count(*) from zad_guardian_proposals) = 1, 'the admin cannot read proposals';
  r := zad_guardian_proposal_decide((select id from zad_guardian_proposals limit 1), true);
  assert (r->>'ok')::bool, r::text;
end $$;
reset role;
do $$ begin
  -- approved: the digest is quiet for everyone, medicine never
  assert _agent_proactive_suppressed('00000000-0000-0000-0000-0000000000a2', 'home_weekly_digest'), 'approval not respected';
  assert not _agent_proactive_suppressed('00000000-0000-0000-0000-0000000000a2', 'med_followup');
end $$;
rollback;

-- investigate: a loop break three days running
begin;
insert into zad_brain_health_alerts (alert_date, kind, total_runs, bad_runs, bad_pct, top_error)
select current_date - d, 'loop_break', 4, 2, 0, 'فواتير من غير أسعار 2' from generate_series(0, 2) d;
do $$ begin
  assert zad_propose_guardians() = 1;
  assert (select kind from zad_guardian_proposals) = 'investigate';
  assert zad_propose_guardians() = 0, 'investigate proposed twice';
end $$;
rollback;

\echo guardian_proposals_test: all checks passed
