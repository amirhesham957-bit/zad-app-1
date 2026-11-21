-- الباب الوحيد، النسخة ٣ (ZAD_OR_PLAN م٢.٥، ٢١/١١): الباب بيتقسم لجزء مشترك ودالة لكل مجال.
--
-- zad_commit_intent بقى فيه المشترك بس: مين (JWT أو user_id من السيرفر)، والشكل، والفرد، والتكرار، وسجل الرفض.
-- القيود والكتابة نفسها في دالة لكل مجال بالبادئة: inventory.* ⇐ zad_intent_inventory. كل مجال جاي (القايمة،
-- الصيدلية، الفلوس) دالة جديدة وسطر في الـcase، من غير ما الباب يتنسخ كله في كل مايجريشن.
--
-- دالة المجال (uid, kind, payload, occurred) بترجّع {ok:false, reason} أو {ok:true, row_id, payload}، والـpayload
-- اللي بترجعه هو اللي بيتكتب في الحدث (فيه before/after). مابيناديهاش حد غير الباب.
--
-- المخزن هنا زي النسخة ٢ بالحرف (added بـitem_id أو من غيره، consumed، quantity_set)، وزايد نوعين:
--   inventory.deleted            {item_id}                          الصف بيتمسح، وتريجر zad_trash بيحفظه ٣٠ يوم.
--   inventory.restock_mode_set   {item_id, restock_mode}            staple أو occasional.
-- مين بينادي: السيرفر بس (service_role)، زي النسخ اللي قبلها.

-- صنف من مخزن البيت ومقفول للكتابة، بنفس شرط RLS بتاع zad_inventory (مراجعة الأمان ٢١/١١). null = مش من البيت.
create or replace function public.zad_intent_household_item(p_uid uuid, p_item_id text)
returns public.zad_inventory
language plpgsql
set search_path = public
as $fn$
declare
  v_row public.zad_inventory%rowtype;
begin
  begin
    select * into v_row from public.zad_inventory i
     where i.id = p_item_id::uuid
       and ((i.family_id is null and i.user_id = p_uid)
            or (i.family_id is not null and i.family_id in (select m.family_id from public.family_members m where m.user_id = p_uid)))
     for update;
  exception when others then
    return null;
  end;
  if v_row.id is null then
    return null;
  end if;
  return v_row;
end;
$fn$;

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
begin
  if p_kind not in ('inventory.added', 'inventory.consumed', 'inventory.quantity_set', 'inventory.deleted',
                    'inventory.restock_mode_set') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  -- الصنف: لازم للكل ماعدا الإضافة (اختياري فيها = تزويد).
  if p_kind <> 'inventory.added' or nullif(v_payload ->> 'item_id', '') is not null then
    v_row := public.zad_intent_household_item(p_uid, v_payload ->> 'item_id');
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
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
    insert into public.zad_inventory (user_id, item_name, quantity, unit, category, expiry_date)
    values (p_uid, v_name, v_qty, coalesce(nullif(btrim(v_payload ->> 'unit'), ''), 'حبة'), v_payload ->> 'category',
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
  if v_kind is null or split_part(v_kind, '.', 1) not in ('inventory') then
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
    'row_id', v_res -> 'row_id', 'before', v_payload -> 'before', 'after', v_payload -> 'after');
end;
$fn$;

-- دوال المجال مابيناديهاش غير الباب (صاحبها نفس صاحب الباب). محدش من برا، ولا السيرفر: الكتابة من غير حدث ممنوعة.
revoke all on function public.zad_intent_household_item(uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.zad_intent_inventory(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
revoke all on function public.zad_commit_intent(jsonb) from public, anon, authenticated;
grant execute on function public.zad_commit_intent(jsonb) to service_role;
