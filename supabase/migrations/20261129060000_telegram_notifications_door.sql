-- P1.6b (مجموعة ٧، تيليجرام والإشعارات): مفاتيح قراءة الإشعارات وفك ربط تيليجرام بيعدوا من zad_commit_my_intent.
--   * zad_intent_settings = نسخة 20261129020000 + settings.notification_switch_set وsettings.telegram_unlinked.
--   * zad_commit_my_intent = نسخة 20261129020000 + النوعين دول. zad_commit_intent مااتلمسش (مجال settings موجود).
--   * اللي فضل مباشر: توليد كود الربط (insert في telegram_bindings). الكود هو الإثبات الوحيد لهوية الشات
--     (20260927120000)، ومايتكتبش في zad_events لأنه دفتر بيتقرا ويتنسخ؛ وسياسة RLS بتحصره على صف من غير chat_id.

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
  v_kind text;
  v_bound int;
  v_rows int;
  c_hhmm constant text := '^([01][0-9]|2[0-3]):[0-5][0-9]$';
begin
  if p_kind not in ('settings.cycle_start_set', 'settings.market_set', 'settings.emergency_fund_set', 'settings.sleep_set',
                    'settings.sleep_cleared', 'settings.app_flag_set',
                    'settings.notification_switch_set', 'settings.telegram_unlinked') then
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

  elsif p_kind = 'settings.notification_switch_set' then
    v_kind := v_payload ->> 'kind';
    if v_kind is null or v_kind not in ('appointment', 'trip', 'document_due') then
      return jsonb_build_object('ok', false, 'reason', 'notification_kind_invalid');
    elsif jsonb_typeof(v_payload -> 'enabled') <> 'boolean' then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end if;
    v_on := (v_payload ->> 'enabled')::boolean;
    select jsonb_build_object('enabled', s.enabled, 'enabled_at', s.enabled_at) into v_before
      from public.zad_notification_switches s where s.user_id = p_uid and s.kind = v_kind for update;
    insert into public.zad_notification_switches (user_id, kind, enabled, enabled_at)
    values (p_uid, v_kind, v_on, case when v_on then now() end)
    on conflict (user_id, kind) do update set enabled = excluded.enabled, enabled_at = excluded.enabled_at;
    v_payload := v_payload || jsonb_build_object('row_id', p_uid, 'before', v_before,
      'after', jsonb_build_object('kind', v_kind, 'enabled', v_on));

  elsif p_kind = 'settings.telegram_unlinked' then
    select count(*), count(*) filter (where bound_at is not null) into v_rows, v_bound
      from public.telegram_bindings where user_id = p_uid;
    delete from public.telegram_bindings where user_id = p_uid;
    v_payload := v_payload || jsonb_build_object('row_id', p_uid,
      'before', jsonb_build_object('rows', v_rows, 'bound', v_bound), 'after', null);

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
                                      'settings.cycle_start_set', 'settings.market_set', 'settings.app_flag_set',
                                      'settings.notification_switch_set', 'settings.telegram_unlinked') then
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
