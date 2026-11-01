-- «خطر» on the third day of the month (2026-11-01).
--
-- The owner: «البادجت بايظ». Measured that day on their account: budget 10,000, spent 2,128 in the
-- first ~4 days (the month's grocery shop) — velocity 1.69, so `threat` = DANGER with 7,641
-- available and 263 a day left. Velocity reads spending as a steady run rate: one stock-up at the
-- start of a cycle, divided by three days, looks like a month that ends at 170%.
--
-- The judgement moves into `zad_budget_threat` (pure, so the scratch SQL test can hold it), and
-- for the first seven days of a cycle it judges the share of the money spent, not the rate:
--   * over the money (balance < 0)           → OVER, as before;
--   * more than half spent in the first week  → WATCH;
--   * otherwise                               → SAFE.
-- From day seven on, the run rate is a fair read and the old thresholds stand (> 1.3 DANGER,
-- > 1.05 WATCH). `velocity` itself is still reported unchanged.
--
-- `zad_budget_state` is the 20261001190000 body (with the 20260914004000 appointments it reads
-- through), the threat block alone replaced.

create or replace function public.zad_budget_threat(
  p_has_opening boolean,
  p_balance numeric,
  p_spent numeric,
  p_pool numeric,
  p_days_since numeric,
  p_cycle_days int
) returns text
language sql
immutable
parallel safe
set search_path = pg_catalog
as $$
  select case
    when not coalesce(p_has_opening, false) then 'UNKNOWN'
    when p_balance < 0 then 'OVER'
    when coalesce(p_pool, 0) <= 0 then 'UNKNOWN'
    when coalesce(p_days_since, 0) < 7 then
      case when p_spent > p_pool * 0.5 then 'WATCH' else 'SAFE' end
    when p_spent / (p_pool * p_days_since / greatest(coalesce(p_cycle_days, 1), 1)) > 1.3 then 'DANGER'
    when p_spent / (p_pool * p_days_since / greatest(coalesce(p_cycle_days, 1), 1)) > 1.05 then 'WATCH'
    else 'SAFE'
  end;
$$;

create or replace function public.zad_budget_state(p_user uuid, p_tz text default null)
 returns jsonb
 language plpgsql
 stable
 set search_path = public
as $function$
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

  -- مبلغ الكشف (20261010190000): ميعاد جاي قبل نهاية الدورة وتكلفته اللي العميل قالها.
  select coalesce(jsonb_agg(item order by item ->> 'next_due'), '[]'::jsonb)
    into v_items
  from (
    select item from jsonb_array_elements(v_items) item
    union all
    select jsonb_build_object(
             'title', a.title,
             'amount', a.expected_cost,
             'kind', 'appointment',
             'next_due', to_char((a.starts_at at time zone v_tz)::date, 'YYYY-MM-DD'),
             'appointment_id', a.id)
    from public.zad_appointments a
    where a.user_id = p_user
      and a.status = 'upcoming'
      and a.expected_cost > 0
      and a.starts_at >= now()
      and (a.starts_at at time zone v_tz)::date < v_end
  ) all_items;

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

  v_threat := public.zad_budget_threat(
    v_has_opening, v_balance, v_spent, v_opening + v_income, v_days_since,
    coalesce((v_state ->> 'cycle_length_days')::int, 1));

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
$function$;
