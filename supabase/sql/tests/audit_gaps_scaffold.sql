-- The live shapes the audit migration (20261005233809) edits, on top of scratch_scaffold.sql. The two functions it rewrites
-- by text carry the exact fragments the live definitions have (checked by a read-only query against the project,
-- 2026-10-05: one 'due', one date regex, two day calculations, one zad_try_date), around a minimal body.
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/audit_gaps_scaffold.sql
--   psql < supabase/migrations/20261005233809_audit_gaps.sql
--   psql < supabase/sql/tests/audit_gaps_test.sql

\set ON_ERROR_STOP on

create table if not exists public.agent_tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, kind text, task_description text,
  scheduled_for timestamptz, status text default 'pending', created_at timestamptz not null default now());
create unique index if not exists idx_agent_tasks_proactive_dedup on public.agent_tasks (user_id, kind, ((created_at at time zone 'UTC')::date))
  where kind in ('spending_ahead', 'med_followup', 'bill_reminder', 'warranty_reminder', 'home_weekly_digest', 'listener_gap_alert',
                 'spend_forecast', 'habit_budget', 'predicted_shortage');
create table if not exists public.zad_transactions (
  id uuid primary key default gen_random_uuid(), user_id uuid, amount numeric, category text, is_expense boolean default true,
  created_at timestamptz default now());
create table if not exists public.zad_subscriptions (
  id uuid primary key default gen_random_uuid(), user_id uuid, title text, amount numeric, renewal_date text, due_day int,
  billing_cycle text default 'MONTHLY', is_active boolean default true);
create table if not exists public.zad_obligations (user_id uuid, title text, active boolean, due_day int);
create table if not exists public.zad_inventory (user_id uuid, quantity numeric, low_stock_threshold numeric);
create table if not exists public.zad_pharmacy_items (user_id uuid, remaining_quantity numeric, daily_dose_count numeric);

create or replace function public.zad_try_date(p text) returns date language sql immutable as $$
  select case when p ~ '^\d{4}-\d{2}-\d{2}' then substring(p from 1 for 10)::date end $$;

-- zad_subscription_next_renewal: the live body, verbatim (prosrc, 2026-10-05).
create or replace function public.zad_subscription_next_renewal(p_renewal_date text, p_due_day integer, p_billing_cycle text, p_asof date)
returns date language plpgsql immutable as $$
declare
  v_anchor date;
  v_day int;
  v_next date;
  v_guard int := 0;
begin
  if p_asof is null then return null; end if;
  if p_renewal_date is not null
     and substring(p_renewal_date from 1 for 10) ~ '^\d{4}-\d{2}-\d{2}$' then
    begin
      v_anchor := substring(p_renewal_date from 1 for 10)::date;
    exception when others then
      v_anchor := null;
    end;
  end if;
  if v_anchor is null then
    v_day := coalesce(p_due_day, (substring(coalesce(p_renewal_date, '') from '\d{1,2}'))::int);
    if v_day is null or v_day < 1 or v_day > 31 then return null; end if;
    v_anchor := make_date(
      extract(year from p_asof)::int, extract(month from p_asof)::int,
      least(v_day, extract(day from (date_trunc('month', p_asof) + interval '1 month - 1 day'))::int));
  else
    v_day := extract(day from v_anchor)::int;
  end if;
  v_next := v_anchor;
  while v_next < p_asof and v_guard < 600 loop
    v_guard := v_guard + 1;
    v_next := case upper(coalesce(p_billing_cycle, 'MONTHLY'))
      when 'YEARLY' then (v_next + interval '1 year')::date
      when 'ANNUAL' then (v_next + interval '1 year')::date
      when 'WEEKLY' then (v_next + interval '1 week')::date
      else make_date(
        extract(year from (v_next + interval '1 month'))::int,
        extract(month from (v_next + interval '1 month'))::int,
        least(v_day, extract(day from (date_trunc('month', v_next + interval '1 month')
                                       + interval '1 month - 1 day'))::int))
    end;
  end loop;
  if v_next < p_asof then return null; end if;
  return v_next;
end;
$$;

-- The bill reminder around its live fragments: candidates within -2..3 days, written as one task.
create or replace function public._agent_bill_reminder_for_user(p_user uuid)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare
  v_items jsonb;
begin
  select jsonb_agg(jsonb_build_object(
        'title', s.title,
        'due', s.renewal_date,
        'days_left', (s.renewal_date::date - (now() at time zone 'utc')::date)
      ))
    into v_items
    from public.zad_subscriptions s
    where s.user_id = p_user and s.is_active is true
        and s.renewal_date ~ '^\d{4}-\d{2}-\d{2}$'
        and (s.renewal_date::date - (now() at time zone 'utc')::date) between -2 and 3;
  if v_items is null then return; end if;
  insert into public.agent_tasks (user_id, kind, task_description, scheduled_for) values (p_user, 'bill_reminder', v_items::text, now());
end;
$function$;

-- Domain observations around its live fragment.
create or replace function public.zad_domain_observations(p_user uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_out jsonb := '[]'::jsonb;
  v_today date := (now() at time zone 'utc')::date;
begin
  SELECT v_out || coalesce(jsonb_agg(jsonb_build_object('title', title, 'renewal_date', rd)), '[]'::jsonb)
    INTO v_out
    FROM (SELECT title, amount, zad_try_date(renewal_date) AS rd
            FROM zad_subscriptions
           WHERE user_id = p_user AND is_active AND renewal_date IS NOT NULL) x
   WHERE rd IS NOT NULL AND rd >= v_today AND rd - v_today <= 7;
  return v_out;
end;
$function$;

-- Data as live (2026-10-05): categories in two vocabularies, a trailing space, a renewal that passed.
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1') on conflict do nothing;
insert into public.zad_transactions (user_id, amount, category) values
  ('00000000-0000-0000-0000-0000000000a1', 100, 'بقالة'), ('00000000-0000-0000-0000-0000000000a1', 50, 'البقالة'),
  ('00000000-0000-0000-0000-0000000000a1', 900, 'فواتير'), ('00000000-0000-0000-0000-0000000000a1', 300, 'عام'),
  ('00000000-0000-0000-0000-0000000000a1', 1500, 'شهر '), ('00000000-0000-0000-0000-0000000000a1', 250, 'صحة'),
  ('00000000-0000-0000-0000-0000000000a1', 70, null), ('00000000-0000-0000-0000-0000000000a1', 40, 'هدايا');
