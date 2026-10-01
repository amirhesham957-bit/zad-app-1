-- One pay day, and a budget whose numbers count the same days (2026-10-01).
--
-- Measured on the owner's account: the budget cycle started on day 16
-- (zad_users.cycle_start_day, what the home card counts down to) while the profile the brain
-- talks from said day 30 (zad_customer_profile.pay_day), and the morning greeting still asked
-- «بتقبض يوم كام؟». And one zad_budget_state answer said «spent 0» next to categories summing
-- to 1,154: after the balance was re-anchored, spent counted from the anchor and the
-- categories from the start of the cycle.

-- 1. The budget cycle is the pay day. When it changes, the profile follows.
create or replace function public.zad_sync_pay_day_from_cycle()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if new.cycle_start_day is not null
     and new.cycle_start_day between 1 and 31
     and new.cycle_start_day is distinct from old.cycle_start_day then
    insert into public.zad_customer_profile (user_id, pay_day, updated_by)
    values (new.id, new.cycle_start_day, 'app')
    on conflict (user_id) do update
      set pay_day = excluded.pay_day, updated_at = now(), updated_by = 'app';
  end if;
  return new;
end;
$function$;

drop trigger if exists zad_users_sync_pay_day on public.zad_users;
create trigger zad_users_sync_pay_day
  after update of cycle_start_day on public.zad_users
  for each row execute function public.zad_sync_pay_day_from_cycle();

-- Existing accounts: the cycle wins (the owner set day 16 on 2026-09-30; the profile's 30
-- dates from 2026-09-29).
update public.zad_customer_profile p
   set pay_day = u.cycle_start_day, updated_at = now(), updated_by = 'app'
  from public.zad_users u
 where u.id = p.user_id
   and u.cycle_start_day between 1 and 31
   and p.pay_day is distinct from u.cycle_start_day;

-- 2. Categories count from the same moment as «spent».
create or replace function public.zad_budget_state(p_user uuid, p_tz text default null::text)
 returns jsonb
 language plpgsql
 stable
 set search_path to 'public'
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
$function$;
