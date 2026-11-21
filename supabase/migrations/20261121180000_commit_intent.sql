-- الباب الوحيد للكتابة، النسخة الأولى (ZAD_OR_PLAN م٢.٢، ٢١/١١).
--
-- zad_commit_intent(intent) بتاخد نية متحللة خلاص (الصنف معروف بالـid والأرقام محسوبة — فهم الكلام ومطابقة
-- الاسم فاضلين في الحواس، zad-brain)، وفي transaction واحدة: بتراجع القيود، وبتكتب الحدث في zad_events،
-- وبتحدّث الجدول. لو قيد اتكسر: مفيش كتابة، والسبب بيتسجل في zad_guard_events (بيبان في «صحة العقل»).
--
-- النسخة دي فيها المخزن بس (٣ أنواع)، نفس قواعد الأدوات النهارده (validators.ts):
--   inventory.added          {item_name, quantity, unit?, category, expiry_date?}   ٠ < الكمية ≤ ٩٩٩، الاسم حرفين+،
--                            الفئة من الـ٨، والصلاحية YYYY-MM-DD ومش قبل يوم الشرا (م٢.٣).
--   inventory.consumed       {item_id, amount, opened?}   ٠ < amount ≤ ١٠٠٠ (أو ٠ مع opened). الكمية بتقف عند صفر.
--   inventory.quantity_set   {item_id, quantity}          ٠ ≤ الكمية ≤ max(القديمة×٢٠، ١٠٠).
-- الصنف لازم يكون من مخزن البيت (بتاع العميل أو عيلته، زي RLS بتاعه). الأدوات بتتحول عليها في م٢.٥.
--
-- التكرار: نفس client_event_id لنفس العميل = نفس النتيجة من غير ما يتطبق تاني (م٢.٤).
-- مين بينادي: السيرفر بس دلوقتي (service_role). لما الموبايل ياخد الصلاحية (م٢.٤) العميل هيبقى auth.uid()
-- دايماً، وuser_id اللي في النية مابيتقريش غير من غير JWT عميل.

create table if not exists public.zad_guard_events (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  reason text not null,
  source text,
  intent jsonb not null,
  created_at timestamptz not null default now()
);
create index if not exists zad_guard_events_user_time on public.zad_guard_events (user_id, created_at desc);
alter table public.zad_guard_events enable row level security;
drop policy if exists guard_events_read_own on public.zad_guard_events;
create policy guard_events_read_own on public.zad_guard_events
  for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete, truncate on public.zad_guard_events from anon, authenticated;

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
  v_row public.zad_inventory%rowtype;
  v_reason text;
  v_qty numeric;
  v_after numeric;
  v_row_id uuid;
  v_event_id uuid;
  v_name text;
  v_expiry date;
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

  -- الشكل: النوع، مفتاح التكرار، المصدر، الثقة، الوقت، الفرد.
  if v_kind is null or v_kind not in ('inventory.added', 'inventory.consumed', 'inventory.quantity_set') then
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

  -- الصنف (للاستهلاك والتعديل): من مخزن البيت بس.
  if v_kind in ('inventory.consumed', 'inventory.quantity_set') then
    begin
      select * into v_row from public.zad_inventory i
       where i.id = (v_payload ->> 'item_id')::uuid
         and (i.user_id = v_uid or i.family_id in (select m.family_id from public.family_members m where m.user_id = v_uid))
       for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null then
      v_reason := 'item_not_found';
    end if;
  end if;

  -- القيود لكل نوع.
  if v_reason is null and v_kind = 'inventory.added' then
    v_name := btrim(coalesce(v_payload ->> 'item_name', ''));
    begin
      v_qty := (v_payload ->> 'quantity')::numeric;
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
        if v_reason is null and v_expiry < v_occurred::date then
          v_reason := 'expiry_before_purchase';
        end if;
      end if;
    end if;
  elsif v_reason is null and v_kind = 'inventory.consumed' then
    begin
      v_qty := (v_payload ->> 'amount')::numeric;
    exception when others then
      v_qty := null;
    end;
    if v_qty is null or v_qty < 0 or (v_qty = 0 and (v_payload -> 'opened') is distinct from 'true'::jsonb) then
      v_reason := 'amount_invalid';
    elsif v_qty > 1000 then
      v_reason := 'amount_too_large';
    end if;
  elsif v_reason is null and v_kind = 'inventory.quantity_set' then
    begin
      v_qty := (v_payload ->> 'quantity')::numeric;
    exception when others then
      v_qty := null;
    end;
    if v_qty is null or v_qty < 0 then
      v_reason := 'qty_negative';
    elsif v_qty > greatest(coalesce(v_row.quantity, 0) * 20, 100) then
      v_reason := 'qty_too_large';
    end if;
  end if;

  if v_reason is not null then
    insert into public.zad_guard_events (user_id, kind, reason, source, intent)
    values (v_uid, v_kind, v_reason, v_source, p_intent);
    return jsonb_build_object('ok', false, 'reason', v_reason);
  end if;

  -- الكتابة والحدث مع بعض. لو نفس المفتاح اتكتب في نفس اللحظة من طلب تاني: الكتابة بتترجع ونرجّع نتيجته.
  begin
    if v_kind = 'inventory.added' then
      insert into public.zad_inventory (user_id, item_name, quantity, unit, category, expiry_date)
      values (v_uid, v_name, v_qty, coalesce(nullif(btrim(v_payload ->> 'unit'), ''), 'حبة'), v_payload ->> 'category',
              nullif(v_payload ->> 'expiry_date', ''))
      returning id into v_row_id;
      v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'after', v_qty);
    elsif v_kind = 'inventory.consumed' then
      v_after := greatest(coalesce(v_row.quantity, 0) - v_qty, 0);
      update public.zad_inventory
         set quantity = v_after,
             opened_at = case when (v_payload -> 'opened') = 'true'::jsonb then coalesce(opened_at, now()) else opened_at end
       where id = v_row.id;
      v_row_id := v_row.id;
      v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.quantity, 'after', v_after);
    else
      update public.zad_inventory set quantity = v_qty where id = v_row.id;
      v_row_id := v_row.id;
      v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_row.quantity, 'after', v_qty);
    end if;

    insert into public.zad_events (user_id, member_id, client_event_id, kind, payload, occurred_at, source, confidence)
    values (v_uid, v_member, v_cid, v_kind, v_payload, v_occurred, v_source, v_conf)
    returning id into v_event_id;
  exception when unique_violation then
    select * into v_existing from public.zad_events where user_id = v_uid and client_event_id = v_cid;
    if not found then
      raise;
    end if;
    return jsonb_build_object('ok', true, 'duplicate', true, 'event_id', v_existing.id, 'kind', v_existing.kind,
      'row_id', v_existing.payload ->> 'row_id');
  end;

  return jsonb_build_object('ok', true, 'duplicate', false, 'event_id', v_event_id, 'kind', v_kind, 'row_id', v_row_id,
    'before', v_payload -> 'before', 'after', v_payload -> 'after');
end;
$fn$;
revoke all on function public.zad_commit_intent(jsonb) from public, anon, authenticated;
grant execute on function public.zad_commit_intent(jsonb) to service_role;
