-- حارس النتيجة (20261011230000). Two accounts: a1 ignores the weekly digest, a2 answers it.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

begin;
-- three weekly digests to each, delivered 9, 5 and 2 days ago; a2 wrote back after each
insert into agent_tasks (user_id, kind, status, updated_at)
select u, 'home_weekly_digest', 'done', now() - (d || ' days')::interval
  from unnest(array['00000000-0000-0000-0000-0000000000a1'::uuid, '00000000-0000-0000-0000-0000000000a2'::uuid]) u,
       unnest(array[6, 5, 2]) d;
insert into zad_chat_turns (user_id, role, created_at)
select '00000000-0000-0000-0000-0000000000a2', 'user', now() - (d || ' days')::interval + interval '3 hours'
  from unnest(array[6, 5, 2]) d;
-- a1 also ignored three medicine follow-ups — protection, never silenced
insert into agent_tasks (user_id, kind, status, updated_at)
select '00000000-0000-0000-0000-0000000000a1', 'med_followup', 'done', now() - (d || ' days')::interval
  from unnest(array[6, 5, 2]) d;
-- a task delivered an hour ago is not judged yet; a pending one never
insert into agent_tasks (user_id, kind, status, updated_at) values
  ('00000000-0000-0000-0000-0000000000a1', 'spend_forecast', 'done', now() - interval '1 hour'),
  ('00000000-0000-0000-0000-0000000000a1', 'spend_forecast', 'pending', null);

do $$
declare n int;
begin
  n := zad_judge_guardian_outcomes();
  assert n = 9, 'judged ' || n;
  assert zad_judge_guardian_outcomes() = 0, 'judged twice';
  -- a1 ignored the digest three times in a row: it falls silent for a1, not for a2
  assert _agent_proactive_suppressed('00000000-0000-0000-0000-0000000000a1', 'home_weekly_digest'), 'a1 not silenced';
  assert not _agent_proactive_suppressed('00000000-0000-0000-0000-0000000000a2', 'home_weekly_digest'), 'a2 silenced';
  -- medicine follow-ups are never silenced
  assert not _agent_proactive_suppressed('00000000-0000-0000-0000-0000000000a1', 'med_followup'), 'med silenced';
  -- the scorecard
  assert (select reply_pct from zad_guardian_scorecard() where kind = 'home_weekly_digest') = 50;
end $$;

-- an answer by action counts too: a1 confirms something from Telegram after the last digest
insert into agent_actions (user_id, source, created_at)
  values ('00000000-0000-0000-0000-0000000000a1', 'telegram', now() - interval '2 days' + interval '1 hour');
delete from zad_guardian_outcomes;
do $$ begin
  perform zad_judge_guardian_outcomes();
  assert not _agent_proactive_suppressed('00000000-0000-0000-0000-0000000000a1', 'home_weekly_digest'),
    'a Telegram action did not count as a reply';
end $$;

-- after 14 quiet days the digest comes back
update zad_guardian_outcomes set delivered_at = delivered_at - interval '30 days', replied_within_day = false;
do $$ begin
  assert not _agent_proactive_suppressed('00000000-0000-0000-0000-0000000000a1', 'home_weekly_digest'),
    'still silent after 14 days';
end $$;
-- the explicit refusal still works as before
insert into zad_memory (user_id, subject_kind, suppress_until)
  values ('00000000-0000-0000-0000-0000000000a2', 'spend_forecast', now() + interval '3 days');
do $$ begin
  assert _agent_proactive_suppressed('00000000-0000-0000-0000-0000000000a2', 'spend_forecast');
end $$;
rollback;

\echo guardian_outcomes_test: all checks passed
