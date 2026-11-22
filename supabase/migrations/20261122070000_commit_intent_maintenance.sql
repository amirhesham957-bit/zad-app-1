-- الباب الوحيد: مجال صيانة البيت (ZAD_OR_PLAN م٢.٥، ٢٢/١١). zad_commit_intent (20261122030000) بينادي الدالة دي لكل
-- نوع بادئته maintenance. التواريخ نصوص في الجدول (YYYY-MM-DD)، والدالة بتتأكد إنها تواريخ حقيقية.
--   maintenance.added    {name, category?, warranty_expiry_date?, service_interval_days?, estimated_cost?}
--   maintenance.updated  {item_id, patch:{last_service_date?, warranty_expiry_date?}}
--   maintenance.deleted  {item_id}   حذف حقيقي، والصف كله في before.
-- أي صف بيتدوّر عليه بـ id وuser_id مع بعض (for update)، ومش لاقيه = item_not_found.

-- YYYY-MM-DD ويوم حقيقي (مش 2026-02-31).
create or replace function public.zad_intent_maintenance_date(p_text text)
returns boolean
language plpgsql
immutable
as $fn$
begin
  return p_text ~ '^\d{4}-\d{2}-\d{2}$' and to_char(p_text::date, 'YYYY-MM-DD') = p_text;
exception when others then
  return false;
end;
$fn$;

create or replace function public.zad_intent_maintenance(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_patch jsonb;
  v_row public.zad_maintenance_items%rowtype;
  v_row_id uuid;
  v_before jsonb := '{}'::jsonb;
  v_key text;
  v_name text;
  v_category text;
  v_cost numeric;
  v_interval numeric;
begin
  if p_kind not in ('maintenance.added', 'maintenance.updated', 'maintenance.deleted') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind in ('maintenance.updated', 'maintenance.deleted') then
    begin
      select * into v_row from public.zad_maintenance_items
       where id = (v_payload ->> 'item_id')::uuid and user_id = p_uid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
  end if;

  if p_kind = 'maintenance.added' then
    v_name := btrim(coalesce(v_payload ->> 'name', ''));
    v_category := coalesce(nullif(btrim(coalesce(v_payload ->> 'category', '')), ''), 'عام');
    if length(v_name) not between 2 and 120 then
      return jsonb_build_object('ok', false, 'reason', 'device_name_invalid');
    elsif length(v_category) > 60 then
      return jsonb_build_object('ok', false, 'reason', 'device_category_invalid');
    end if;
    if nullif(v_payload ->> 'warranty_expiry_date', '') is not null
       and not public.zad_intent_maintenance_date(v_payload ->> 'warranty_expiry_date') then
      return jsonb_build_object('ok', false, 'reason', 'day_invalid');
    end if;
    begin
      v_interval := (v_payload ->> 'service_interval_days')::numeric;
      v_cost := coalesce((v_payload ->> 'estimated_cost')::numeric, 0);
    exception when others then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end;
    if v_interval is not null and (v_interval <= 0 or v_interval <> trunc(v_interval) or v_interval > 36500) then
      return jsonb_build_object('ok', false, 'reason', 'interval_invalid');
    elsif v_cost < 0 or v_cost > 1000000000 then
      return jsonb_build_object('ok', false, 'reason', 'cost_invalid');
    end if;
    insert into public.zad_maintenance_items (user_id, name, category, warranty_expiry_date, service_interval_days, estimated_cost)
    values (p_uid, v_name, v_category, nullif(v_payload ->> 'warranty_expiry_date', ''), v_interval::int, v_cost)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null,
      'after', (select to_jsonb(m) from public.zad_maintenance_items m where m.id = v_row_id));
  elsif p_kind = 'maintenance.updated' then
    v_patch := v_payload -> 'patch';
    if v_patch is null or jsonb_typeof(v_patch) <> 'object' or v_patch = '{}'::jsonb then
      return jsonb_build_object('ok', false, 'reason', 'patch_empty');
    end if;
    for v_key in select jsonb_object_keys(v_patch) loop
      if v_key not in ('last_service_date', 'warranty_expiry_date') then
        return jsonb_build_object('ok', false, 'reason', 'patch_field_unknown');
      end if;
      if jsonb_typeof(v_patch -> v_key) <> 'string' or not public.zad_intent_maintenance_date(v_patch ->> v_key) then
        return jsonb_build_object('ok', false, 'reason', 'day_invalid');
      end if;
      v_before := v_before || jsonb_build_object(v_key, to_jsonb(v_row) -> v_key);
    end loop;
    update public.zad_maintenance_items
       set last_service_date = case when v_patch ? 'last_service_date' then v_patch ->> 'last_service_date' else last_service_date end,
           warranty_expiry_date = case when v_patch ? 'warranty_expiry_date' then v_patch ->> 'warranty_expiry_date' else warranty_expiry_date end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_before,
      'after', (select to_jsonb(m) from public.zad_maintenance_items m where m.id = v_row_id));
  else
    delete from public.zad_maintenance_items where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_maintenance(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
revoke all on function public.zad_intent_maintenance_date(text) from public, anon, authenticated, service_role;
