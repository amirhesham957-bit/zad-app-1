-- الباب الوحيد: مجال الصيدلية (ZAD_OR_PLAN م٢.٥، ٢١/١١). أدوات الصيدلية في العقل بتكتب من هنا بس.
--
--   pharmacy.added       {owner_id?, name, dosage?, dose_times?, daily_dose_count?, unit?, remaining_quantity?, category?,
--                         for_person?, is_recurring?}
--   pharmacy.updated     {item_id, patch:{dosage?, dose_times?, daily_dose_count?, remaining_quantity?, is_recurring?}}
--   pharmacy.deleted     {item_id}                 الصف كامل في الحدث، وتريجر zad_trash بيحفظه.
--   pharmacy.dose_taken  {item_id, taken_at?}      بيعدّي على zad_log_pharmacy_dose_atomic (الكاتب الوحيد للجرعات).
--
-- الدوا بتاع مين: العميل نفسه، أو فرد في عيلته موافق إنه يتابع أدويته (zad_family_share_granted، 'medicines') — نفس
-- قرار medicineHolder في العقل (قرار المالك ١٣/١١). الجرعة على دوا العميل نفسه بس، زي الأداة النهارده.
-- القيود: الاسم ٢–١٢٠، المواعيد HH:MM مفصولة بفاصلة (٢٤:٠٠ غلط، زي regex السيرفر)، عدد الجرعات ١–٢٤ ولو فيه مواعيد
-- بيتحسب منها، والكمية عدد صحيح من ٠ لـ١٠٠٠٠. تريجر zad_pharmacy_items_normalize بيوحّد الوحدة بعد كده زي ما هو.
--
-- الباب نفسه زي 20261121230000 بالحرف، وزايد سطر المجال، والرد بقى فيه payload الحدث (الصيدلية محتاجة نتيجة الجرعة).

create or replace function public.zad_intent_pharmacy_can_write(p_uid uuid, p_owner uuid)
returns boolean
language sql
stable
set search_path = public
as $fn$
  select p_owner = p_uid
      or (exists (select 1 from public.family_members a join public.family_members b on a.family_id = b.family_id
                   where a.user_id = p_uid and b.user_id = p_owner)
          and coalesce(public.zad_family_share_granted(p_uid, p_owner, 'medicines'), false));
$fn$;

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
  c_times constant text := '^([01][0-9]|2[0-3]):[0-5][0-9](,([01][0-9]|2[0-3]):[0-5][0-9])*$';
begin
  if p_kind not in ('pharmacy.added', 'pharmacy.updated', 'pharmacy.deleted', 'pharmacy.dose_taken') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind <> 'pharmacy.added' then
    begin
      select * into v_row from public.zad_pharmacy_items where id = (v_payload ->> 'item_id')::uuid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null or not public.zad_intent_pharmacy_can_write(p_uid, v_row.user_id)
       or (p_kind = 'pharmacy.dose_taken' and v_row.user_id <> p_uid) then
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

create or replace function public.zad_commit_intent(p_intent jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_claims jsonb := coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
  v_uid uuid := auth.uid();
  v_kind text := p_intent ->> 'kind';
  v_cid text := p_intent ->> 'client_event_id';
  v_source text := coalesce(p_intent ->> 'source', 'model');
  v_payload jsonb := coalesce(p_intent -> 'payload', '{}'::jsonb);
  v_conf numeric;
  v_occurred timestamptz;
  v_member uuid;
  v_existing public.zad_events%rowtype;
  v_reason text;
  v_res jsonb;
  v_event_id uuid;
begin
  -- مين: JWT العميل لو موجود، وإلا (السيرفر) user_id اللي في النية. JWT عميل من غير sub = مرفوض.
  if v_uid is null then
    if v_claims ->> 'role' in ('authenticated', 'anon') then
      return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
    end if;
    begin
      v_uid := (p_intent ->> 'user_id')::uuid;
    exception when others then
      v_uid := null;
    end;
  end if;
  if v_uid is null or not exists (select 1 from auth.users where id = v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  end if;

  -- الشكل: النوع (بادئة مجال معروف — النوع نفسه بتراجعه دالة المجال)، مفتاح التكرار، المصدر، الثقة، الوقت، الفرد.
  if v_kind is null or split_part(v_kind, '.', 1) not in ('inventory', 'shopping', 'pharmacy') then
    v_reason := 'unknown_kind';
  elsif v_cid is null or length(v_cid) not between 1 and 100 then
    v_reason := 'bad_client_event_id';
  elsif v_source not in ('manual', 'receipt', 'bank', 'model', 'cron') then
    v_reason := 'bad_source';
  elsif jsonb_typeof(v_payload) <> 'object' then
    v_reason := 'bad_payload';
  end if;
  if v_reason is null then
    begin
      v_conf := (p_intent ->> 'confidence')::numeric;
      v_occurred := coalesce((p_intent ->> 'occurred_at')::timestamptz, now());
    exception when others then
      v_reason := 'bad_shape';
    end;
  end if;
  if v_reason is null and v_conf is not null and v_conf not between 0 and 1 then
    v_reason := 'bad_confidence';
  end if;
  if v_reason is null then
    if p_intent ? 'member_id' then
      begin
        v_member := (p_intent ->> 'member_id')::uuid;
      exception when others then
        v_member := null;
      end;
      if v_member is null or not exists (
        select 1 from public.zad_household_members where id = v_member and user_id = v_uid and archived_at is null
      ) then
        v_reason := 'member_not_in_household';
      end if;
    else
      v_member := public.zad_self_member(v_uid);
    end if;
  end if;
  if v_reason is not null then
    insert into public.zad_guard_events (user_id, kind, reason, source, intent)
    values (v_uid, coalesce(v_kind, '?'), v_reason, v_source, p_intent);
    return jsonb_build_object('ok', false, 'reason', v_reason);
  end if;

  -- تكرار: نفس النتيجة.
  select * into v_existing from public.zad_events where user_id = v_uid and client_event_id = v_cid;
  if found then
    return jsonb_build_object('ok', true, 'duplicate', true, 'event_id', v_existing.id, 'kind', v_existing.kind,
      'row_id', v_existing.payload ->> 'row_id');
  end if;

  -- القيود والكتابة في دالة المجال، والحدث معاها. لو نفس المفتاح اتكتب في نفس اللحظة من طلب تاني: الكتابة بتترجع
  -- ونرجّع نتيجته.
  begin
    v_res := case split_part(v_kind, '.', 1)
      when 'inventory' then public.zad_intent_inventory(v_uid, v_kind, v_payload, v_occurred)
      when 'shopping' then public.zad_intent_shopping(v_uid, v_kind, v_payload, v_occurred)
      when 'pharmacy' then public.zad_intent_pharmacy(v_uid, v_kind, v_payload, v_occurred)
    end;
    if (v_res ->> 'ok')::boolean is not true then
      v_reason := coalesce(v_res ->> 'reason', 'refused');
    else
      v_payload := v_res -> 'payload';
      insert into public.zad_events (user_id, member_id, client_event_id, kind, payload, occurred_at, source, confidence)
      values (v_uid, v_member, v_cid, v_kind, v_payload, v_occurred, v_source, v_conf)
      returning id into v_event_id;
    end if;
  exception when unique_violation then
    select * into v_existing from public.zad_events where user_id = v_uid and client_event_id = v_cid;
    if not found then
      raise;
    end if;
    return jsonb_build_object('ok', true, 'duplicate', true, 'event_id', v_existing.id, 'kind', v_existing.kind,
      'row_id', v_existing.payload ->> 'row_id');
  end;

  if v_reason is not null then
    insert into public.zad_guard_events (user_id, kind, reason, source, intent)
    values (v_uid, v_kind, v_reason, v_source, p_intent);
    return jsonb_build_object('ok', false, 'reason', v_reason);
  end if;

  return jsonb_build_object('ok', true, 'duplicate', false, 'event_id', v_event_id, 'kind', v_kind,
    'row_id', v_res -> 'row_id', 'before', v_payload -> 'before', 'after', v_payload -> 'after', 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_pharmacy_can_write(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function public.zad_intent_pharmacy(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
revoke all on function public.zad_commit_intent(jsonb) from public, anon, authenticated;
grant execute on function public.zad_commit_intent(jsonb) to service_role;
