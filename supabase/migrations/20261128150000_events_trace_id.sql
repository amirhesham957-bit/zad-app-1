-- P1.7: trace_id واحد بيمشي من زرار فلاتر لحد صف zad_events.
-- العميل بيبعت الهيدر x-zad-trace-id، والفانكشن بتحطه في النية (p_intent.trace_id)، والباب بيكتبه في الحدث.
-- اختياري: النية من غير trace_id (أو بشكل غلط) بتتكتب عادي وtrace_id = null. الباقي في الباب زي ما هو (member_facts).

alter table public.zad_events
  add column if not exists trace_id text check (trace_id is null or length(trace_id) between 8 and 64);

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
  v_trace text := nullif(btrim(coalesce(p_intent ->> 'trace_id', '')), '');
begin
  -- trace_id اختياري: لو شكله غلط بنتجاهله (التتبّع مايوقّفش كتابة).
  if v_trace is not null and length(v_trace) not between 8 and 64 then
    v_trace := null;
  end if;

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
  if v_kind is null or split_part(v_kind, '.', 1) not in ('inventory', 'shopping', 'pharmacy', 'money', 'subscription', 'debt',
                                                           'obligation', 'maintenance', 'document', 'appointment', 'settings', 'goal', 'trait', 'profile') then
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
    -- if/elsif مش case: case بيحضّر كل النداءات مرة واحدة ويقع لو دالة مجال لسه مش موجودة.
    if split_part(v_kind, '.', 1) = 'inventory' then
      v_res := public.zad_intent_inventory(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'shopping' then
      v_res := public.zad_intent_shopping(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'pharmacy' then
      v_res := public.zad_intent_pharmacy(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'money' then
      v_res := public.zad_intent_money(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'subscription' then
      v_res := public.zad_intent_subscription(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'debt' then
      v_res := public.zad_intent_debt(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'obligation' then
      v_res := public.zad_intent_obligation(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'maintenance' then
      v_res := public.zad_intent_maintenance(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'document' then
      v_res := public.zad_intent_document(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'appointment' then
      v_res := public.zad_intent_appointment(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'settings' then
      v_res := public.zad_intent_settings(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'goal' then
      v_res := public.zad_intent_goal(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'trait' then
      v_res := public.zad_intent_trait(v_uid, v_kind, v_payload, v_occurred);
    elsif split_part(v_kind, '.', 1) = 'profile' then
      v_res := public.zad_intent_profile(v_uid, v_kind, v_payload, v_occurred);
    end if;
    if (v_res ->> 'ok')::boolean is not true then
      v_reason := coalesce(v_res ->> 'reason', 'refused');
    else
      v_payload := v_res -> 'payload';
      insert into public.zad_events (user_id, member_id, client_event_id, kind, payload, occurred_at, source, confidence, trace_id)
      values (v_uid, v_member, v_cid, v_kind, v_payload, v_occurred, v_source, v_conf, v_trace)
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

revoke all on function public.zad_commit_intent(jsonb) from public, anon, authenticated;
grant execute on function public.zad_commit_intent(jsonb) to service_role;
