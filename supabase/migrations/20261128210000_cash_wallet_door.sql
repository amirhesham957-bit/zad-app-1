-- P3.12: محفظة الكاش من الباب الوحيد.
--
-- رصيد الكاش موجود ومحسوب من الدفتر (zad_cash_balance، 20260726060000): تحويل لكاش (سحب ATM) = +،
-- مصروف بمحفظة cash = -، ودفع الكارت مايلمسوش. مفيش جدول جديد (رصيد تاني = مصدر حقيقة تاني).
-- الناقص كان الباب: نفس السحب ييجي مرتين (إشعار البنك + «سحبت ١٠٠٠» بالكلام) فالكاش يتضاعف، ومصروف
-- «كاش» لدفعة البنك إشعارها وصل فتتخصم من الكاش ومن البنك. نوعين جداد في مجال money (من غير ما نلمس
-- zad_commit_intent: بيندّه zad_intent_money للبادئة money):
--
--   money.cash_withdrawn {amount, title?, from_wallet? (card|bank)، allow_duplicate?}
--       تحويل لكاش، مش مصروف. نفس المبلغ في تحويل لكاش من ٦ ساعات قبل لـ٦ بعد = نفس السحب:
--       رفض cash_withdrawal_duplicate_suspected بتفاصيل التوأم (سؤال واحد)، و allow_duplicate = «سحبتين فعلاً».
--   money.cash_spent {amount, title, category?, merchant_name?, for_person?, confirm_cash?}
--       مصروف من محفظة الكاش. لو فيه إشعار بنك (مصروف كارت من الإشعار، لسه مش مفسَّر) بنفس المبلغ في نافذة
--       P2.10 (private.zad_bank_twin) = غالباً دفعة واحدة بالكارت: رفض cash_spend_matches_bank_notice بتفاصيل
--       الإشعار (سؤال واحد)، و confirm_cash = «دفعت كاش فعلاً».
--   money.purchase بـpurchase.wallet = cash: نفس الحارس (purchase.confirm_cash).
--
-- باقي أنواع money بتعدّي لدالة المجال القديمة (اتسمّت zad_intent_money_core) من غير تغيير.

alter function public.zad_intent_money(uuid, text, jsonb, timestamptz) rename to zad_intent_money_core;

create or replace function public.zad_intent_money(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_res jsonb;
  v_twin public.zad_transactions%rowtype;
  v_twin_id uuid;
  v_amount numeric;
  v_wallet text;
  v_fields jsonb;
  v_reason text;
  v_before numeric;
begin
  if p_kind not in ('money.cash_withdrawn', 'money.cash_spent') then
    if p_kind = 'money.purchase' and jsonb_typeof(p_payload -> 'purchase') = 'object'
       and p_payload -> 'purchase' ->> 'wallet' = 'cash'
       and coalesce(p_payload -> 'purchase' ->> 'confirm_cash', '') <> 'true' then
      begin
        v_amount := round((p_payload -> 'purchase' ->> 'amount')::numeric, 2);
      exception when others then
        v_amount := null;
      end;
      if v_amount is not null and v_amount > 0 then
        v_twin_id := private.zad_bank_twin(p_uid, v_amount, p_occurred);
        if v_twin_id is not null then
          select * into v_twin from public.zad_transactions where id = v_twin_id;
          return jsonb_build_object('ok', false, 'reason', 'cash_spend_matches_bank_notice',
            'detail', jsonb_build_object('twin_id', v_twin.id, 'title', v_twin.title, 'amount', v_twin.amount, 'created_at', v_twin.created_at));
        end if;
      end if;
    end if;
    return public.zad_intent_money_core(p_uid, p_kind, p_payload, p_occurred);
  end if;

  v_before := public.zad_cash_balance(p_uid);

  if p_kind = 'money.cash_withdrawn' then
    v_wallet := coalesce(nullif(p_payload ->> 'from_wallet', ''), 'card');
    if v_wallet not in ('card', 'bank') then
      return jsonb_build_object('ok', false, 'reason', 'wallet_unknown');
    end if;
    v_fields := jsonb_build_object('amount', p_payload -> 'amount',
      'title', coalesce(nullif(btrim(coalesce(p_payload ->> 'title', '')), ''), 'سحب كاش'),
      'category', coalesce(nullif(p_payload ->> 'category', ''), 'تحويلات'),
      'txn_kind', 'transfer', 'transfer_to', 'cash', 'wallet', v_wallet,
      'source_type', p_payload -> 'source_type', 'merchant_name', p_payload -> 'merchant_name');
    v_reason := public.zad_intent_money_fields(v_fields, true);
    if v_reason is not null then
      return jsonb_build_object('ok', false, 'reason', v_reason);
    end if;
    v_amount := round((v_fields ->> 'amount')::numeric, 2);
    if coalesce(p_payload ->> 'allow_duplicate', '') <> 'true' then
      select * into v_twin from public.zad_transactions
       where user_id = p_uid and txn_kind = 'transfer' and transfer_to = 'cash'
         and abs(amount - v_amount) < 0.005
         and created_at between p_occurred - interval '6 hours' and p_occurred + interval '6 hours'
       order by abs(extract(epoch from created_at - p_occurred)) limit 1;
      if found then
        return jsonb_build_object('ok', false, 'reason', 'cash_withdrawal_duplicate_suspected',
          'detail', jsonb_build_object('twin_id', v_twin.id, 'title', v_twin.title, 'amount', v_twin.amount, 'created_at', v_twin.created_at));
      end if;
    end if;
  else
    v_fields := jsonb_build_object('amount', p_payload -> 'amount', 'title', p_payload -> 'title',
      'category', p_payload -> 'category', 'merchant_name', p_payload -> 'merchant_name',
      'for_person', p_payload -> 'for_person', 'source_type', p_payload -> 'source_type',
      'txn_kind', 'expense', 'wallet', 'cash');
    v_reason := public.zad_intent_money_fields(v_fields, true);
    if v_reason is not null then
      return jsonb_build_object('ok', false, 'reason', v_reason);
    end if;
    v_amount := round((v_fields ->> 'amount')::numeric, 2);
    if coalesce(p_payload ->> 'confirm_cash', '') <> 'true' then
      v_twin_id := private.zad_bank_twin(p_uid, v_amount, p_occurred);
      if v_twin_id is not null then
        select * into v_twin from public.zad_transactions where id = v_twin_id;
        return jsonb_build_object('ok', false, 'reason', 'cash_spend_matches_bank_notice',
          'detail', jsonb_build_object('twin_id', v_twin.id, 'title', v_twin.title, 'amount', v_twin.amount, 'created_at', v_twin.created_at));
      end if;
    end if;
  end if;

  v_res := public.zad_intent_money_core(p_uid, 'money.logged',
    (select jsonb_object_agg(k, v) from jsonb_each(v_fields) e(k, v) where v <> 'null'::jsonb), p_occurred);
  if (v_res ->> 'ok')::boolean is not true then
    return v_res;
  end if;
  return jsonb_set(v_res, '{payload}', (v_res -> 'payload') || jsonb_build_object(
    'cash_before', v_before, 'cash_after', public.zad_cash_balance(p_uid)));
end;
$fn$;

revoke all on function public.zad_intent_money(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
revoke all on function public.zad_intent_money_core(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
