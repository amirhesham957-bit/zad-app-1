-- P1.6b (ديون/التزامات/اشتراكات): أزرارهم في فلاتر بتكتب من الباب بدل الجدول.
--   * zad_intent_obligation = نسخة 20261122060000 + item_id اختياري في obligation.added (id الصف من الـOutbox، وتكراره = رجّع
--     الصف من غير كتابة) + due_date، وpatch في obligation.updated يقبل title/amount/kind/recurrence/due_day/due_date/confirmed/
--     active (due_day وdue_date بـnull = مسح). نوع جديد obligation.deleted (حذف فعلي، زي زرار الحذف اللي كان بيمسح الصف).
--   * zad_intent_subscription = نسخة 20261122040000 + item_id اختياري في subscription.added + due_day/type/provider/auto_deduct (النوع حروف صغيرة وشرطة سفلية، لأن القديم متنوع)،
--     والدورة WEEKLY كمان، وpatch يقبل category/billing_cycle/type/provider/auto_deduct. التاريخ بياخد أول ١٠ حروف.
--   * zad_intent_debt من غير تغيير: التطبيق بيعدّي من debt.added/updated/deleted زي ما هي.
--   * zad_commit_my_intent = نسخة 20261128250000 + الأنواع الجديدة. المصدر manual دايماً والمستخدم auth.uid() بس.

create or replace function public.zad_intent_obligation(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_patch jsonb;
  v_row public.zad_obligations%rowtype;
  v_key text;
  v_title text;
  v_amount numeric;
  v_kind text;
  v_recurrence text;
  v_day int;
  v_date text;
  v_provider text;
  v_total int;
  v_row_id uuid;
  v_new_id uuid;
begin
  if p_kind not in ('obligation.added', 'obligation.updated', 'obligation.deactivated', 'obligation.deleted') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind in ('obligation.updated', 'obligation.deactivated', 'obligation.deleted') then
    begin
      select * into v_row from public.zad_obligations
       where id = (v_payload ->> 'item_id')::uuid and user_id = p_uid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
  end if;

  if p_kind = 'obligation.added' then
    -- العميل (الـOutbox) بيختار id الصف. لو الصف ده بتاعي موجود فالنية اتطبقت قبل كده بمفتاح تاني: رجّعه من غير كتابة.
    -- لو بتاع حد تاني أو id مش UUID: item_not_found (من غير ما نقول إنه موجود).
    if nullif(v_payload ->> 'item_id', '') is not null then
      begin
        v_new_id := (v_payload ->> 'item_id')::uuid;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'item_not_found');
      end;
      select * into v_row from public.zad_obligations where id = v_new_id;
      if v_row.id is not null then
        if v_row.user_id <> p_uid then
          return jsonb_build_object('ok', false, 'reason', 'item_not_found');
        end if;
        return jsonb_build_object('ok', true, 'row_id', v_row.id,
          'payload', v_payload || jsonb_build_object('row_id', v_row.id, 'after', to_jsonb(v_row), 'replayed', true));
      end if;
    end if;
    v_title := btrim(coalesce(v_payload ->> 'title', ''));
    if length(v_title) not between 2 and 120 then
      return jsonb_build_object('ok', false, 'reason', 'obligation_title_invalid');
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
    v_kind := v_payload ->> 'kind';
    if v_kind is null or v_kind not in ('rent', 'installment', 'debt', 'tuition', 'utility', 'other') then
      return jsonb_build_object('ok', false, 'reason', 'obligation_kind_invalid');
    end if;
    v_recurrence := coalesce(nullif(v_payload ->> 'recurrence', ''), 'monthly');
    if v_recurrence not in ('monthly', 'quarterly', 'yearly', 'once') then
      return jsonb_build_object('ok', false, 'reason', 'recurrence_invalid');
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
    v_date := nullif(v_payload ->> 'due_date', '');
    if v_date is not null then
      begin
        if v_date !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'bad'; end if;
        perform v_date::date;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'due_date_invalid');
      end;
    end if;
    v_provider := nullif(btrim(coalesce(v_payload ->> 'provider', '')), '');
    if v_provider is not null and v_provider not in ('تابي', 'تمارة', 'فاليو') then
      v_provider := null;
    end if;
    -- عدد الأقساط له معنى مع مزوّد تقسيط بس، وهو اللي المتبقي منه بيبدأ.
    if v_provider is not null and nullif(v_payload ->> 'total_installments', '') is not null then
      begin
        v_total := round((v_payload ->> 'total_installments')::numeric)::int;
      exception when others then
        v_total := null;
      end;
      if v_total is null or v_total <= 0 or v_total > 600 then
        return jsonb_build_object('ok', false, 'reason', 'installments_invalid');
      end if;
    end if;
    insert into public.zad_obligations (id, user_id, title, amount, kind, recurrence, due_day, due_date, auto_detected, confirmed,
                                        active, provider, total_installments, remaining_installments)
    values (coalesce(v_new_id, gen_random_uuid()), p_uid, v_title, v_amount, v_kind, v_recurrence, v_day, v_date::date,
            coalesce((v_payload ->> 'auto_detected')::boolean, false), coalesce((v_payload ->> 'confirmed')::boolean, true), true,
            v_provider, v_total, v_total)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null,
      'after', (select to_jsonb(o) from public.zad_obligations o where o.id = v_row_id));
  elsif p_kind = 'obligation.updated' then
    v_patch := v_payload -> 'patch';
    if v_patch is null or jsonb_typeof(v_patch) <> 'object' or v_patch = '{}'::jsonb then
      return jsonb_build_object('ok', false, 'reason', 'patch_empty');
    end if;
    for v_key in select jsonb_object_keys(v_patch) loop
      if v_key not in ('title', 'amount', 'kind', 'recurrence', 'due_day', 'due_date', 'confirmed', 'active') then
        return jsonb_build_object('ok', false, 'reason', 'patch_field_unknown');
      end if;
    end loop;
    if v_patch ? 'title' and length(btrim(coalesce(v_patch ->> 'title', ''))) not between 2 and 120 then
      return jsonb_build_object('ok', false, 'reason', 'obligation_title_invalid');
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
    if v_patch ? 'kind' and coalesce(v_patch ->> 'kind', '') not in ('rent', 'installment', 'debt', 'tuition', 'utility', 'other') then
      return jsonb_build_object('ok', false, 'reason', 'obligation_kind_invalid');
    end if;
    if v_patch ? 'recurrence' and coalesce(v_patch ->> 'recurrence', '') not in ('monthly', 'quarterly', 'yearly', 'once') then
      return jsonb_build_object('ok', false, 'reason', 'recurrence_invalid');
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
    if v_patch ? 'due_date' and nullif(v_patch ->> 'due_date', '') is not null then
      begin
        if v_patch ->> 'due_date' !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'bad'; end if;
        perform (v_patch ->> 'due_date')::date;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'due_date_invalid');
      end;
    end if;
    if v_patch ? 'confirmed' and jsonb_typeof(v_patch -> 'confirmed') <> 'boolean' then
      return jsonb_build_object('ok', false, 'reason', 'confirmed_invalid');
    end if;
    if v_patch ? 'active' and jsonb_typeof(v_patch -> 'active') <> 'boolean' then
      return jsonb_build_object('ok', false, 'reason', 'active_invalid');
    end if;
    update public.zad_obligations
       set title = case when v_patch ? 'title' then btrim(v_patch ->> 'title') else title end,
           amount = case when v_patch ? 'amount' then v_amount else amount end,
           kind = case when v_patch ? 'kind' then v_patch ->> 'kind' else kind end,
           recurrence = case when v_patch ? 'recurrence' then v_patch ->> 'recurrence' else recurrence end,
           due_day = case when v_patch ? 'due_day' then nullif(v_patch ->> 'due_day', '')::int else due_day end,
           due_date = case when v_patch ? 'due_date' then nullif(v_patch ->> 'due_date', '')::date else due_date end,
           confirmed = case when v_patch ? 'confirmed' then (v_patch ->> 'confirmed')::boolean else confirmed end,
           active = case when v_patch ? 'active' then (v_patch ->> 'active')::boolean else active end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row),
      'after', (select to_jsonb(o) from public.zad_obligations o where o.id = v_row_id));
  elsif p_kind = 'obligation.deleted' then
    delete from public.zad_obligations where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  else
    if not v_row.active then
      return jsonb_build_object('ok', false, 'reason', 'already_inactive');
    end if;
    update public.zad_obligations set active = false where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row),
      'after', (select to_jsonb(o) from public.zad_obligations o where o.id = v_row_id));
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_obligation(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;

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
  v_new_id uuid;
  v_day int;
  v_type text;
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
    if nullif(v_payload ->> 'item_id', '') is not null then
      begin
        v_new_id := (v_payload ->> 'item_id')::uuid;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'item_not_found');
      end;
      select * into v_row from public.zad_subscriptions where id = v_new_id;
      if v_row.id is not null then
        if v_row.user_id <> p_uid then
          return jsonb_build_object('ok', false, 'reason', 'item_not_found');
        end if;
        return jsonb_build_object('ok', true, 'row_id', v_row.id,
          'payload', v_payload || jsonb_build_object('row_id', v_row.id, 'after', to_jsonb(v_row), 'replayed', true));
      end if;
    end if;
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
        if v_date !~ '^\d{4}-\d{2}-\d{2}' then raise exception 'bad'; end if;
        v_date := substring(v_date from 1 for 10);
        perform v_date::date;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'renewal_date_invalid');
      end;
    end if;
    v_cycle := coalesce(nullif(v_payload ->> 'billing_cycle', ''), 'MONTHLY');
    if v_cycle not in ('MONTHLY', 'YEARLY', 'WEEKLY') then
      return jsonb_build_object('ok', false, 'reason', 'billing_cycle_invalid');
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
    v_type := coalesce(nullif(v_payload ->> 'type', ''), 'subscription');
    if v_type !~ '^[a-z_]{2,30}$' then
      return jsonb_build_object('ok', false, 'reason', 'subscription_type_invalid');
    end if;
    insert into public.zad_subscriptions (id, user_id, title, amount, renewal_date, category, billing_cycle, is_active, due_day,
                                          type, provider, auto_deduct)
    values (coalesce(v_new_id, gen_random_uuid()), p_uid, v_title, v_amount, v_date,
            nullif(btrim(coalesce(v_payload ->> 'category', '')), ''), v_cycle, true, v_day, v_type,
            nullif(btrim(coalesce(v_payload ->> 'provider', '')), ''),
            coalesce((v_payload ->> 'auto_deduct')::boolean, false))
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null,
      'after', (select to_jsonb(s) from public.zad_subscriptions s where s.id = v_row_id));
  elsif p_kind = 'subscription.updated' then
    v_patch := v_payload -> 'patch';
    if v_patch is null or jsonb_typeof(v_patch) <> 'object' or v_patch = '{}'::jsonb then
      return jsonb_build_object('ok', false, 'reason', 'patch_empty');
    end if;
    for v_key in select jsonb_object_keys(v_patch) loop
      if v_key not in ('title', 'amount', 'renewal_date', 'due_day', 'is_active', 'category', 'billing_cycle', 'type',
                       'provider', 'auto_deduct') then
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
        if v_patch ->> 'renewal_date' !~ '^\d{4}-\d{2}-\d{2}' then raise exception 'bad'; end if;
        perform substring(v_patch ->> 'renewal_date' from 1 for 10)::date;
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
    if v_patch ? 'billing_cycle' and coalesce(v_patch ->> 'billing_cycle', '') not in ('MONTHLY', 'YEARLY', 'WEEKLY') then
      return jsonb_build_object('ok', false, 'reason', 'billing_cycle_invalid');
    end if;
    if v_patch ? 'type' and coalesce(v_patch ->> 'type', '') !~ '^[a-z_]{2,30}$' then
      return jsonb_build_object('ok', false, 'reason', 'subscription_type_invalid');
    end if;
    if v_patch ? 'is_active' and jsonb_typeof(v_patch -> 'is_active') <> 'boolean' then
      return jsonb_build_object('ok', false, 'reason', 'is_active_invalid');
    end if;
    if v_patch ? 'auto_deduct' and jsonb_typeof(v_patch -> 'auto_deduct') <> 'boolean' then
      return jsonb_build_object('ok', false, 'reason', 'auto_deduct_invalid');
    end if;
    update public.zad_subscriptions
       set title = case when v_patch ? 'title' then btrim(v_patch ->> 'title') else title end,
           amount = case when v_patch ? 'amount' then v_amount else amount end,
           renewal_date = case when v_patch ? 'renewal_date' then substring(nullif(v_patch ->> 'renewal_date', '') from 1 for 10) else renewal_date end,
           due_day = case when v_patch ? 'due_day' then nullif(v_patch ->> 'due_day', '')::int else due_day end,
           category = case when v_patch ? 'category' then nullif(btrim(coalesce(v_patch ->> 'category', '')), '') else category end,
           billing_cycle = case when v_patch ? 'billing_cycle' then v_patch ->> 'billing_cycle' else billing_cycle end,
           type = case when v_patch ? 'type' then v_patch ->> 'type' else type end,
           provider = case when v_patch ? 'provider' then nullif(btrim(coalesce(v_patch ->> 'provider', '')), '') else provider end,
           auto_deduct = case when v_patch ? 'auto_deduct' then (v_patch ->> 'auto_deduct')::boolean else auto_deduct end,
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

create or replace function public.zad_commit_my_intent(
  p_kind text,
  p_client_event_id text,
  p_payload jsonb,
  p_occurred_at timestamptz default null,
  p_trace_id text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $w$
declare
  v_uid uuid := auth.uid();
  v_intent jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  end if;
  if p_kind is null or p_kind not in ('inventory.added', 'inventory.consumed', 'inventory.quantity_set',
                                      'inventory.rate_corrected',
                                      'money.logged', 'money.updated', 'money.deleted', 'money.limit_set',
                                      'money.category_budget_set', 'settings.emergency_fund_set',
                                      'debt.added', 'debt.updated', 'debt.deleted',
                                      'obligation.added', 'obligation.updated', 'obligation.deleted',
                                      'subscription.added', 'subscription.updated', 'subscription.deleted') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;
  if p_occurred_at is not null and p_occurred_at > now() + interval '1 hour' then
    return jsonb_build_object('ok', false, 'reason', 'bad_shape');
  end if;

  v_intent := jsonb_build_object(
    'kind', p_kind,
    'client_event_id', p_client_event_id,
    'source', 'manual',
    'payload', p_payload);
  if p_occurred_at is not null then
    v_intent := v_intent || jsonb_build_object('occurred_at', p_occurred_at);
  end if;
  if nullif(btrim(coalesce(p_trace_id, '')), '') is not null then
    v_intent := v_intent || jsonb_build_object('trace_id', btrim(p_trace_id));
  end if;
  return public.zad_commit_intent(v_intent);
end;
$w$;

revoke all on function public.zad_commit_my_intent(text, text, jsonb, timestamptz, text) from public, anon;
grant execute on function public.zad_commit_my_intent(text, text, jsonb, timestamptz, text) to authenticated, service_role;
