-- «محتاج مصروف زيادة؟» كان بيخصم من رصيد الطفل.
--
-- شاشة الطفل بتعرض الطلب كـ«طلب مصروف أو مشتريات»، لكن zad_decide_purchase_request
-- كانت بتعامل أي PURCHASE_REQUEST كطلب شرا: موافقة الأب = خصم المبلغ من رصيد الطفل،
-- ويوصله «اتوافق على طلبك واتخصم … من رصيدك». يعني الطفل اللي طلب مصروف كان
-- رصيده بيقل بدل ما يزيد، وممكن ينزل تحت الصفر. ومكانش فيه أي طريق للأب يحط فلوس
-- للطفل أصلاً — الرصيد كان بيزيد بس من مكافأة مهمة أو تحدي.
--
-- بعد الملف ده:
--   * الطلب بيحمل نوعه في metadata.kind: 'allowance' (مصروف) أو 'purchase' (شرا).
--     طلب من غير kind — كل طلبات تطبيق الأندرويد القديم — يفضل شرا زي ما كان.
--   * موافقة على مصروف = الرصيد يزيد بالمبلغ.
--   * موافقة على شرا = خصم، بس لو الرصيد يكفي. لو مايكفيش الطلب يفضل معلّق
--     والأب يتقاله «حوّله مصروف الأول» — مفيش رصيد سالب تاني.
--   * zad_send_allowance: الأب (مسؤول العيلة) يحوّل مصروف لأي فرد من غير طلب.
--
-- نفس نمط 20260921150000: الرصيد مايتغيرش إلا جوه دالة بترفع zad.family_ledger.

create or replace function public.zad_decide_purchase_request(p_message uuid, p_approve boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_msg public.chat_messages%rowtype;
  v_meta jsonb;
  v_amount numeric;
  v_status text;
  v_allowance boolean;
  v_sender uuid;
  v_sender_user uuid;
  v_balance numeric;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_approve is null then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  select * into v_msg from public.chat_messages where id = p_message for update;
  if not found or not exists (
    select 1 from public.family_members
    where user_id = auth.uid() and family_id = v_msg.family_id
  ) then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if not public.zad_is_family_admin(v_msg.family_id) then
    return jsonb_build_object('ok', false, 'reason', 'not_an_admin');
  end if;
  if v_msg.message_type is distinct from 'PURCHASE_REQUEST' then
    return jsonb_build_object('ok', false, 'reason', 'not_a_request');
  end if;

  begin
    v_meta := v_msg.metadata::jsonb;
    v_amount := (v_meta ->> 'amount')::numeric;
  exception when others then
    return jsonb_build_object('ok', false, 'reason', 'invalid_request');
  end;
  if coalesce(v_meta ->> 'status', '') <> 'PENDING' then
    return jsonb_build_object('ok', true, 'already', true, 'status', v_meta ->> 'status');
  end if;
  if v_amount is null or v_amount <= 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_request');
  end if;

  v_allowance := coalesce(v_meta ->> 'kind', 'purchase') = 'allowance';

  select id, user_id, balance into v_sender, v_sender_user, v_balance
  from public.family_members
  where id::text = v_msg.sender_id and family_id = v_msg.family_id
  for update;

  -- A purchase the child cannot afford stays pending: the parent is told to send
  -- an allowance first, and no balance goes below zero.
  if p_approve and not v_allowance and v_sender is not null
     and coalesce(v_balance, 0) < v_amount then
    return jsonb_build_object(
      'ok', false, 'reason', 'insufficient_balance',
      'balance', coalesce(v_balance, 0), 'amount', v_amount);
  end if;

  v_status := case when p_approve then 'APPROVED' else 'REJECTED' end;

  perform set_config('zad.family_ledger', 'on', true);

  update public.chat_messages
  set metadata = (v_meta || jsonb_build_object(
        'status', v_status, 'decided_by', auth.uid(), 'decided_at', now()))::text
  where id = p_message;

  if p_approve and v_sender is not null then
    update public.family_members
    set balance = coalesce(balance, 0)
                  + case when v_allowance then v_amount else -v_amount end
    where id = v_sender
    returning balance into v_balance;
  end if;

  if v_sender_user is not null then
    insert into public.app_notifications (user_id, title, message)
    values (v_sender_user,
            case when p_approve then 'موافق! ✅' else 'الطلب اترفض' end,
            case
              when p_approve and v_allowance
                then 'اتحوّلك ' || v_amount || ' مصروف، ورصيدك بقى ' || v_balance || '.'
              when p_approve
                then 'اتوافق على طلبك واتخصم ' || v_amount || ' من رصيدك.'
              else 'طلبك بـ ' || v_amount || ' ماتوافقش عليه.'
            end);
  end if;

  perform set_config('zad.family_ledger', 'off', true);

  return jsonb_build_object(
    'ok', true, 'already', false, 'status', v_status,
    'kind', case when v_allowance then 'allowance' else 'purchase' end,
    'credited', case when p_approve and v_allowance and v_sender is not null
                     then v_amount else 0 end,
    'debited', case when p_approve and not v_allowance and v_sender is not null
                    then v_amount else 0 end,
    'balance', v_balance);
end;
$$;

-- ── A parent sends an allowance without being asked ──────────────────────────

create or replace function public.zad_send_allowance(p_member uuid, p_amount numeric)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_family uuid;
  v_user uuid;
  v_balance numeric;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_member is null or p_amount is null or p_amount <= 0 or p_amount > 1000000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  select family_id, user_id into v_family, v_user
  from public.family_members where id = p_member for update;
  if not found or not exists (
    select 1 from public.family_members
    where user_id = auth.uid() and family_id = v_family
  ) then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if not public.zad_is_family_admin(v_family) then
    return jsonb_build_object('ok', false, 'reason', 'not_an_admin');
  end if;

  perform set_config('zad.family_ledger', 'on', true);

  update public.family_members
  set balance = coalesce(balance, 0) + p_amount
  where id = p_member
  returning balance into v_balance;

  if v_user is not null and v_user <> auth.uid() then
    insert into public.app_notifications (user_id, title, message)
    values (v_user, 'وصلك مصروف 💰',
            'اتحوّلك ' || p_amount || '، ورصيدك بقى ' || v_balance || '.');
  end if;

  perform set_config('zad.family_ledger', 'off', true);

  return jsonb_build_object('ok', true, 'balance', v_balance, 'credited', p_amount);
end;
$$;

revoke all on function public.zad_decide_purchase_request(uuid, boolean) from public, anon;
grant execute on function public.zad_decide_purchase_request(uuid, boolean) to authenticated;
revoke all on function public.zad_send_allowance(uuid, numeric) from public, anon;
grant execute on function public.zad_send_allowance(uuid, numeric) to authenticated;
