-- الباب الوحيد: مجال الإعدادات، zad_users (ZAD_OR_PLAN م٢.٥، ٢٢/١١). أدوات العقل اللي بتغيّر إعدادات العميل بتكتب من هنا بس.
--
--   settings.cycle_start_set      {day}                يوم بداية الدورة (١–٣١). cycle_anchor مابيتلمسش.
--   settings.market_set           {currency, country}  كود عملة ISO (٣ حروف كابيتال) وكود بلد (حرفين كابيتال).
--   settings.emergency_fund_set   {balance}            رصيد صندوق الطوارئ: رقم من ٠ لـ١٠٠ مليون (بيتقرّب لقرشين).
--   settings.sleep_set            {bed, wake}          HH:MM، النوم من ٢٠:٠٠ لـ٠٣:٠٠ والصحيان من ٠٤:٠٠ لـ١٢:٠٠، المصدر manual.
--   settings.sleep_cleared        {}                   يمسح مواعيد النوم (المتعلّم واليدوي).
--   settings.app_flag_set         {setting, on}        pet_calls | food_pattern ⇐ pet_calls_enabled | food_pattern_enabled.
--
-- عمود واحد أو مجموعة أعمدة معروفة لكل نوع (مفيش patch حر)، والحدث شايل القديم (before) والجديد (after) من نفس الأعمدة.
-- الصف هو صف العميل نفسه (id = المستخدم). limit_set بتاع الرصيد فضل في مجال الفلوس (20261122020000).
-- اللي فضل بيكتب zad_users مباشرة: ختم آخر موقع/نشاط من التطبيق والكرون، ومزامنة الموبايل لإيقاع النوم المتعلّم
-- (zad_set_sleep_window، RPC بـauth.uid()) — مش أدوات موديل.

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
    if v_day is null or v_day not between 1 and 31 then
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
