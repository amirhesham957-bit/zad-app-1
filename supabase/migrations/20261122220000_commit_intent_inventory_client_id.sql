-- ZAD_OR_PLAN م٢.٤ (تكملة): inventory.added بياخد item_id جديد من العميل.
--
-- الـOutbox المحلي في الموبايل بيولّد id للصنف قبل ما يبعت، فلازم السيرفر يكتب الصف بنفس الـid ومايولّدش واحد تاني.
-- القاعدة: item_id في الإضافة =
--   * صنف موجود في البيت  ⇐ تزويد عليه (زي ما كان بالظبط)
--   * UUID صالح ومش موجود في zad_inventory خالص ⇐ صف جديد بالـid ده
--   * أي حاجة تانية (مش UUID، أو id صف مستخدم تاني) ⇐ item_not_found، ومفيش تلميح إن الصف موجود عند حد.
-- الباقي في zad_intent_inventory زي 20261121220000 بالحرف.

create or replace function public.zad_intent_inventory(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_row public.zad_inventory%rowtype;
  v_reason text;
  v_qty numeric;
  v_after numeric;
  v_row_id uuid;
  v_name text;
  v_expiry date;
  v_new_id uuid;
begin
  if p_kind not in ('inventory.added', 'inventory.consumed', 'inventory.quantity_set', 'inventory.deleted',
                    'inventory.restock_mode_set') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  -- الصنف: لازم للكل ماعدا الإضافة (اختياري فيها = تزويد).
  if p_kind <> 'inventory.added' or nullif(v_payload ->> 'item_id', '') is not null then
    v_row := public.zad_intent_household_item(p_uid, v_payload ->> 'item_id');
    if v_row.id is null then
      -- الإضافة بـitem_id مش موجود في البيت: id جديد من العميل (الـOutbox المحلي)، بشرطين: UUID صالح، ومش موجود
      -- خالص في zad_inventory (صف مستخدم تاني = item_not_found، من غير ما نقول إنه موجود).
      if p_kind = 'inventory.added' then
        begin
          v_new_id := (v_payload ->> 'item_id')::uuid;
        exception when others then
          v_new_id := null;
        end;
        if v_new_id is null or exists (select 1 from public.zad_inventory i where i.id = v_new_id) then
          return jsonb_build_object('ok', false, 'reason', 'item_not_found');
        end if;
      else
        return jsonb_build_object('ok', false, 'reason', 'item_not_found');
      end if;
    end if;
  end if;

  -- القيود.
  if p_kind = 'inventory.added' then
    v_name := btrim(coalesce(v_payload ->> 'item_name', ''));
    begin
      -- العمود numeric(12,3): 0.0004 كانت هتعدي «> 0» وتتخزن صفر.
      v_qty := round((v_payload ->> 'quantity')::numeric, 3);
    exception when others then
      v_qty := null;
    end;
    if length(v_name) < 2 or length(v_name) > 120 then
      v_reason := 'name_invalid';
    elsif v_qty is null or v_qty <= 0 then
      v_reason := 'qty_not_positive';
    elsif v_qty > 999 then
      v_reason := 'qty_too_large';
    elsif coalesce(v_payload ->> 'category', '') not in
          ('البقالة', 'الخضار', 'الفواكه', 'اللحوم', 'الألبان', 'المشروبات', 'العناية', 'أخرى') then
      v_reason := 'category_unknown';
    elsif nullif(v_payload ->> 'expiry_date', '') is not null then
      if (v_payload ->> 'expiry_date') !~ '^\d{4}-\d{2}-\d{2}$' then
        v_reason := 'expiry_bad_format';
      else
        begin
          v_expiry := (v_payload ->> 'expiry_date')::date;
        exception when others then
          v_reason := 'expiry_bad_format';
        end;
        if v_reason is null and v_expiry < p_occurred::date then
          v_reason := 'expiry_before_purchase';
        end if;
      end if;
    end if;
  elsif p_kind = 'inventory.consumed' then
    begin
      v_qty := round((v_payload ->> 'amount')::numeric, 3);
    exception when others then
      v_qty := null;
    end;
    if v_qty is null or v_qty < 0 or (v_qty = 0 and (v_payload -> 'opened') is distinct from 'true'::jsonb) then
      v_reason := 'amount_invalid';
    elsif v_qty > 1000 then
      v_reason := 'amount_too_large';
    end if;
  elsif p_kind = 'inventory.quantity_set' then
    begin
      v_qty := round((v_payload ->> 'quantity')::numeric, 3);
    exception when others then
      v_qty := null;
    end;
    if v_qty is null or v_qty < 0 then
      v_reason := 'qty_negative';
    elsif v_qty > greatest(coalesce(v_row.quantity, 0) * 20, 100) then
      v_reason := 'qty_too_large';
    end if;
  elsif p_kind = 'inventory.restock_mode_set' then
    if coalesce(v_payload ->> 'restock_mode', '') not in ('staple', 'occasional') then
      v_reason := 'restock_mode_unknown';
    end if;
  end if;
  if v_reason is not null then
    return jsonb_build_object('ok', false, 'reason', v_reason);
  end if;

  -- الكتابة.
  if p_kind = 'inventory.added' and v_row.id is not null then
    v_after := greatest(coalesce(v_row.quantity, 0), 0) + v_qty;
    update public.zad_inventory
       set quantity = v_after,
           category = coalesce(v_row.category, v_payload ->> 'category'),
           expiry_date = coalesce(nullif(v_payload ->> 'expiry_date', ''), v_row.expiry_date)
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.quantity, 'after', v_after);
  elsif p_kind = 'inventory.added' then
    insert into public.zad_inventory (id, user_id, item_name, quantity, unit, category, expiry_date)
    values (coalesce(v_new_id, gen_random_uuid()), p_uid, v_name, v_qty, coalesce(nullif(btrim(v_payload ->> 'unit'), ''), 'حبة'), v_payload ->> 'category',
            nullif(v_payload ->> 'expiry_date', ''))
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'after', v_qty);
  elsif p_kind = 'inventory.consumed' then
    v_after := greatest(coalesce(v_row.quantity, 0) - v_qty, 0);
    update public.zad_inventory
       set quantity = v_after,
           opened_at = case when (v_payload -> 'opened') = 'true'::jsonb then coalesce(opened_at, now()) else opened_at end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.quantity, 'after', v_after);
  elsif p_kind = 'inventory.quantity_set' then
    update public.zad_inventory set quantity = v_qty where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.quantity, 'after', v_qty);
  elsif p_kind = 'inventory.deleted' then
    -- الصف كامل في الحدث، وتريجر zad_trash بيحفظه للتراجع.
    delete from public.zad_inventory where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  else
    update public.zad_inventory set restock_mode = v_payload ->> 'restock_mode' where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.restock_mode,
                                                 'after', v_payload ->> 'restock_mode');
  end if;
  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;
