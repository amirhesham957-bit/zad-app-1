-- P1.6b (مجموعة ٣، إعدادات الحساب): أزرار الإعدادات في فلاتر بتكتب zad_users من الباب بدل upsert مباشر.
--   * zad_intent_money_core = نسخة 20261128250000 (آخر تعريف) بس money.limit_set بيكتب balance_anchored_at = now() كمان مع
--     monthly_limit وlimit_confirmed_at: الرصيد بيبدأ يتحسب من لحظة ما العميل بيقوله (20260816120000)، وzad_budget_state بيقراه.
--     غلاف الكاش zad_intent_money (20261128210000) مااتلمسش.
--   * zad_intent_settings = نسخة 20261122100000 + settings.cycle_start_set بـday = null صريح بيرجّع لشهر التقويم (زي زرار المسح القديم).
--   * zad_commit_my_intent = نسخة 20261129010000 + settings.cycle_start_set وsettings.market_set وsettings.app_flag_set.
--   * مراية zad_user_budget (20261128260000): تريجر after update of على نفس أعمدة zad_users اللي الباب بيكتبها، فالمراية بتمشي
--     لوحدها مع كل كتابة من الباب (الاختبار بيتأكد). مفيش تعديل عليها هنا.
--   * اللي فضل مباشر: name/avatar_uri (ملف شخصي، مفيش نوع ليه)، ختم الموقع/النشاط، zad_set_sleep_window (RPC بـauth.uid() للنوم المتعلّم).

create or replace function public.zad_intent_money_core(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_patch jsonb;
  v_row public.zad_transactions%rowtype;
  v_reason text;
  v_key text;
  v_kind text;
  v_at timestamptz;
  v_row_id uuid;
  v_before jsonb := '{}'::jsonb;
  v_buy jsonb;
  v_amount numeric;
  v_category text;
  v_cap public.zad_category_budgets%rowtype;
  v_new_id uuid;
begin
  if p_kind not in ('money.logged', 'money.updated', 'money.deleted', 'money.purchase', 'money.limit_set',
                    'money.category_budget_set') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind in ('money.updated', 'money.deleted') then
    begin
      select * into v_row from public.zad_transactions
       where id = (v_payload ->> 'item_id')::uuid and user_id = p_uid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
  end if;

  if p_kind = 'money.logged' then
    v_reason := public.zad_intent_money_fields(v_payload, true);
    if v_reason is null and nullif(v_payload ->> 'created_at', '') is not null then
      v_at := (v_payload ->> 'created_at')::timestamptz;
      if v_at > now() + interval '5 minutes' or v_at < now() - interval '1 year' then
        v_reason := 'date_invalid';
      end if;
    end if;
    if v_reason is not null then
      return jsonb_build_object('ok', false, 'reason', v_reason);
    end if;
    v_kind := v_payload ->> 'txn_kind';
    -- P1.6b: العميل (الـOutbox) بيختار id الصف. لو الصف ده بتاعي موجود فالنية اتطبقت قبل كده بمفتاح تاني: رجّعه من غير
    -- كتابة. لو بتاع حد تاني أو id مش UUID: item_not_found (من غير ما نقول إنه موجود).
    if nullif(v_payload ->> 'item_id', '') is not null then
      begin
        v_new_id := (v_payload ->> 'item_id')::uuid;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'item_not_found');
      end;
      select * into v_row from public.zad_transactions where id = v_new_id;
      if v_row.id is not null then
        if v_row.user_id <> p_uid then
          return jsonb_build_object('ok', false, 'reason', 'item_not_found');
        end if;
        return jsonb_build_object('ok', true, 'row_id', v_row.id,
          'payload', v_payload || jsonb_build_object('row_id', v_row.id, 'after', to_jsonb(v_row), 'replayed', true));
      end if;
    end if;
    insert into public.zad_transactions (id, user_id, amount, title, category, is_expense, txn_kind, wallet, transfer_to,
                                         source_type, merchant_name, for_person, counts_toward_budget, currency, created_at)
    values (coalesce(v_new_id, gen_random_uuid()), p_uid, round((v_payload ->> 'amount')::numeric, 2), btrim(v_payload ->> 'title'),
            nullif(btrim(coalesce(v_payload ->> 'category', '')), ''),
            -- العمودين مع بعض دايماً (التطبيق بيقرا is_expense والسيرفر txn_kind). التحويل مصروف من ناحية المحفظة.
            v_kind <> 'income', v_kind, coalesce(nullif(v_payload ->> 'wallet', ''), 'card'),
            case when v_kind = 'transfer' then v_payload ->> 'transfer_to' end,
            nullif(v_payload ->> 'source_type', ''), nullif(btrim(coalesce(v_payload ->> 'merchant_name', '')), ''),
            case when v_kind = 'expense' then nullif(btrim(coalesce(v_payload ->> 'for_person', '')), '') end,
            coalesce((v_payload ->> 'counts_toward_budget')::boolean, true),
            case when coalesce(v_payload ->> 'currency', '') ~ '^[A-Z]{3}$' then v_payload ->> 'currency' end,
            coalesce(v_at, now()))
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'after',
      (select to_jsonb(t) from public.zad_transactions t where t.id = v_row_id));
  elsif p_kind = 'money.updated' then
    v_patch := v_payload -> 'patch';
    if v_patch is null or jsonb_typeof(v_patch) <> 'object' or v_patch = '{}'::jsonb then
      return jsonb_build_object('ok', false, 'reason', 'patch_empty');
    end if;
    for v_key in select jsonb_object_keys(v_patch) loop
      if v_key not in ('amount', 'title', 'category', 'txn_kind', 'for_person', 'merchant_name', 'counts_toward_budget') then
        return jsonb_build_object('ok', false, 'reason', 'patch_field_unknown');
      end if;
      v_before := v_before || jsonb_build_object(v_key, to_jsonb(v_row) -> v_key);
    end loop;
    v_reason := public.zad_intent_money_fields(v_patch, false);
    -- تحويل محتاج «رايح فين»، والتعديل مايقدرش يقوله: من وإلى تحويل بيتسجل معاملة جديدة.
    if v_reason is null and (v_patch ->> 'txn_kind' = 'transfer' or (v_row.txn_kind = 'transfer' and v_patch ? 'txn_kind')) then
      v_reason := 'transfer_change_unsupported';
    end if;
    if v_reason is not null then
      return jsonb_build_object('ok', false, 'reason', v_reason);
    end if;
    update public.zad_transactions
       set amount = case when v_patch ? 'amount' then round((v_patch ->> 'amount')::numeric, 2) else amount end,
           title = case when v_patch ? 'title' then btrim(v_patch ->> 'title') else title end,
           category = case when v_patch ? 'category' then nullif(btrim(coalesce(v_patch ->> 'category', '')), '') else category end,
           txn_kind = coalesce(v_patch ->> 'txn_kind', txn_kind),
           is_expense = case when v_patch ? 'txn_kind' then (v_patch ->> 'txn_kind') <> 'income' else is_expense end,
           for_person = case when v_patch ? 'for_person' then nullif(btrim(coalesce(v_patch ->> 'for_person', '')), '') else for_person end,
           merchant_name = case when v_patch ? 'merchant_name' then nullif(btrim(coalesce(v_patch ->> 'merchant_name', '')), '') else merchant_name end,
           counts_toward_budget = case when v_patch ? 'counts_toward_budget' then (v_patch ->> 'counts_toward_budget')::boolean else counts_toward_budget end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_before, 'after',
      (select to_jsonb(t) from public.zad_transactions t where t.id = v_row_id));
  elsif p_kind = 'money.deleted' then
    delete from public.zad_transactions where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  elsif p_kind = 'money.limit_set' then
    -- رصيد الدورة (الاسم تاريخي: monthly_limit). limit_confirmed_at بيتكتب لأنه فعل العميل بتأكيده.
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
    select jsonb_build_object('monthly_limit', u.monthly_limit, 'limit_confirmed_at', u.limit_confirmed_at, 'balance_anchored_at', u.balance_anchored_at)
      into v_before from public.zad_users u where u.id = p_uid for update;
    update public.zad_users set monthly_limit = v_amount, limit_confirmed_at = now(), balance_anchored_at = now() where id = p_uid;
    v_row_id := p_uid;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_before,
      'after', jsonb_build_object('monthly_limit', v_amount));
  elsif p_kind = 'money.category_budget_set' then
    -- سقف فئة واحدة؛ صفر بيشيله.
    v_category := btrim(coalesce(v_payload ->> 'category', ''));
    begin
      v_amount := round((v_payload ->> 'amount')::numeric, 2);
    exception when others then
      v_amount := null;
    end;
    if length(v_category) not between 2 and 40 then
      return jsonb_build_object('ok', false, 'reason', 'category_invalid');
    elsif v_amount is null or v_amount < 0 then
      return jsonb_build_object('ok', false, 'reason', 'amount_not_positive');
    elsif v_amount > 100000000 then
      return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
    end if;
    select * into v_cap from public.zad_category_budgets where user_id = p_uid and category = v_category for update;
    if v_amount = 0 then
      if v_cap.id is null then
        return jsonb_build_object('ok', false, 'reason', 'no_category_budget');
      end if;
      delete from public.zad_category_budgets where id = v_cap.id;
      v_row_id := v_cap.id;
      v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_cap), 'after', null);
    else
      insert into public.zad_category_budgets (user_id, category, amount, updated_at)
      values (p_uid, v_category, v_amount, now())
      on conflict (user_id, category) do update set amount = excluded.amount, updated_at = excluded.updated_at
      returning id into v_row_id;
      v_payload := v_payload || jsonb_build_object('row_id', v_row_id,
        'before', case when v_cap.id is null then null else to_jsonb(v_cap) end,
        'after', (select to_jsonb(c) from public.zad_category_budgets c where c.id = v_row_id));
    end if;
  else
    if jsonb_typeof(v_payload -> 'purchase') <> 'object' then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end if;
    v_reason := public.zad_intent_money_fields(
      (v_payload -> 'purchase') || jsonb_build_object('txn_kind', 'expense'), true);
    if v_reason is not null then
      return jsonb_build_object('ok', false, 'reason', v_reason);
    end if;
    v_buy := public.zad_record_purchase_service(p_uid, v_payload -> 'purchase');
    if (v_buy ->> 'ok')::boolean is not true or nullif(v_buy ->> 'transaction_id', '') is null then
      return jsonb_build_object('ok', false,
        'reason', 'purchase_' || coalesce(v_buy ->> 'status', v_buy ->> 'reason', 'refused'), 'detail', v_buy);
    end if;
    v_row_id := (v_buy ->> 'transaction_id')::uuid;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'after', v_buy);
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;


revoke all on function public.zad_intent_money_core(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;

create or replace function public.zad_intent_settings(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_row public.zad_users%rowtype;
  v_before jsonb;
  v_day int;
  v_amount numeric;
  v_bed time;
  v_wake time;
  v_flag text;
  v_on boolean;
  c_hhmm constant text := '^([01][0-9]|2[0-3]):[0-5][0-9]$';
begin
  if p_kind not in ('settings.cycle_start_set', 'settings.market_set', 'settings.emergency_fund_set', 'settings.sleep_set',
                    'settings.sleep_cleared', 'settings.app_flag_set') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  select * into v_row from public.zad_users where id = p_uid for update;
  if v_row.id is null then
    return jsonb_build_object('ok', false, 'reason', 'user_not_found');
  end if;

  if p_kind = 'settings.cycle_start_set' then
    begin
      v_day := (v_payload ->> 'day')::numeric::int;
      if (v_payload ->> 'day')::numeric <> v_day then v_day := null; end if;
    exception when others then
      v_day := null;
    end;
    if jsonb_typeof(v_payload -> 'day') = 'null' then
      v_day := null; -- day صريح = null: يرجّع لشهر التقويم
    elsif v_day is null or v_day not between 1 and 31 then
      return jsonb_build_object('ok', false, 'reason', 'cycle_day_invalid');
    end if;
    v_before := jsonb_build_object('cycle_start_day', v_row.cycle_start_day);
    update public.zad_users set cycle_start_day = v_day where id = p_uid;
    v_payload := v_payload || jsonb_build_object('row_id', p_uid, 'before', v_before,
      'after', jsonb_build_object('cycle_start_day', v_day));

  elsif p_kind = 'settings.market_set' then
    if coalesce(v_payload ->> 'currency', '') !~ '^[A-Z]{3}$' then
      return jsonb_build_object('ok', false, 'reason', 'currency_invalid');
    elsif coalesce(v_payload ->> 'country', '') !~ '^[A-Z]{2}$' then
      return jsonb_build_object('ok', false, 'reason', 'country_invalid');
    end if;
    v_before := jsonb_build_object('currency', v_row.currency, 'country', v_row.country);
    update public.zad_users set currency = v_payload ->> 'currency', country = v_payload ->> 'country' where id = p_uid;
    v_payload := v_payload || jsonb_build_object('row_id', p_uid, 'before', v_before,
      'after', jsonb_build_object('currency', v_payload ->> 'currency', 'country', v_payload ->> 'country'));

  elsif p_kind = 'settings.emergency_fund_set' then
    begin
      v_amount := round((v_payload ->> 'balance')::numeric, 2);
    exception when others then
      v_amount := null;
    end;
    if v_amount is null or v_amount < 0 then
      return jsonb_build_object('ok', false, 'reason', 'balance_invalid');
    elsif v_amount > 100000000 then
      return jsonb_build_object('ok', false, 'reason', 'amount_over_cap');
    end if;
    v_before := jsonb_build_object('emergency_fund_balance', v_row.emergency_fund_balance);
    update public.zad_users set emergency_fund_balance = v_amount where id = p_uid;
    v_payload := v_payload || jsonb_build_object('row_id', p_uid, 'before', v_before,
      'after', jsonb_build_object('emergency_fund_balance', v_amount));

  elsif p_kind = 'settings.sleep_set' then
    if coalesce(v_payload ->> 'bed', '') !~ c_hhmm or coalesce(v_payload ->> 'wake', '') !~ c_hhmm then
      return jsonb_build_object('ok', false, 'reason', 'sleep_time_invalid');
    end if;
    v_bed := (v_payload ->> 'bed')::time;
    v_wake := (v_payload ->> 'wake')::time;
    if not (v_bed >= time '20:00' or v_bed <= time '03:00') then
      return jsonb_build_object('ok', false, 'reason', 'sleep_bed_out_of_range');
    elsif v_wake not between time '04:00' and time '12:00' then
      return jsonb_build_object('ok', false, 'reason', 'sleep_wake_out_of_range');
    end if;
    v_before := jsonb_build_object('sleep_bed', v_row.sleep_bed, 'sleep_wake', v_row.sleep_wake,
      'sleep_nights', v_row.sleep_nights, 'sleep_source', v_row.sleep_source);
    update public.zad_users
       set sleep_bed = v_bed, sleep_wake = v_wake, sleep_nights = null, sleep_source = 'manual', sleep_updated_at = now()
     where id = p_uid;
    v_payload := v_payload || jsonb_build_object('row_id', p_uid, 'before', v_before,
      'after', jsonb_build_object('sleep_bed', v_bed, 'sleep_wake', v_wake, 'sleep_source', 'manual'));

  elsif p_kind = 'settings.sleep_cleared' then
    v_before := jsonb_build_object('sleep_bed', v_row.sleep_bed, 'sleep_wake', v_row.sleep_wake,
      'sleep_nights', v_row.sleep_nights, 'sleep_source', v_row.sleep_source);
    update public.zad_users
       set sleep_bed = null, sleep_wake = null, sleep_nights = null, sleep_source = null, sleep_updated_at = now()
     where id = p_uid;
    v_payload := v_payload || jsonb_build_object('row_id', p_uid, 'before', v_before,
      'after', jsonb_build_object('sleep_bed', null, 'sleep_wake', null, 'sleep_source', null));

  else
    v_flag := v_payload ->> 'setting';
    if v_flag not in ('pet_calls', 'food_pattern') then
      return jsonb_build_object('ok', false, 'reason', 'setting_unknown');
    elsif jsonb_typeof(v_payload -> 'on') <> 'boolean' then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end if;
    v_on := (v_payload ->> 'on')::boolean;
    if v_flag = 'pet_calls' then
      v_before := jsonb_build_object('pet_calls_enabled', v_row.pet_calls_enabled);
      update public.zad_users set pet_calls_enabled = v_on where id = p_uid;
      v_payload := v_payload || jsonb_build_object('row_id', p_uid, 'before', v_before,
        'after', jsonb_build_object('pet_calls_enabled', v_on));
    else
      v_before := jsonb_build_object('food_pattern_enabled', v_row.food_pattern_enabled);
      update public.zad_users set food_pattern_enabled = v_on where id = p_uid;
      v_payload := v_payload || jsonb_build_object('row_id', p_uid, 'before', v_before,
        'after', jsonb_build_object('food_pattern_enabled', v_on));
    end if;
  end if;
  return jsonb_build_object('ok', true, 'row_id', p_uid, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_settings(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;

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
                                      'subscription.added', 'subscription.updated', 'subscription.deleted',
                                      'settings.cycle_start_set', 'settings.market_set', 'settings.app_flag_set') then
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
