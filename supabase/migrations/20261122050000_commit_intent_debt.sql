-- الباب الوحيد: مجال الديون (ZAD_OR_PLAN م٢.٥، ٢٢/١١). الأنواع:
--   debt.added    {name, remaining_balance, minimum_payment?, interest_rate?, due_day?}   الاسم ٢–١٢٠، الرصيد > ٠ و≤ ١٠٠ مليون،
--                                                                                         الحد الأدنى ≥ ٠، اليوم ١–٣١. principal = الرصيد.
--   debt.updated  {item_id, patch:{remaining_balance, minimum_payment, is_active}}         الرصيد ≥ ٠ (صفر = الدين خلص، والأداة بتبعت is_active=false)
--   debt.deleted  {item_id}                                                               حذف فعلي، والصف كامل في before
-- الصف بيتدوّر عليه بـ id + user_id، ومش موجود/بتاع حد تاني = item_not_found.

create or replace function public.zad_intent_debt(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_patch jsonb;
  v_row public.zad_debts%rowtype;
  v_key text;
  v_name text;
  v_balance numeric;
  v_min numeric;
  v_rate numeric;
  v_day int;
  v_row_id uuid;
begin
  if p_kind not in ('debt.added', 'debt.updated', 'debt.deleted') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind in ('debt.updated', 'debt.deleted') then
    begin
      select * into v_row from public.zad_debts
       where id = (v_payload ->> 'item_id')::uuid and user_id = p_uid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
  end if;

  if p_kind = 'debt.added' then
    v_name := btrim(coalesce(v_payload ->> 'name', ''));
    if length(v_name) not between 2 and 120 then
      return jsonb_build_object('ok', false, 'reason', 'debt_name_invalid');
    end if;
    begin
      v_balance := round((v_payload ->> 'remaining_balance')::numeric, 2);
    exception when others then
      v_balance := null;
    end;
    if v_balance is null or v_balance <= 0 then
      return jsonb_build_object('ok', false, 'reason', 'amount_not_positive');
    elsif v_balance > 100000000 then
      return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
    end if;
    begin
      v_min := round(coalesce(nullif(v_payload ->> 'minimum_payment', ''), '0')::numeric, 2);
    exception when others then
      v_min := null;
    end;
    if v_min is null or v_min < 0 then
      return jsonb_build_object('ok', false, 'reason', 'minimum_invalid');
    elsif v_min > 100000000 then
      return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
    end if;
    begin
      v_rate := coalesce(nullif(v_payload ->> 'interest_rate', '')::numeric, 0);
    exception when others then
      v_rate := null;
    end;
    if v_rate is null or v_rate < 0 or v_rate > 1000 then
      return jsonb_build_object('ok', false, 'reason', 'interest_invalid');
    end if;
    if nullif(v_payload ->> 'due_day', '') is not null then
      begin
        v_day := (v_payload ->> 'due_day')::int;
      exception when others then
        v_day := null;
      end;
      if v_day is null or v_day not between 1 and 31 then
        return jsonb_build_object('ok', false, 'reason', 'due_day_invalid');
      end if;
    end if;
    insert into public.zad_debts (user_id, name, principal_amount, remaining_balance, minimum_payment, interest_rate, due_day, is_active)
    values (p_uid, v_name, v_balance, v_balance, v_min, v_rate, v_day, true)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null,
      'after', (select to_jsonb(d) from public.zad_debts d where d.id = v_row_id));
  elsif p_kind = 'debt.updated' then
    v_patch := v_payload -> 'patch';
    if v_patch is null or jsonb_typeof(v_patch) <> 'object' or v_patch = '{}'::jsonb then
      return jsonb_build_object('ok', false, 'reason', 'patch_empty');
    end if;
    for v_key in select jsonb_object_keys(v_patch) loop
      if v_key not in ('remaining_balance', 'minimum_payment', 'is_active') then
        return jsonb_build_object('ok', false, 'reason', 'patch_field_unknown');
      end if;
    end loop;
    if v_patch ? 'remaining_balance' then
      begin
        v_balance := round((v_patch ->> 'remaining_balance')::numeric, 2);
      exception when others then
        v_balance := null;
      end;
      if v_balance is null or v_balance < 0 then
        return jsonb_build_object('ok', false, 'reason', 'balance_negative');
      elsif v_balance > 100000000 then
        return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
      end if;
    end if;
    if v_patch ? 'minimum_payment' then
      begin
        v_min := round((v_patch ->> 'minimum_payment')::numeric, 2);
      exception when others then
        v_min := null;
      end;
      if v_min is null or v_min < 0 then
        return jsonb_build_object('ok', false, 'reason', 'minimum_invalid');
      elsif v_min > 100000000 then
        return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
      end if;
    end if;
    if v_patch ? 'is_active' and jsonb_typeof(v_patch -> 'is_active') <> 'boolean' then
      return jsonb_build_object('ok', false, 'reason', 'is_active_invalid');
    end if;
    update public.zad_debts
       set remaining_balance = case when v_patch ? 'remaining_balance' then v_balance else remaining_balance end,
           minimum_payment = case when v_patch ? 'minimum_payment' then v_min else minimum_payment end,
           is_active = case when v_patch ? 'is_active' then (v_patch ->> 'is_active')::boolean else is_active end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row),
      'after', (select to_jsonb(d) from public.zad_debts d where d.id = v_row_id));
  else
    delete from public.zad_debts where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_debt(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
