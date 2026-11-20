-- صيدلية العيلة: رب الأسرة (admin) يضيف ويعدّل ويسجّل جرعات لأفراد عيلته (طلب واجهة العوالم، ٢٠٢٦-١١-١٦).
--
-- 20260901020000 سمحت للـadmin بالقراءة بس (الدوا حساس)، والكتابة فضلت لصاحب الصف. هنا الكتابة بتتفتح
-- للـadmin من غير ما تتفتح سياسة كتابة على صفوف الغير: مفيش policy جديدة على zad_pharmacy_items، والعميل
-- مايقدرش يعمل insert/update على صف حد تاني. الطريق الوحيد دالتين SECURITY DEFINER بيتأكدوا الأول إن
-- المنادي (auth.uid() فقط، من غير user id من العميل) admin في عيلة الفرد المستهدف نفسها:
--   • zad_family_pharmacy_save     — إضافة (p_item = null) أو تعديل دوا الفرد.
--   • zad_family_pharmacy_log_dose — تسجيل جرعة اتاخدت، بنفس حساب zad_log_pharmacy_dose_atomic
--     (واحدة بواحدة، وإعادة نفس الميعاد مالهاش أثر). من غير سطر قايمة الشراء: ده على جهاز الفرد نفسه.
-- الفرد بيفضل يقرا ويعدّل بتاعه بسياسته القديمة. الـadmin اللي بيضيف دوا لنفسه بيعدي من نفس الدالة (هو admin
-- في عيلته). أوقات الجرعات بنفس الـregex بتاع السيرفر بالظبط (24:00 غلط).

create or replace function public.zad_is_family_head_of(p_target uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select auth.uid() is not null and exists (
    select 1
      from public.family_members fm_admin
      join public.family_members fm_target on fm_target.family_id = fm_admin.family_id
     where fm_admin.user_id = auth.uid()
       and fm_admin.role = 'admin'
       and fm_target.user_id = p_target
  )
$$;
revoke all on function public.zad_is_family_head_of(uuid) from public, anon, authenticated;

create or replace function public.zad_family_pharmacy_save(
  p_target uuid,
  p_item uuid,
  p_name text,
  p_dosage text default null,
  p_unit text default null,
  p_daily_dose_count int default null,
  p_dose_times text default null,
  p_units_per_dose numeric default null,
  p_remaining_quantity int default null,
  p_expiry_date text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.zad_pharmacy_items;
  v_times text := nullif(btrim(coalesce(p_dose_times, '')), '');
  v_bad boolean;
begin
  if not public.zad_is_family_head_of(p_target) then
    raise exception 'not_family_head' using errcode = '42501';
  end if;
  if p_item is null and (p_name is null or char_length(btrim(p_name)) not between 1 and 80) then
    raise exception 'bad_name' using errcode = '22023';
  end if;
  if p_name is not null and char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'bad_name' using errcode = '22023';
  end if;
  if p_daily_dose_count is not null and p_daily_dose_count not between 0 and 24 then
    raise exception 'bad_dose_count' using errcode = '22023';
  end if;
  if p_remaining_quantity is not null and p_remaining_quantity not between 0 and 10000 then
    raise exception 'bad_quantity' using errcode = '22023';
  end if;
  if p_units_per_dose is not null and p_units_per_dose not between 0 and 100 then
    raise exception 'bad_units_per_dose' using errcode = '22023';
  end if;
  if v_times is not null then
    select bool_or(btrim(t) !~ '^([01]?[0-9]|2[0-3]):[0-5][0-9]$') into v_bad
      from unnest(string_to_array(v_times, ',')) as t;
    if v_bad then raise exception 'bad_dose_times' using errcode = '22023'; end if;
  end if;

  if p_item is null then
    insert into public.zad_pharmacy_items
      (user_id, name, dosage, unit, daily_dose_count, dose_times, units_per_dose, remaining_quantity, expiry_date)
    values
      (p_target, btrim(p_name), p_dosage, coalesce(p_unit, 'قرص'), coalesce(p_daily_dose_count, 1), v_times,
       p_units_per_dose, coalesce(p_remaining_quantity, 1), p_expiry_date)
    returning * into v_row;
  else
    update public.zad_pharmacy_items i set
      name = coalesce(btrim(p_name), i.name),
      dosage = coalesce(p_dosage, i.dosage),
      unit = coalesce(p_unit, i.unit),
      daily_dose_count = coalesce(p_daily_dose_count, i.daily_dose_count),
      dose_times = case when p_dose_times is null then i.dose_times else v_times end,
      has_invalid_dose_time = case when p_dose_times is null then i.has_invalid_dose_time else false end,
      units_per_dose = coalesce(p_units_per_dose, i.units_per_dose),
      remaining_quantity = coalesce(p_remaining_quantity, i.remaining_quantity),
      qty_confirmed_at = case when p_remaining_quantity is null then i.qty_confirmed_at else now() end,
      expiry_date = coalesce(p_expiry_date, i.expiry_date)
    where i.id = p_item and i.user_id = p_target
    returning * into v_row;
    if not found then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;
  end if;
  return jsonb_build_object('ok', true, 'item_id', v_row.id, 'user_id', v_row.user_id, 'name', v_row.name,
                            'remaining_quantity', v_row.remaining_quantity);
exception when unique_violation then
  return jsonb_build_object('ok', false, 'reason', 'duplicate_name');
end;
$$;

create or replace function public.zad_family_pharmacy_log_dose(
  p_target uuid,
  p_item uuid,
  p_scheduled_at timestamptz default null,
  p_taken_at timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_item public.zad_pharmacy_items%rowtype;
  v_slot timestamptz;
  v_dose_id uuid;
  v_units numeric;
  v_acc numeric;
  v_whole int;
  v_qty int;
  v_carry numeric;
begin
  if not public.zad_is_family_head_of(p_target) then
    raise exception 'not_family_head' using errcode = '42501';
  end if;
  if p_item is null then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;
  v_slot := coalesce(p_scheduled_at,
    date_trunc('hour', coalesce(p_taken_at, now()))
      + floor(extract(minute from coalesce(p_taken_at, now())) / 5)::int * interval '5 minutes');

  select * into v_item from public.zad_pharmacy_items where id = p_item and user_id = p_target for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  v_units := greatest(coalesce(v_item.units_per_dose, 1), 0);
  insert into public.zad_pharmacy_doses (user_id, item_id, scheduled_at, taken_at, status, units)
  values (p_target, p_item, v_slot, coalesce(p_taken_at, now()), 'taken', v_units)
  on conflict (user_id, item_id, scheduled_at) where scheduled_at is not null do nothing
  returning id into v_dose_id;
  if v_dose_id is null then
    return jsonb_build_object('ok', true, 'duplicate', true, 'item_id', v_item.id, 'name', v_item.name,
                              'remaining_quantity', v_item.remaining_quantity, 'scheduled_at', v_slot);
  end if;

  v_acc := v_item.dose_carry + v_units;
  v_whole := floor(v_acc)::int;
  v_qty := greatest(0, v_item.remaining_quantity - v_whole);
  v_carry := case when v_qty = 0 then 0 else v_acc - v_whole end;
  update public.zad_pharmacy_items set remaining_quantity = v_qty, dose_carry = v_carry where id = v_item.id;

  return jsonb_build_object('ok', true, 'duplicate', false, 'dose_id', v_dose_id, 'item_id', v_item.id,
                            'name', v_item.name, 'previous_quantity', v_item.remaining_quantity,
                            'remaining_quantity', v_qty, 'scheduled_at', v_slot);
end;
$$;

revoke all on function public.zad_family_pharmacy_save(uuid, uuid, text, text, text, int, text, numeric, int, text) from public, anon;
grant execute on function public.zad_family_pharmacy_save(uuid, uuid, text, text, text, int, text, numeric, int, text) to authenticated;
revoke all on function public.zad_family_pharmacy_log_dose(uuid, uuid, timestamptz, timestamptz) from public, anon;
grant execute on function public.zad_family_pharmacy_log_dose(uuid, uuid, timestamptz, timestamptz) to authenticated;
