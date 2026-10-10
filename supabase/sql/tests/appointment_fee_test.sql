-- An appointment's fee is reserved (migration 20261010190000). Scratch database only:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/appointment_fee_test.sql
--
-- zad_budget_state below is the live text, character for character (pg_get_functiondef on
-- 2026-10-10, md5 10eb8df86c2e1c7a7db72338f27b099a — the test checks it), so the migration's
-- match is tried on what production has. zad_budget_state_legacy is a stub with a fixed cycle.
-- Everything rolls back.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

begin;

alter table public.zad_users add column if not exists balance_anchored_at timestamptz;
create table if not exists public.zad_transactions (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, amount numeric not null default 0,
  txn_kind text, is_verified boolean, category text, created_at timestamptz default now());
create table if not exists public.zad_appointments (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, title text not null, kind text not null default 'other',
  starts_at timestamptz not null, place_label text, remind_minutes_before integer, recurrence text not null default 'once',
  status text not null default 'upcoming' check (status in ('upcoming', 'done', 'cancelled')), source text, notes text,
  created_at timestamptz default now(), updated_at timestamptz default now(), for_person text);

-- A cycle that ends in 10 days, 5000 opening, 1000 spent, rent 2000 due in 5 days.
create or replace function public.zad_budget_state_legacy(p_user uuid, p_tz text default null)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'cycle_end', to_char(current_date + 10, 'YYYY-MM-DD'), 'days_left', 10, 'timezone', 'Africa/Cairo',
    'monthly_limit', 5000, 'income', 0, 'spent', 1000, 'days_elapsed', 20, 'cycle_length_days', 30,
    'committed_items', jsonb_build_array(jsonb_build_object(
      'title', 'إيجار', 'amount', 2000, 'kind', 'obligation', 'next_due', to_char(current_date + 5, 'YYYY-MM-DD'))))
$$;

CREATE OR REPLACE FUNCTION public.zad_budget_state(p_user uuid, p_tz text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_state jsonb;
  v_end date;
  v_items jsonb;
  v_committed numeric;
  v_obligations numeric;
  v_subscriptions numeric;
  v_available numeric;
  v_daily numeric;
  v_next jsonb;
  v_days_left int;
  v_opening numeric;
  v_has_opening boolean;
  v_income numeric;
  v_spent numeric;
  v_balance numeric;
  v_remaining numeric;
  v_velocity numeric;
  v_threat text;
  v_anchor timestamptz;
  v_tz text;
  v_unverified int;
  v_days_since numeric;
  v_by_category jsonb;
begin
  v_state := public.zad_budget_state_legacy(p_user, p_tz);
  v_end := (v_state ->> 'cycle_end')::date;
  v_days_left := coalesce((v_state ->> 'days_left')::int, 0);
  v_tz := coalesce(v_state ->> 'timezone', 'UTC');

  select coalesce(jsonb_agg(item order by item ->> 'next_due'), '[]'::jsonb)
    into v_items
  from jsonb_array_elements(coalesce(v_state -> 'committed_items', '[]'::jsonb)) item
  where (item ->> 'next_due')::date < v_end;

  select coalesce(sum((item ->> 'amount')::numeric), 0),
         coalesce(sum((item ->> 'amount')::numeric) filter (where item ->> 'kind' <> 'subscription'), 0),
         coalesce(sum((item ->> 'amount')::numeric) filter (where item ->> 'kind' = 'subscription'), 0)
    into v_committed, v_obligations, v_subscriptions
  from jsonb_array_elements(v_items) item;

  v_has_opening := (v_state ->> 'monthly_limit') is not null;
  v_opening := coalesce((v_state ->> 'monthly_limit')::numeric, 0);

  select balance_anchored_at into v_anchor from public.zad_users where id = p_user;

  v_by_category := v_state -> 'by_category';
  if v_anchor is null then
    v_income     := coalesce((v_state ->> 'income')::numeric, 0);
    v_spent      := coalesce((v_state ->> 'spent')::numeric, 0);
    v_unverified := coalesce((v_state ->> 'unverified_count')::int, 0);
  else
    select
      coalesce(sum(amount) filter (where txn_kind = 'income'), 0),
      coalesce(sum(amount) filter (where txn_kind = 'expense'), 0),
      count(*) filter (where txn_kind in ('expense','income') and coalesce(is_verified, false) = false)
    into v_income, v_spent, v_unverified
    from public.zad_transactions
    where user_id = p_user
      and created_at >= v_anchor;

    -- Same window as v_spent, so the categories add up to «spent».
    select coalesce(jsonb_object_agg(cat, total), '{}'::jsonb)
      into v_by_category
    from (
      select coalesce(nullif(btrim(category), ''), 'أخرى') as cat, round(sum(amount)::numeric, 2) as total
      from public.zad_transactions
      where user_id = p_user
        and created_at >= v_anchor
        and txn_kind = 'expense'
      group by 1
    ) c;
  end if;

  v_balance := v_opening + v_income - v_spent;

  v_remaining := case when v_has_opening then v_balance else null end;
  v_available := case when v_remaining is null then null else v_remaining - v_committed end;
  v_daily := case
    when v_available is null then null
    when v_days_left > 0 then v_available / v_days_left
    else v_available
  end;
  v_next := v_items -> 0;

  v_days_since := case
    when v_anchor is null then greatest(coalesce((v_state ->> 'days_elapsed')::int, 1), 1)
    else greatest(extract(epoch from (now() - v_anchor)) / 86400.0, 1)
  end;
  v_velocity := case
    when (v_opening + v_income) <= 0 then null
    else v_spent / ((v_opening + v_income)
                    * v_days_since
                    / greatest(coalesce((v_state ->> 'cycle_length_days')::int, 1), 1))
  end;

  v_threat := case
    when not v_has_opening then 'UNKNOWN'
    when v_balance < 0 then 'OVER'
    when v_velocity is null then 'UNKNOWN'
    when v_velocity > 1.3 then 'DANGER'
    when v_velocity > 1.05 then 'WATCH'
    else 'SAFE'
  end;

  return v_state || jsonb_build_object(
    'committed', round(v_committed, 2),
    'committed_obligations', round(v_obligations, 2),
    'committed_subscriptions', round(v_subscriptions, 2),
    'committed_items', v_items,
    'next_obligation_due', v_next,
    'opening_balance', round(v_opening, 2),
    'balance_anchored_at', v_anchor,
    'spent', round(v_spent, 2),
    'income', round(v_income, 2),
    'unverified_count', v_unverified,
    'balance', round(v_balance, 2),
    'remaining', round(v_remaining, 2),
    'available', round(v_available, 2),
    'daily_allowance_left', round(v_daily, 2),
    'velocity', round(v_velocity, 4),
    'threat', v_threat,
    'by_category', coalesce(v_by_category, '{}'::jsonb)
  );
end;
$function$
;

do $$ begin
  if md5(pg_get_functiondef('public.zad_budget_state(uuid,text)'::regprocedure)) <> '10eb8df86c2e1c7a7db72338f27b099a' then
    raise exception 'the copy of zad_budget_state is not the live text';
  end if;
end $$;

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000e1'), ('00000000-0000-0000-0000-0000000000e2') on conflict do nothing;
insert into public.zad_users (id) values ('00000000-0000-0000-0000-0000000000e1'), ('00000000-0000-0000-0000-0000000000e2') on conflict do nothing;

do $$ begin
  if (public.zad_budget_state('00000000-0000-0000-0000-0000000000e1') ->> 'committed')::numeric <> 2000 then
    raise exception 'baseline committed is not the rent';
  end if;
end $$;

\i supabase/migrations/20261010190000_appointment_fee_is_reserved.sql
-- Twice: a reset database replays it, and the patch must not stack.
\i supabase/migrations/20261010190000_appointment_fee_is_reserved.sql

insert into public.zad_appointments (user_id, title, kind, starts_at, status, expected_cost) values
  ('00000000-0000-0000-0000-0000000000e1', 'كشف الأسنان', 'medical', now() + interval '3 days', 'upcoming', 400),   -- reserved
  ('00000000-0000-0000-0000-0000000000e1', 'دكتور العيون', 'medical', now() + interval '3 days', 'upcoming', null),  -- fee unknown
  ('00000000-0000-0000-0000-0000000000e1', 'متابعة', 'medical', now() + interval '20 days', 'upcoming', 300),       -- next cycle
  ('00000000-0000-0000-0000-0000000000e1', 'اتلغى', 'medical', now() + interval '2 days', 'cancelled', 500),
  ('00000000-0000-0000-0000-0000000000e1', 'خلص', 'medical', now() + interval '2 days', 'done', 600),
  ('00000000-0000-0000-0000-0000000000e1', 'عدّى', 'medical', now() - interval '1 hour', 'upcoming', 200),       -- already happened
  ('00000000-0000-0000-0000-0000000000e2', 'حد تاني', 'medical', now() + interval '1 day', 'upcoming', 999);

do $$
declare v jsonb := public.zad_budget_state('00000000-0000-0000-0000-0000000000e1');
begin
  if (v ->> 'committed')::numeric <> 2400 then raise exception 'committed: %', v ->> 'committed'; end if;
  if (v ->> 'available')::numeric <> 1600 then raise exception 'available: %', v ->> 'available'; end if;
  if jsonb_array_length(v -> 'committed_items') <> 2 then raise exception 'items: %', v -> 'committed_items'; end if;
  -- Sorted by due date: the visit in 3 days comes before the rent in 5, and is «next».
  if v -> 'committed_items' -> 0 ->> 'kind' <> 'appointment' or v -> 'committed_items' -> 0 ->> 'title' <> 'كشف الأسنان'
     or (v -> 'committed_items' -> 0 ->> 'amount')::numeric <> 400 or v -> 'committed_items' -> 0 ->> 'appointment_id' is null then
    raise exception 'first item: %', v -> 'committed_items' -> 0;
  end if;
  if v -> 'next_obligation_due' ->> 'title' <> 'كشف الأسنان' then raise exception 'next due: %', v -> 'next_obligation_due'; end if;
  -- The other account sees only its own.
  if (public.zad_budget_state('00000000-0000-0000-0000-0000000000e2') ->> 'committed')::numeric <> 2999 then
    raise exception 'other account';
  end if;
  -- The fee is what the customer said: positive, bounded.
  begin
    update public.zad_appointments set expected_cost = 0 where title = 'كشف الأسنان';
    raise exception 'a zero fee was accepted';
  exception when check_violation then null;
  end;
  raise notice 'appointment_fee_test: all passed';
end $$;

rollback;
