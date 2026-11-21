-- Scratch shape for commit_intent_self_test.sql (after the pharmacy, money and budgets scaffolds): zad_users' settings columns,
-- agent_goals, zad_savings_challenges (incl. the one-active unique index) and zad_dose_snoozes with their migrations'
-- constraints, plus zad_goal_add_progress verbatim from 20261113070000. Never against live.
\set ON_ERROR_STOP on
alter table public.zad_users
  add column cycle_start_day int check (cycle_start_day between 1 and 31), add column currency text, add column country text,
  add column emergency_fund_balance numeric not null default 0, add column sleep_bed time, add column sleep_wake time,
  add column sleep_nights smallint, add column sleep_source text check (sleep_source is null or sleep_source in ('learned', 'manual')),
  add column sleep_updated_at timestamptz, add column pet_calls_enabled boolean not null default true,
  add column food_pattern_enabled boolean not null default false;
create table public.agent_goals (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) <= 200), metric text check (char_length(metric) <= 200), target_value numeric,
  current_value numeric not null default 0, deadline_date date,
  status text not null default 'active' check (status in ('active','achieved','stalled','cancelled')),
  last_reviewed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  progress_kind text not null default 'tasks' check (progress_kind in ('tasks', 'amount')), unique (user_id, title));
create table public.zad_savings_challenges (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  started_on date not null, length_days int not null default 30 check (length_days between 7 and 90),
  daily_cap numeric(14, 2) not null check (daily_cap >= 0), currency text check (currency is null or char_length(currency) <= 10),
  status text not null default 'active' check (status in ('active', 'completed', 'abandoned')),
  days_won int not null default 0, days_lost int not null default 0, streak int not null default 0, best_streak int not null default 0,
  last_evaluated_on date, source text not null default 'app' check (source in ('app', 'voice', 'chat', 'telegram')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create unique index zad_savings_challenges_one_active on public.zad_savings_challenges (user_id) where status = 'active';
create table public.zad_dose_snoozes (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null references public.zad_pharmacy_items(id) on delete cascade,
  scheduled_at timestamptz not null, snooze_until timestamptz not null, created_at timestamptz not null default now(),
  primary key (user_id, item_id, scheduled_at));
create or replace function public.zad_goal_add_progress(p_user uuid, p_goal uuid, p_amount numeric)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_goal public.agent_goals%rowtype;
begin
  if p_amount is null or p_amount = 0 then
    return jsonb_build_object('ok', false, 'reason', 'no_amount');
  end if;
  select * into v_goal from public.agent_goals
   where id = p_goal and user_id = p_user and status = 'active' for update;
  if v_goal.id is null then
    return jsonb_build_object('ok', false, 'reason', 'unknown_goal');
  end if;
  if v_goal.progress_kind <> 'amount' then
    return jsonb_build_object('ok', false, 'reason', 'not_amount');
  end if;
  update public.agent_goals
     set current_value = greatest(0, current_value + p_amount), updated_at = now()
   where id = p_goal
  returning * into v_goal;
  return jsonb_build_object('ok', true, 'current_value', v_goal.current_value, 'target_value', v_goal.target_value);
end
$function$;
