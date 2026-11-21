-- الباب الوحيد: مجال الاشتراكات (ZAD_OR_PLAN م٢.٥، ٢٢/١١). zad_intent_subscription(uid, kind, payload, occurred) بيراجع اللي كانت
-- أدوات العقل بتراجعه بإيدها وبيكتب الصف، والباب بيكتب الحدث معاه. الأنواع:
--   subscription.added    {title, amount, renewal_date?, category?, billing_cycle?}   العنوان ٢–١٢٠، المبلغ > ٠ و≤ ١٠٠ مليون،
--                                                                                  التاريخ YYYY-MM-DD، الدورة MONTHLY|YEARLY
--   subscription.updated  {item_id, patch:{title,amount,renewal_date,due_day,is_active}}   (تقديم التجديد بعد الدفع = تعديل برضه)
--   subscription.deleted  {item_id}                                                       حذف فعلي، والصف كامل في before
-- الصف بيتدوّر عليه بـ id + user_id، ومش موجود/بتاع حد تاني = item_not_found.

create or replace function public.zad_intent_subscription(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_patch jsonb;
  v_row public.zad_subscriptions%rowtype;
  v_key text;
  v_title text;
  v_amount numeric;
  v_cycle text;
  v_date text;
  v_row_id uuid;
  v_day int;
begin
  if p_kind not in ('subscription.added', 'subscription.updated', 'subscription.deleted') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind in ('subscription.updated', 'subscription.deleted') then
    begin
      select * into v_row from public.zad_subscriptions
       where id = (v_payload ->> 'item_id')::uuid and user_id = p_uid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
  end if;

  if p_kind = 'subscription.added' then
    v_title := btrim(coalesce(v_payload ->> 'title', ''));
    if length(v_title) not between 2 and 120 then
      return jsonb_build_object('ok', false, 'reason', 'subscription_title_invalid');
    end if;
    begin
      v_amount := round((v_payload ->> 'amount')::numeric, 2);
    exception when others then
      v_amount := null;
    end;
    if v_amount is null or v_amount <= 0 then
      return jsonb_build_object('ok', false, 'reason', 'amount_not_positive');
    elsif v_amount > 100000000 then
      return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
    end if;
    v_date := nullif(v_payload ->> 'renewal_date', '');
    if v_date is not null then
      begin
        if v_date !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'bad'; end if;
        perform v_date::date;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'renewal_date_invalid');
      end;
    end if;
    v_cycle := coalesce(nullif(v_payload ->> 'billing_cycle', ''), 'MONTHLY');
    if v_cycle not in ('MONTHLY', 'YEARLY') then
      return jsonb_build_object('ok', false, 'reason', 'billing_cycle_invalid');
    end if;
    insert into public.zad_subscriptions (user_id, title, amount, renewal_date, category, billing_cycle, is_active)
    values (p_uid, v_title, v_amount, v_date, nullif(btrim(coalesce(v_payload ->> 'category', '')), ''), v_cycle, true)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null,
      'after', (select to_jsonb(s) from public.zad_subscriptions s where s.id = v_row_id));
  elsif p_kind = 'subscription.updated' then
    v_patch := v_payload -> 'patch';
    if v_patch is null or jsonb_typeof(v_patch) <> 'object' or v_patch = '{}'::jsonb then
      return jsonb_build_object('ok', false, 'reason', 'patch_empty');
    end if;
    for v_key in select jsonb_object_keys(v_patch) loop
      if v_key not in ('title', 'amount', 'renewal_date', 'due_day', 'is_active') then
        return jsonb_build_object('ok', false, 'reason', 'patch_field_unknown');
      end if;
    end loop;
    if v_patch ? 'title' and length(btrim(coalesce(v_patch ->> 'title', ''))) not between 2 and 120 then
      return jsonb_build_object('ok', false, 'reason', 'subscription_title_invalid');
    end if;
    if v_patch ? 'amount' then
      begin
        v_amount := round((v_patch ->> 'amount')::numeric, 2);
      exception when others then
        v_amount := null;
      end;
      if v_amount is null or v_amount <= 0 then
        return jsonb_build_object('ok', false, 'reason', 'amount_not_positive');
      elsif v_amount > 100000000 then
        return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
      end if;
    end if;
    if v_patch ? 'renewal_date' and nullif(v_patch ->> 'renewal_date', '') is not null then
      begin
        if v_patch ->> 'renewal_date' !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'bad'; end if;
        perform (v_patch ->> 'renewal_date')::date;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'renewal_date_invalid');
      end;
    end if;
    if v_patch ? 'due_day' and nullif(v_patch ->> 'due_day', '') is not null then
      begin
        v_day := (v_patch ->> 'due_day')::int;
      exception when others then
        v_day := null;
      end;
      if v_day is null or v_day not between 1 and 31 then
        return jsonb_build_object('ok', false, 'reason', 'due_day_invalid');
      end if;
    end if;
    if v_patch ? 'is_active' and jsonb_typeof(v_patch -> 'is_active') <> 'boolean' then
      return jsonb_build_object('ok', false, 'reason', 'is_active_invalid');
    end if;
    update public.zad_subscriptions
       set title = case when v_patch ? 'title' then btrim(v_patch ->> 'title') else title end,
           amount = case when v_patch ? 'amount' then round((v_patch ->> 'amount')::numeric, 2) else amount end,
           renewal_date = case when v_patch ? 'renewal_date' then nullif(v_patch ->> 'renewal_date', '') else renewal_date end,
           due_day = case when v_patch ? 'due_day' then nullif(v_patch ->> 'due_day', '')::int else due_day end,
           is_active = case when v_patch ? 'is_active' then (v_patch ->> 'is_active')::boolean else is_active end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row),
      'after', (select to_jsonb(s) from public.zad_subscriptions s where s.id = v_row_id));
  else
    delete from public.zad_subscriptions where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_subscription(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
