-- الباب الوحيد: تأجيل الجرعة (ZAD_OR_PLAN م٢.٥، ٢٢/١١). zad_intent_pharmacy زي 20261122000000 بالحرف، وزايد نوع:
--   pharmacy.dose_snoozed {item_id, scheduled_at, minutes}   «فكّرني بعدين»: upsert على zad_dose_snoozes (user_id, item_id,
--                                                            scheduled_at)، الدقايق ٥–٢٤٠، والدوا بتاع العميل نفسه بس.
-- الباب نفسه ماتغيرش (المجال pharmacy موجود فيه). الكتابة كلها بعد كده من الباب: أداة snooze_pharmacy_dose وزرار تليجرام.

create or replace function public.zad_intent_pharmacy(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_patch jsonb;
  v_row public.zad_pharmacy_items%rowtype;
  v_owner uuid;
  v_name text;
  v_times text;
  v_count int;
  v_qty int;
  v_key text;
  v_before jsonb := '{}'::jsonb;
  v_row_id uuid;
  v_dose jsonb;
  v_at timestamptz;
  v_minutes int;
  v_snooze_before jsonb;
  c_times constant text := '^([01][0-9]|2[0-3]):[0-5][0-9](,([01][0-9]|2[0-3]):[0-5][0-9])*$';
begin
  if p_kind not in ('pharmacy.added', 'pharmacy.updated', 'pharmacy.deleted', 'pharmacy.dose_taken', 'pharmacy.dose_snoozed') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind <> 'pharmacy.added' then
    begin
      select * into v_row from public.zad_pharmacy_items where id = (v_payload ->> 'item_id')::uuid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null or not public.zad_intent_pharmacy_can_write(p_uid, v_row.user_id)
       or (p_kind in ('pharmacy.dose_taken', 'pharmacy.dose_snoozed') and v_row.user_id <> p_uid) then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
  end if;

  -- القيود المشتركة على الحقول (للإضافة من الـpayload، وللتعديل من الـpatch).
  v_patch := case when p_kind = 'pharmacy.added' then v_payload when p_kind = 'pharmacy.updated' then v_payload -> 'patch' end;
  if p_kind = 'pharmacy.updated' then
    if v_patch is null or jsonb_typeof(v_patch) <> 'object' or v_patch = '{}'::jsonb then
      return jsonb_build_object('ok', false, 'reason', 'patch_empty');
    end if;
    for v_key in select jsonb_object_keys(v_patch) loop
      if v_key not in ('dosage', 'dose_times', 'daily_dose_count', 'remaining_quantity', 'is_recurring') then
        return jsonb_build_object('ok', false, 'reason', 'patch_field_unknown');
      end if;
    end loop;
  end if;
  if v_patch is not null then
    v_times := nullif(btrim(coalesce(v_patch ->> 'dose_times', '')), '');
    if v_times is not null and (v_times !~ c_times or array_length(string_to_array(v_times, ','), 1) > 24) then
      return jsonb_build_object('ok', false, 'reason', 'dose_times_invalid');
    end if;
    if v_patch ? 'daily_dose_count' and v_patch -> 'daily_dose_count' <> 'null'::jsonb then
      begin
        v_count := (v_patch ->> 'daily_dose_count')::numeric::int;
      exception when others then
        v_count := null;
      end;
      if v_count is null or v_count not between 1 and 24 then
        return jsonb_build_object('ok', false, 'reason', 'dose_count_invalid');
      end if;
    end if;
    -- المواعيد هي العدد (العقل كان بيعمل كده، والتلفون بيقسم عليه أيام الكفاية).
    if v_times is not null then
      v_count := array_length(string_to_array(v_times, ','), 1);
    end if;
    if v_patch ? 'remaining_quantity' and v_patch -> 'remaining_quantity' <> 'null'::jsonb then
      begin
        v_qty := round((v_patch ->> 'remaining_quantity')::numeric)::int;
      exception when others then
        v_qty := null;
      end;
      if v_qty is null or v_qty not between 0 and 10000 then
        return jsonb_build_object('ok', false, 'reason', 'qty_invalid');
      end if;
    end if;
    if v_patch ? 'is_recurring' and jsonb_typeof(v_patch -> 'is_recurring') not in ('boolean', 'null') then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end if;
    if length(coalesce(v_patch ->> 'dosage', '')) > 120 then
      return jsonb_build_object('ok', false, 'reason', 'dosage_too_long');
    end if;
  end if;

  if p_kind = 'pharmacy.added' then
    v_name := btrim(coalesce(v_payload ->> 'name', ''));
    if length(v_name) < 2 or length(v_name) > 120 then
      return jsonb_build_object('ok', false, 'reason', 'name_invalid');
    end if;
    begin
      v_owner := coalesce(nullif(v_payload ->> 'owner_id', '')::uuid, p_uid);
    exception when others then
      v_owner := null;
    end;
    if v_owner is null or not exists (select 1 from auth.users where id = v_owner)
       or not public.zad_intent_pharmacy_can_write(p_uid, v_owner) then
      return jsonb_build_object('ok', false, 'reason', 'member_not_granted');
    end if;
    insert into public.zad_pharmacy_items (user_id, name, dosage, daily_dose_count, dose_times, unit, remaining_quantity,
                                           category, for_person, is_recurring)
    values (v_owner, v_name, nullif(btrim(coalesce(v_payload ->> 'dosage', '')), ''), coalesce(v_count, 1), v_times,
            coalesce(nullif(btrim(coalesce(v_payload ->> 'unit', '')), ''), 'قرص'), coalesce(v_qty, 1),
            left(coalesce(nullif(btrim(coalesce(v_payload ->> 'category', '')), ''), 'عام'), 40),
            left(nullif(btrim(coalesce(v_payload ->> 'for_person', '')), ''), 60),
            coalesce((v_payload ->> 'is_recurring')::boolean, false))
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'owner_id', v_owner, 'after',
      (select to_jsonb(p) from public.zad_pharmacy_items p where p.id = v_row_id));
  elsif p_kind = 'pharmacy.updated' then
    for v_key in select jsonb_object_keys(v_patch) loop
      v_before := v_before || jsonb_build_object(v_key, to_jsonb(v_row) -> v_key);
    end loop;
    if v_times is not null then
      v_before := v_before || jsonb_build_object('daily_dose_count', v_row.daily_dose_count);
    end if;
    update public.zad_pharmacy_items
       set dosage = case when v_patch ? 'dosage' then nullif(btrim(coalesce(v_patch ->> 'dosage', '')), '') else dosage end,
           dose_times = case when v_patch ? 'dose_times' then v_times else dose_times end,
           daily_dose_count = coalesce(v_count, daily_dose_count),
           remaining_quantity = coalesce(v_qty, remaining_quantity),
           is_recurring = case when v_patch ? 'is_recurring' and v_patch -> 'is_recurring' <> 'null'::jsonb
                               then (v_patch ->> 'is_recurring')::boolean else is_recurring end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_before, 'after',
      (select to_jsonb(p) from public.zad_pharmacy_items p where p.id = v_row_id));
  elsif p_kind = 'pharmacy.deleted' then
    delete from public.zad_pharmacy_items where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  elsif p_kind = 'pharmacy.dose_snoozed' then
    -- «فكّرني بعدين»: صف تأجيل واحد لكل (العميل، الدوا، الخانة)، والكرون بيسكت عنها لحد snooze_until. الدوا بتاع العميل نفسه.
    begin
      v_at := (v_payload ->> 'scheduled_at')::timestamptz;
    exception when others then
      v_at := null;
    end;
    if v_at is null then
      return jsonb_build_object('ok', false, 'reason', 'dose_slot_invalid');
    end if;
    begin
      v_minutes := (v_payload ->> 'minutes')::numeric::int;
    exception when others then
      v_minutes := null;
    end;
    if v_minutes is null or v_minutes not between 5 and 240 then
      return jsonb_build_object('ok', false, 'reason', 'snooze_minutes_invalid');
    end if;
    select to_jsonb(s) into v_snooze_before from public.zad_dose_snoozes s
     where s.user_id = p_uid and s.item_id = v_row.id and s.scheduled_at = v_at;
    insert into public.zad_dose_snoozes (user_id, item_id, scheduled_at, snooze_until)
    values (p_uid, v_row.id, v_at, now() + make_interval(mins => v_minutes))
    on conflict (user_id, item_id, scheduled_at) do update set snooze_until = excluded.snooze_until;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_snooze_before, 'after',
      (select to_jsonb(s) from public.zad_dose_snoozes s where s.user_id = p_uid and s.item_id = v_row.id and s.scheduled_at = v_at));
  else
    v_dose := public.zad_log_pharmacy_dose_atomic(p_uid, v_row.id, null,
      coalesce(nullif(v_payload ->> 'taken_at', '')::timestamptz, p_occurred));
    if (v_dose ->> 'ok')::boolean is not true then
      return jsonb_build_object('ok', false, 'reason', 'dose_' || coalesce(v_dose ->> 'reason', 'refused'));
    end if;
    if (v_dose ->> 'duplicate')::boolean is true then
      return jsonb_build_object('ok', false, 'reason', 'dose_already_logged');
    end if;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.remaining_quantity,
      'after', (v_dose -> 'remaining_quantity'), 'dose_id', v_dose -> 'dose_id',
      'shopping_added', coalesce(v_dose -> 'shopping_added', 'false'::jsonb));
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_pharmacy(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
