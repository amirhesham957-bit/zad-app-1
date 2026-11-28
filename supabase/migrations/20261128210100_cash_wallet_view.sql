-- P3.12: «معايا كام كاش» في عرض الفلوس: cash_on_hand = {value, source: zad_cash_balance}.
-- نفس zad_view_money بتاعة 20261128190000 (القاصر بيتقفل فوق قبل أي رقم) + رقم الكاش بس. القراية invoker-rights،
-- فـRLS على zad_transactions (restrictive للقاصر) بتحمي حتى لو اتنادت الدالة من برا العرض.

create or replace function public.zad_view_money()
returns jsonb language plpgsql stable set search_path = public, pg_temp as $$
declare
  v_me uuid := auth.uid();
  v_s jsonb;
  v_debts numeric; v_debt_n int;
  v_subs numeric; v_sub_n int;
  v_threat text;
  v_actions jsonb := '[]'::jsonb;
  v_cash numeric;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  -- P2.5: القاصر مايشوفش أرقام ميزانية خالص (قرار المالك ٢٠٢٦-١١-٢٨).
  if public.zad_i_am_minor() then return jsonb_build_object('ok', false, 'reason', 'minor_no_budget'); end if;
  v_s := public.zad_budget_state(v_me);
  v_threat := v_s ->> 'threat';
  -- P3.12: رصيد الكاش من الدفتر (سحب - صرف كاش). القاصر خرج فوق، فمايوصلهوش.
  v_cash := public.zad_cash_balance(v_me);

  select coalesce(sum(remaining_balance), 0), count(*) into v_debts, v_debt_n
    from public.zad_debts where user_id = v_me and coalesce(is_active, true);
  select coalesce(sum(amount), 0), count(*) into v_subs, v_sub_n
    from public.zad_subscriptions where user_id = v_me and coalesce(is_active, true);

  v_actions := v_actions || jsonb_build_array(jsonb_build_object('id', 'add_expense', 'label', 'سجّل مصروف'));
  if v_threat in ('WATCH', 'DANGER', 'OVER') then
    v_actions := v_actions || jsonb_build_array(jsonb_build_object('id', 'review_budget', 'label', 'راجع الميزانية'));
  end if;
  if v_debt_n > 0 then
    v_actions := v_actions || jsonb_build_array(jsonb_build_object('id', 'pay_debt', 'label', 'سدّد دين'));
  end if;

  return jsonb_build_object(
    'ok', true, 'view', 'money',
    'numbers', jsonb_build_object(
      'balance', public.zad_view_num((v_s ->> 'balance')::numeric, 'zad_budget_state.balance'),
      'available', public.zad_view_num((v_s ->> 'available')::numeric, 'zad_budget_state.available'),
      'spent', public.zad_view_num((v_s ->> 'spent')::numeric, 'zad_budget_state.spent'),
      'income', public.zad_view_num((v_s ->> 'income')::numeric, 'zad_budget_state.income'),
      'committed', public.zad_view_num((v_s ->> 'committed')::numeric, 'zad_budget_state.committed'),
      'daily_allowance_left', public.zad_view_num((v_s ->> 'daily_allowance_left')::numeric, 'zad_budget_state.daily_allowance_left'),
      'cash_on_hand', public.zad_view_num(v_cash, 'zad_cash_balance'),
      'debts_remaining', public.zad_view_num(v_debts, 'zad_debts.remaining_balance'),
      'debts_count', public.zad_view_num(v_debt_n, 'zad_debts.id'),
      'subscriptions_amount', public.zad_view_num(v_subs, 'zad_subscriptions.amount'),
      'subscriptions_count', public.zad_view_num(v_sub_n, 'zad_subscriptions.id')
    ),
    'threat', jsonb_build_object('value', v_threat, 'source', 'zad_budget_state.threat'),
    'available_actions', v_actions
  );
end $$;
