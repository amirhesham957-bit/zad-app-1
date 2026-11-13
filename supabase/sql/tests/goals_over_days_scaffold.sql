-- agent_goals / agent_tasks as far as 20261113070000 touches them, with the progress trigger as live had it
-- before (every finished linked task = +1). Loads after scratch_scaffold.sql. Two live-shaped goals: one from the
-- app (counted check-ins, with its review) and one from the chat (an amount, no review) — the 13/11 measurement.

\set ON_ERROR_STOP on

create table public.agent_goals (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, title text not null, metric text,
  target_value numeric, current_value numeric not null default 0, deadline_date date, status text not null default 'active',
  last_reviewed_at timestamptz, created_at timestamptz default now(), updated_at timestamptz default now(),
  unique (user_id, title)
);
create table public.agent_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, kind text, goal_id uuid references public.agent_goals(id),
  recurrence text, scheduled_for timestamptz, task_description text, status text not null default 'pending',
  created_at timestamptz default now()
);

create or replace function public.agent_goal_touch_progress() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.goal_id is not null and new.status = 'done' then
    update agent_goals set current_value = current_value + 1, last_reviewed_at = now(), updated_at = now()
     where id = new.goal_id and status = 'active';
  end if;
  return null;
end; $$;
create trigger trg_agent_goal_progress after update of status on public.agent_tasks for each row
  when (new.status = 'done' and (old.status is distinct from 'done')) execute function public.agent_goal_touch_progress();

insert into public.agent_goals (id, user_id, title, metric, target_value, current_value, deadline_date) values
  ('a0000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', 'ألتزم بميزانية الشهر',
   'الصرف جوه الميزانية — 12 متابعة أسبوعية على ٣ شهور', 12, 1, '2027-01-29'),
  ('b0000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000b1', 'ميزانية طلعات الشتا', null, 400, 0, '2027-02-28');
insert into public.agent_tasks (user_id, kind, goal_id, recurrence, scheduled_for, task_description) values
  ('00000000-0000-0000-0000-0000000000a1', 'goal_review', 'a0000000-0000-0000-0000-0000000000a1', 'weekly', now() + interval '1 day', 'review');
