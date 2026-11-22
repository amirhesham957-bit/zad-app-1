-- الباب الوحيد: مجال قايمة التسوق (ZAD_OR_PLAN م٢.٥، ٢١/١١). أدوات القايمة في العقل بتكتب من هنا بس.
--
--   shopping.added      {item_name, quantity, item_id?}   الاسم ٢–١٢٠ حرف، والكمية بتتقرّب لفوق لعدد صحيح (العمود integer)
--                                                         من ١ لـ١٠٠. بـitem_id = تزويد على سطر مفتوح في قايمة البيت.
--   shopping.completed  {item_id}                         السطر لازم يكون مفتوح.
--   shopping.deleted    {item_id}                         الصف كامل في الحدث، وتريجر zad_trash بيحفظه.
-- السطر لازم يكون من قايمة البيت بنفس شرط RLS بتاع zad_shopping_list بالحرف: صف العميل نفسه، أو صف عيلة هو فيها.
-- الباب نفسه زي 20261121220000 بالحرف، وزايد سطر المجال.

create or replace function public.zad_intent_shopping(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_row public.zad_shopping_list%rowtype;
  v_qty numeric;
  v_name text;
  v_row_id uuid;
  v_after int;
begin
  if p_kind not in ('shopping.added', 'shopping.completed', 'shopping.deleted') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind <> 'shopping.added' or nullif(v_payload ->> 'item_id', '') is not null then
    begin
      select * into v_row from public.zad_shopping_list s
       where s.id = (v_payload ->> 'item_id')::uuid
         -- نفس zad_shopping_list_update بالحرف (20261011140000).
         and (s.user_id = p_uid
              or (s.family_id is not null and s.family_id in (select m.family_id from public.family_members m where m.user_id = p_uid)))
       for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
    if p_kind in ('shopping.added', 'shopping.completed') and coalesce(v_row.is_purchased, false) then
      return jsonb_build_object('ok', false, 'reason', 'already_purchased');
    end if;
  end if;

  if p_kind = 'shopping.added' then
    v_name := btrim(coalesce(v_payload ->> 'item_name', ''));
    begin
      v_qty := ceil((v_payload ->> 'quantity')::numeric);
    exception when others then
      v_qty := null;
    end;
    if v_row.id is null and (length(v_name) < 2 or length(v_name) > 120) then
      return jsonb_build_object('ok', false, 'reason', 'name_invalid');
    elsif v_qty is null or v_qty < 1 then
      return jsonb_build_object('ok', false, 'reason', 'qty_not_positive');
    elsif v_qty > 100 then
      return jsonb_build_object('ok', false, 'reason', 'qty_too_large');
    end if;
    if v_row.id is not null then
      v_after := coalesce(v_row.quantity, 1) + v_qty::int;
      update public.zad_shopping_list set quantity = v_after where id = v_row.id;
      v_row_id := v_row.id;
      v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.quantity, 'after', v_after);
    else
      insert into public.zad_shopping_list (user_id, item_name, quantity, is_purchased)
      values (p_uid, v_name, v_qty::int, false)
      returning id into v_row_id;
      v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'after', v_qty::int);
    end if;
  elsif p_kind = 'shopping.completed' then
    update public.zad_shopping_list set is_purchased = true where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', false, 'after', true);
  else
    delete from public.zad_shopping_list where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
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
  if v_kind is null or split_part(v_kind, '.', 1) not in ('inventory', 'shopping') then
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

revoke all on function public.zad_intent_shopping(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
revoke all on function public.zad_commit_intent(jsonb) from public, anon, authenticated;
grant execute on function public.zad_commit_intent(jsonb) to service_role;
