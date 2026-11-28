-- P1.6b (مجموعة ٤، المواعيد): زراير «مواعيدي» في فلاتر بتكتب zad_appointments من الباب بدل upsert/update/delete مباشر.
--   * zad_intent_appointment = نسخة 20261122090000 + item_id اختياري في appointment.added (id الصف من الـOutbox، وتكراره = رجّع
--     الصف من غير كتابة؛ id بتاع حد تاني أو مش UUID = item_not_found). باقي الدالة (والقيود) زي ما هي.
--   * zad_commit_my_intent = نسخة 20261129020000 + appointment.added وappointment.updated وappointment.deleted.
--   * اللي فضل مباشر: تذكيرات الأماكن (zad_place_reminders: إضافة وإلغاء) وزيارات الأماكن (zad_place_visits: مسح) في
--     my_places_screen.dart. مفيش مجال «place» ورا الباب، وإنشاؤه خارج شريحة الزراير.

create or replace function public.zad_intent_appointment(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_patch jsonb;
  v_src jsonb;
  v_row public.zad_appointments%rowtype;
  v_row_id uuid;
  v_new_id uuid;
  v_before jsonb := '{}'::jsonb;
  v_key text;
  v_reason text;
begin
  if p_kind not in ('appointment.added', 'appointment.updated', 'appointment.deleted') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind in ('appointment.updated', 'appointment.deleted') then
    begin
      select * into v_row from public.zad_appointments
       where id = (v_payload ->> 'item_id')::uuid and user_id = p_uid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
  end if;

  if p_kind = 'appointment.added' then
    -- العميل (الـOutbox) بيختار id الصف. لو الصف ده بتاعي موجود فالنية اتطبقت قبل كده بمفتاح تاني: رجّعه من غير كتابة.
    -- لو بتاع حد تاني أو id مش UUID: item_not_found (من غير ما نقول إنه موجود).
    if nullif(v_payload ->> 'item_id', '') is not null then
      begin
        v_new_id := (v_payload ->> 'item_id')::uuid;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'item_not_found');
      end;
      select * into v_row from public.zad_appointments where id = v_new_id;
      if v_row.id is not null then
        if v_row.user_id <> p_uid then
          return jsonb_build_object('ok', false, 'reason', 'item_not_found');
        end if;
        return jsonb_build_object('ok', true, 'row_id', v_row.id,
          'payload', v_payload || jsonb_build_object('row_id', v_row.id, 'after', to_jsonb(v_row), 'replayed', true));
      end if;
    end if;
    v_src := jsonb_build_object('kind', 'personal', 'remind_minutes_before', 0, 'recurrence', 'once', 'source', 'chat') || v_payload;
    v_reason := public.zad_intent_appointment_fields(v_src, true);
    if v_reason is not null then
      return jsonb_build_object('ok', false, 'reason', v_reason);
    end if;
    insert into public.zad_appointments (id, user_id, title, kind, starts_at, place_label, remind_minutes_before, recurrence, source,
                                         for_person, expected_cost)
    values (coalesce(v_new_id, gen_random_uuid()), p_uid, btrim(v_src ->> 'title'), v_src ->> 'kind', (v_src ->> 'starts_at')::timestamptz,
            nullif(v_src ->> 'place_label', ''), (v_src ->> 'remind_minutes_before')::numeric::int, v_src ->> 'recurrence',
            v_src ->> 'source', nullif(btrim(coalesce(v_src ->> 'for_person', '')), ''),
            round((v_src ->> 'expected_cost')::numeric, 2))
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null,
      'after', (select to_jsonb(a) from public.zad_appointments a where a.id = v_row_id));
  elsif p_kind = 'appointment.updated' then
    v_patch := v_payload -> 'patch';
    if v_patch is null or jsonb_typeof(v_patch) <> 'object' or v_patch = '{}'::jsonb then
      return jsonb_build_object('ok', false, 'reason', 'patch_empty');
    end if;
    for v_key in select jsonb_object_keys(v_patch) loop
      if v_key not in ('status', 'starts_at', 'title', 'place_label', 'recurrence', 'remind_minutes_before', 'expected_cost') then
        return jsonb_build_object('ok', false, 'reason', 'patch_field_unknown');
      end if;
      v_before := v_before || jsonb_build_object(v_key, to_jsonb(v_row) -> v_key);
    end loop;
    v_reason := public.zad_intent_appointment_fields(v_patch, false);
    if v_reason is not null then
      return jsonb_build_object('ok', false, 'reason', v_reason);
    end if;
    update public.zad_appointments
       set status = case when v_patch ? 'status' then v_patch ->> 'status' else status end,
           starts_at = case when v_patch ? 'starts_at' then (v_patch ->> 'starts_at')::timestamptz else starts_at end,
           title = case when v_patch ? 'title' then btrim(v_patch ->> 'title') else title end,
           place_label = case when v_patch ? 'place_label' then nullif(v_patch ->> 'place_label', '') else place_label end,
           recurrence = case when v_patch ? 'recurrence' then v_patch ->> 'recurrence' else recurrence end,
           remind_minutes_before = case when v_patch ? 'remind_minutes_before'
                                        then (v_patch ->> 'remind_minutes_before')::numeric::int else remind_minutes_before end,
           expected_cost = case when v_patch ? 'expected_cost' then round((v_patch ->> 'expected_cost')::numeric, 2) else expected_cost end,
           updated_at = now()
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_before,
      'after', (select to_jsonb(a) from public.zad_appointments a where a.id = v_row_id));
  else
    delete from public.zad_appointments where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_appointment(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;

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
                                      'appointment.added', 'appointment.updated', 'appointment.deleted') then
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
