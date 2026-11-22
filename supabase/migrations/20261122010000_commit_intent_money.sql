-- الباب الوحيد: مجال الفلوس، المعاملات (ZAD_OR_PLAN م٢.٥، ٢٢/١١). أدوات المعاملات في العقل بتكتب من هنا بس.
--
--   money.logged     {amount, title, txn_kind, wallet?, transfer_to?, category?, merchant_name?, source_type?, for_person?,
--                     created_at?}                                               صف جديد.
--   money.updated    {item_id, patch:{amount?, title?, category?, txn_kind?, for_person?, merchant_name?,
--                     counts_toward_budget?}}                                    حقول معروفة بس، والنوع بيجرّ is_expense معاه.
--   money.deleted    {item_id}                                                   الصف كامل في الحدث، وzad_trash بيحفظه.
--   money.purchase   {purchase}                                                  مصروف بأصناف: بيعدّي على zad_record_purchase_service
--                                                                                (باب الشرا، ترانزاكشن واحدة للفلوس والمخزن والصيدلية).
-- المعاملة لازم تكون بتاعة العميل نفسه (RLS بتاعة zad_transactions: user_id = auth.uid() بس).
-- القيود، نفس validators.ts: المبلغ > ٠ و≤ مليون (بيتقرّب لقرشين)، الوصف ١–٨٠ ومش تخمين («؟» أو مثلاً/يمكن/ربما/غالباً)،
-- النوع والمحفظة من قايمة الـCHECK، التحويل لازم يقول رايح فين، و«لمين» ١–٤٠، والتاريخ مش في المستقبل ومش أقدم من سنة.
-- رفض باب الشرا بيرجع سببه في detail (نتيجة الباب كاملة)، عشان رد «فيه مصروف بنفس المبلغ…» يفضل زي ما هو.
--
-- الباب نفسه زي 20261122000000 بالحرف، وزايد سطر المجال، والرفض بقى بيرجّع detail المجال لو فيه.

create or replace function public.zad_intent_money_fields(p_fields jsonb, p_new boolean)
returns text
language plpgsql
immutable
set search_path = public
as $fn$
declare
  v_amount numeric;
  v_at timestamptz;
begin
  if p_new or p_fields ? 'amount' then
    begin
      v_amount := (p_fields ->> 'amount')::numeric;
    exception when others then
      v_amount := null;
    end;
    if v_amount is null or v_amount <= 0 then
      return 'amount_not_positive';
    elsif v_amount > 1000000 then
      return 'amount_over_cap';
    end if;
  end if;
  if p_new or p_fields ? 'title' then
    if length(btrim(coalesce(p_fields ->> 'title', ''))) not between 1 and 80 then
      return 'title_invalid';
    elsif btrim(p_fields ->> 'title') ~ '[?؟]|(^|\s)(مثلا|مثلاً|يمكن|ربما|غالبا|غالباً)(\s|$)' then
      return 'title_guessed';
    end if;
  end if;
  if (p_new or p_fields ? 'txn_kind') and coalesce(p_fields ->> 'txn_kind', '') not in ('expense', 'income', 'transfer') then
    return 'txn_kind_unknown';
  end if;
  if p_fields ? 'wallet' and coalesce(p_fields ->> 'wallet', '') not in ('cash', 'card', 'bank') then
    return 'wallet_unknown';
  end if;
  if p_new and (p_fields ->> 'txn_kind') = 'transfer'
     and coalesce(p_fields ->> 'transfer_to', '') not in ('cash', 'card', 'bank') then
    return 'transfer_to_missing';
  end if;
  if length(coalesce(p_fields ->> 'category', '')) > 40 or length(coalesce(p_fields ->> 'merchant_name', '')) > 80 then
    return 'text_too_long';
  end if;
  if nullif(btrim(coalesce(p_fields ->> 'for_person', '')), '') is not null
     and length(btrim(p_fields ->> 'for_person')) > 40 then
    return 'for_person_invalid';
  end if;
  if nullif(p_fields ->> 'created_at', '') is not null then
    begin
      v_at := (p_fields ->> 'created_at')::timestamptz;
    exception when others then
      return 'date_invalid';
    end;
  end if;
  if p_fields ? 'counts_toward_budget' and jsonb_typeof(p_fields -> 'counts_toward_budget') <> 'boolean' then
    return 'bad_payload';
  end if;
  return null;
end;
$fn$;

create or replace function public.zad_intent_money(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_patch jsonb;
  v_row public.zad_transactions%rowtype;
  v_reason text;
  v_key text;
  v_kind text;
  v_at timestamptz;
  v_row_id uuid;
  v_before jsonb := '{}'::jsonb;
  v_buy jsonb;
begin
  if p_kind not in ('money.logged', 'money.updated', 'money.deleted', 'money.purchase') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  if p_kind in ('money.updated', 'money.deleted') then
    begin
      select * into v_row from public.zad_transactions
       where id = (v_payload ->> 'item_id')::uuid and user_id = p_uid for update;
    exception when others then
      v_row := null;
    end;
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'item_not_found');
    end if;
  end if;

  if p_kind = 'money.logged' then
    v_reason := public.zad_intent_money_fields(v_payload, true);
    if v_reason is null and nullif(v_payload ->> 'created_at', '') is not null then
      v_at := (v_payload ->> 'created_at')::timestamptz;
      if v_at > now() + interval '5 minutes' or v_at < now() - interval '1 year' then
        v_reason := 'date_invalid';
      end if;
    end if;
    if v_reason is not null then
      return jsonb_build_object('ok', false, 'reason', v_reason);
    end if;
    v_kind := v_payload ->> 'txn_kind';
    insert into public.zad_transactions (user_id, amount, title, category, is_expense, txn_kind, wallet, transfer_to,
                                         source_type, merchant_name, for_person, created_at)
    values (p_uid, round((v_payload ->> 'amount')::numeric, 2), btrim(v_payload ->> 'title'),
            nullif(btrim(coalesce(v_payload ->> 'category', '')), ''),
            -- العمودين مع بعض دايماً (التطبيق بيقرا is_expense والسيرفر txn_kind). التحويل مصروف من ناحية المحفظة.
            v_kind <> 'income', v_kind, coalesce(nullif(v_payload ->> 'wallet', ''), 'card'),
            case when v_kind = 'transfer' then v_payload ->> 'transfer_to' end,
            nullif(v_payload ->> 'source_type', ''), nullif(btrim(coalesce(v_payload ->> 'merchant_name', '')), ''),
            case when v_kind = 'expense' then nullif(btrim(coalesce(v_payload ->> 'for_person', '')), '') end,
            coalesce(v_at, now()))
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'after',
      (select to_jsonb(t) from public.zad_transactions t where t.id = v_row_id));
  elsif p_kind = 'money.updated' then
    v_patch := v_payload -> 'patch';
    if v_patch is null or jsonb_typeof(v_patch) <> 'object' or v_patch = '{}'::jsonb then
      return jsonb_build_object('ok', false, 'reason', 'patch_empty');
    end if;
    for v_key in select jsonb_object_keys(v_patch) loop
      if v_key not in ('amount', 'title', 'category', 'txn_kind', 'for_person', 'merchant_name', 'counts_toward_budget') then
        return jsonb_build_object('ok', false, 'reason', 'patch_field_unknown');
      end if;
      v_before := v_before || jsonb_build_object(v_key, to_jsonb(v_row) -> v_key);
    end loop;
    v_reason := public.zad_intent_money_fields(v_patch, false);
    -- تحويل محتاج «رايح فين»، والتعديل مايقدرش يقوله: من وإلى تحويل بيتسجل معاملة جديدة.
    if v_reason is null and (v_patch ->> 'txn_kind' = 'transfer' or (v_row.txn_kind = 'transfer' and v_patch ? 'txn_kind')) then
      v_reason := 'transfer_change_unsupported';
    end if;
    if v_reason is not null then
      return jsonb_build_object('ok', false, 'reason', v_reason);
    end if;
    update public.zad_transactions
       set amount = case when v_patch ? 'amount' then round((v_patch ->> 'amount')::numeric, 2) else amount end,
           title = case when v_patch ? 'title' then btrim(v_patch ->> 'title') else title end,
           category = case when v_patch ? 'category' then nullif(btrim(coalesce(v_patch ->> 'category', '')), '') else category end,
           txn_kind = coalesce(v_patch ->> 'txn_kind', txn_kind),
           is_expense = case when v_patch ? 'txn_kind' then (v_patch ->> 'txn_kind') <> 'income' else is_expense end,
           for_person = case when v_patch ? 'for_person' then nullif(btrim(coalesce(v_patch ->> 'for_person', '')), '') else for_person end,
           merchant_name = case when v_patch ? 'merchant_name' then nullif(btrim(coalesce(v_patch ->> 'merchant_name', '')), '') else merchant_name end,
           counts_toward_budget = case when v_patch ? 'counts_toward_budget' then (v_patch ->> 'counts_toward_budget')::boolean else counts_toward_budget end
     where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', v_before, 'after',
      (select to_jsonb(t) from public.zad_transactions t where t.id = v_row_id));
  elsif p_kind = 'money.deleted' then
    delete from public.zad_transactions where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row), 'after', null);
  else
    if jsonb_typeof(v_payload -> 'purchase') <> 'object' then
      return jsonb_build_object('ok', false, 'reason', 'bad_payload');
    end if;
    v_reason := public.zad_intent_money_fields(
      (v_payload -> 'purchase') || jsonb_build_object('txn_kind', 'expense'), true);
    if v_reason is not null then
      return jsonb_build_object('ok', false, 'reason', v_reason);
    end if;
    v_buy := public.zad_record_purchase_service(p_uid, v_payload -> 'purchase');
    if (v_buy ->> 'ok')::boolean is not true or nullif(v_buy ->> 'transaction_id', '') is null then
      return jsonb_build_object('ok', false,
        'reason', 'purchase_' || coalesce(v_buy ->> 'status', v_buy ->> 'reason', 'refused'), 'detail', v_buy);
    end if;
    v_row_id := (v_buy ->> 'transaction_id')::uuid;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'after', v_buy);
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
  if v_kind is null or split_part(v_kind, '.', 1) not in ('inventory', 'shopping', 'pharmacy', 'money') then
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
      when 'money' then public.zad_intent_money(v_uid, v_kind, v_payload, v_occurred)
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
    return jsonb_build_object('ok', false, 'reason', v_reason, 'detail', v_res -> 'detail');
  end if;

  return jsonb_build_object('ok', true, 'duplicate', false, 'event_id', v_event_id, 'kind', v_kind,
    'row_id', v_res -> 'row_id', 'before', v_payload -> 'before', 'after', v_payload -> 'after', 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_money_fields(jsonb, boolean) from public, anon, authenticated, service_role;
revoke all on function public.zad_intent_money(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
revoke all on function public.zad_commit_intent(jsonb) from public, anon, authenticated;
grant execute on function public.zad_commit_intent(jsonb) to service_role;
