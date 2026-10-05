-- وقفة التفكير قبل الشرا (ZAD_LIVING_BRAIN.md §١٠ والشريحة ٣٦، قرار المالك ٢٠٢٦-١٠-٠٥).
--
-- «رادار تفادي الشراء العاطفي: تجميد طلب المشتريات غير الطارئة لمدة ٢٤ ساعة لمراجعة قرار الشراء». العيلة بتشغّلها
-- (المسؤول بس): طلب **شرا** من فرد (مش طلب مصروف) مايتوافقش عليه قبل ما يعدّي عليه ٢٤ ساعة من وقت ما اتبعت. الرفض في
-- أي وقت، والمسؤول يقدر يقفل الوقفة. افتراضي مقفولة — مفيش عيلة سلوكها اتغيّر من غير ما تختار.
--
-- الحارس في السيرفر نفسه (zad_decide_purchase_request)، مش زرار متعطّل في التطبيق: تليجرام أو نسخة قديمة مايعدّوهاش.
-- الدالة دي نسخة 20260928180000_allowance_is_a_credit.sql بالظبط، والفرق الوحيد بلوك الوقفة قبل فحص الرصيد.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد: جلسات تانية شغالة بتاخد الساعات المدوّرة (اتصادمنا مرتين ٢٠٢٦-١٠-٠٥).

alter table public.family_groups
  add column if not exists purchase_pause_hours smallint not null default 0;
alter table public.family_groups drop constraint if exists family_groups_purchase_pause_hours_check;
alter table public.family_groups
  add constraint family_groups_purchase_pause_hours_check check (purchase_pause_hours in (0, 24));

-- المسؤول بس، لعيلته هو. بترجّع الساعات الجديدة.
create or replace function public.zad_set_purchase_pause(p_on boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_family uuid;
  v_hours smallint := case when p_on then 24 else 0 end;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_on is null then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;
  select family_id into v_family from public.family_members where user_id = auth.uid() limit 1;
  if v_family is null then
    return jsonb_build_object('ok', false, 'reason', 'no_family');
  end if;
  if not public.zad_is_family_admin(v_family) then
    return jsonb_build_object('ok', false, 'reason', 'not_an_admin');
  end if;
  update public.family_groups set purchase_pause_hours = v_hours where id = v_family;
  return jsonb_build_object('ok', true, 'hours', v_hours);
end;
$$;

revoke all on function public.zad_set_purchase_pause(boolean) from public, anon;
grant execute on function public.zad_set_purchase_pause(boolean) to authenticated;

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
  v_pause smallint;
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

  -- وقفة التفكير (20261005231147): شرا مش مصروف، والعيلة مشغّلاها، والطلب لسه ماكملش المدة ⇒ يفضل معلّق.
  -- الرفض مسموح في أي وقت، والمسؤول يقدر يقفل الوقفة نفسها (zad_set_purchase_pause).
  select coalesce(purchase_pause_hours, 0) into v_pause from public.family_groups where id = v_msg.family_id;
  if p_approve and not v_allowance and coalesce(v_pause, 0) > 0
     and v_msg.created_at > now() - make_interval(hours => v_pause) then
    return jsonb_build_object(
      'ok', false, 'reason', 'cooling_off',
      'ready_at', v_msg.created_at + make_interval(hours => v_pause));
  end if;

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

revoke all on function public.zad_decide_purchase_request(uuid, boolean) from public, anon;
grant execute on function public.zad_decide_purchase_request(uuid, boolean) to authenticated;
