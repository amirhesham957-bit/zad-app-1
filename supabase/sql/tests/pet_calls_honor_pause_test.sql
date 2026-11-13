-- نداء زادو يحترم قرار الحارس (20261113090000). Run order: see the CI line.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

insert into auth.users (id) values
  ('00000000-0000-4000-8000-0000000000b1'), ('00000000-0000-4000-8000-0000000000b2');
insert into zad_users (id) values
  ('00000000-0000-4000-8000-0000000000b1'), ('00000000-0000-4000-8000-0000000000b2');
insert into zad_companion_care (user_id, fed_at, watered_at) values
  ('00000000-0000-4000-8000-0000000000b1', now() - interval '18 hours', now() - interval '1 hour'),
  ('00000000-0000-4000-8000-0000000000b2', now() - interval '18 hours', now() - interval '1 hour');
insert into telegram_bindings (user_id, chat_id) values
  ('00000000-0000-4000-8000-0000000000b1', 1), ('00000000-0000-4000-8000-0000000000b2', 2);

-- 1. no decision yet: both hungry pets call
begin;
do $$ begin
  assert zad_enqueue_pet_calls() = 2, 'calls held before any decision';
end $$;
rollback;

-- 2. a proposal that is only proposed changes nothing
begin;
insert into zad_guardian_proposals (kind, subject, why) values ('pause_kind', 'pet_call', 'x');
do $$ begin
  assert zad_enqueue_pet_calls() = 2, 'a proposal acted before approval';
end $$;
rollback;

-- 3. approved: nobody is called, for any user
begin;
insert into zad_guardian_proposals (kind, subject, why, status) values ('pause_kind', 'pet_call', 'x', 'approved');
do $$ begin
  assert zad_enqueue_pet_calls() = 0, 'approved pause ignored by the pet-call queue';
end $$;
rollback;

-- 4. approving another kind does not silence pet calls
begin;
insert into zad_guardian_proposals (kind, subject, why, status) values ('pause_kind', 'home_weekly_digest', 'x', 'approved');
do $$ begin
  assert zad_enqueue_pet_calls() = 2, 'another kind''s pause silenced pet calls';
end $$;
rollback;

-- 5. one customer ignored three calls in a row: only that customer stops
begin;
insert into zad_guardian_outcomes (task_id, user_id, kind, delivered_at, replied_within_day)
select gen_random_uuid(), '00000000-0000-4000-8000-0000000000b1', 'pet_call', now() - (g || ' days')::interval, false
  from generate_series(1, 3) g;
do $$ begin
  assert zad_enqueue_pet_calls() = 1, 'personal ignore not honoured';
  assert (select user_id from agent_tasks where kind = 'pet_call') = '00000000-0000-4000-8000-0000000000b2';
end $$;
rollback;

\echo pet_calls_honor_pause_test: all checks passed
