-- الباب الوحيد: مجال المواعيد (ZAD_OR_PLAN م٢.٥، ٢٢/١١). zad_commit_intent بينادي الدالة دي لكل نوع بادئته appointment.
-- الأداة (TS) بتحسب الوقت بتوقيت العميل وتوحّد «لمين» وتراجع التعارض؛ الدالة بتراجع قيود الجدول الحي وتكتب.
--   appointment.added    {title, kind?, starts_at, place_label?, remind_minutes_before?, recurrence?, source?, for_person?,
--                         expected_cost?}   الافتراضيات زي أداة add_appointment: personal / ٠ دقيقة / once / chat.
--   appointment.updated  {item_id, patch:{status?, starts_at?, title?, place_label?, recurrence?, remind_minutes_before?,
--                         expected_cost?}}  place_label وexpected_cost null = امسحه؛ updated_at = دلوقتي.
--   appointment.deleted  {item_id}           حذف حقيقي، والصف كله في before.
-- الصف بيتدوّر عليه بـ id وuser_id مع بعض (for update)، ومش لاقيه = item_not_found.

-- قيود الجدول الحي على الحقول الموجودة في p_src (كلها في الإضافة، والموجود بس في التعديل). null = سليم، وإلا سبب قصير.
create or replace function public.zad_intent_appointment_fields(p_src jsonb, p_full boolean)
returns text
language plpgsql
as $fn$
declare
  v_n numeric;
  v_ts timestamptz;
begin
  if p_full or p_src ? 'title' then
    if jsonb_typeof(p_src -> 'title') <> 'string' or length(btrim(p_src ->> 'title')) not between 2 and 160 then
      return 'appt_title_invalid';
    end if;
  end if;
  if p_full or p_src ? 'starts_at' then
    begin
      v_ts := (p_src ->> 'starts_at')::timestamptz;
    exception when others then
      return 'starts_at_invalid';
    end;
    if v_ts is null then return 'starts_at_invalid'; end if;
  end if;
  if p_full and ((p_src ->> 'kind') is null or (p_src ->> 'kind') not in ('work', 'errand', 'medical', 'family', 'personal', 'other')) then
    return 'kind_invalid';
  end if;
  if p_src ? 'status' and ((p_src ->> 'status') is null or (p_src ->> 'status') not in ('upcoming', 'done', 'cancelled')) then
    return 'status_invalid';
  end if;
  if (p_full or p_src ? 'recurrence') and ((p_src ->> 'recurrence') is null
     or (p_src ->> 'recurrence') not in ('once', 'hourly', 'daily', 'weekly', 'monthly')) then
    return 'appt_recurrence_invalid';
  end if;
  if p_full and ((p_src ->> 'source') is null or (p_src ->> 'source') not in ('app', 'voice', 'chat', 'telegram', 'notification')) then
    return 'source_invalid';
  end if;
  if p_full or p_src ? 'remind_minutes_before' then
    begin
      v_n := (p_src ->> 'remind_minutes_before')::numeric;
    exception when others then
      return 'remind_invalid';
    end;
    if v_n is null or v_n <> trunc(v_n) or v_n < 0 or v_n > 10080 then return 'remind_invalid'; end if;
  end if;
  if p_src ? 'place_label' and length(coalesce(p_src ->> 'place_label', '')) > 120 then
    return 'place_too_long';
  end if;
  if p_src ? 'for_person' and length(btrim(coalesce(p_src ->> 'for_person', ''))) > 40 then
    return 'for_person_invalid';
  end if;
  if p_src ? 'expected_cost' and (p_src ->> 'expected_cost') is not null then
    begin
      v_n := round((p_src ->> 'expected_cost')::numeric, 2);
    exception when others then
      return 'cost_invalid';
    end;
    if v_n <= 0 or v_n > 1000000 then return 'cost_invalid'; end if;
  end if;
  return null;
end;
$fn$;

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
    v_src := jsonb_build_object('kind', 'personal', 'remind_minutes_before', 0, 'recurrence', 'once', 'source', 'chat') || v_payload;
    v_reason := public.zad_intent_appointment_fields(v_src, true);
    if v_reason is not null then
      return jsonb_build_object('ok', false, 'reason', v_reason);
    end if;
    insert into public.zad_appointments (user_id, title, kind, starts_at, place_label, remind_minutes_before, recurrence, source,
                                         for_person, expected_cost)
    values (p_uid, btrim(v_src ->> 'title'), v_src ->> 'kind', (v_src ->> 'starts_at')::timestamptz,
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
revoke all on function public.zad_intent_appointment_fields(jsonb, boolean) from public, anon, authenticated, service_role;
