-- P2.2: سمات الفرد في البيت (معيل، كبيرة، لوحده، فيها قاصر، مسافرة) بتاريخ بداية ونهاية ومصدر.
-- الكتابة من الباب الوحيد بس (zad_commit_intent ⇐ zad_intent_trait): trait.set و trait.end. سمة مفتوحة واحدة لكل (فرد، سمة).
--
--   trait.set  {member_id, trait, source, starts_on?}   يفتح السمة. مفتوحة قبل كده ⇐ trait_already_open.
--   trait.end  {member_id, trait, ends_on?}             يقفل السمة المفتوحة (ends_on الافتراضي النهارده). مفيش مفتوحة ⇐ trait_not_open.

create table if not exists public.zad_household_traits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  member_id uuid not null,
  trait text not null check (trait in ('breadwinner', 'elder', 'alone', 'has_minor', 'travelling')),
  starts_on date not null default current_date,
  ends_on date check (ends_on is null or ends_on >= starts_on),
  source text not null check (source in ('said', 'observed', 'inferred')),
  created_at timestamptz not null default now(),
  foreign key (member_id, user_id) references public.zad_household_members (id, user_id)
);
create unique index if not exists zad_household_traits_one_open
  on public.zad_household_traits (member_id, trait) where ends_on is null;
create index if not exists zad_household_traits_user_idx on public.zad_household_traits (user_id, member_id);

alter table public.zad_household_traits enable row level security;
drop policy if exists household_traits_read_own on public.zad_household_traits;
create policy household_traits_read_own on public.zad_household_traits
  for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete, truncate on public.zad_household_traits from anon, authenticated;

create or replace function public.zad_intent_trait(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_member uuid;
  v_trait text := nullif(btrim(coalesce(p_payload ->> 'trait', '')), '');
  v_source text;
  v_starts date;
  v_ends date;
  v_row public.zad_household_traits%rowtype;
  v_row_id uuid;
begin
  if p_kind not in ('trait.set', 'trait.end') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;
  if v_trait is null or v_trait not in ('breadwinner', 'elder', 'alone', 'has_minor', 'travelling') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_trait');
  end if;
  begin
    v_member := (v_payload ->> 'member_id')::uuid;
  exception when others then
    v_member := null;
  end;
  if v_member is null or not exists (
    select 1 from public.zad_household_members where id = v_member and user_id = p_uid and archived_at is null
  ) then
    return jsonb_build_object('ok', false, 'reason', 'member_not_in_household');
  end if;

  select * into v_row from public.zad_household_traits
   where member_id = v_member and user_id = p_uid and trait = v_trait and ends_on is null for update;

  if p_kind = 'trait.set' then
    v_source := v_payload ->> 'source';
    if v_source is null or v_source not in ('said', 'observed', 'inferred') then
      return jsonb_build_object('ok', false, 'reason', 'bad_source');
    end if;
    if nullif(btrim(coalesce(v_payload ->> 'starts_on', '')), '') is not null then
      begin
        v_starts := left(btrim(v_payload ->> 'starts_on'), 10)::date;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'trait_date_invalid');
      end;
    end if;
    if v_row.id is not null then
      return jsonb_build_object('ok', false, 'reason', 'trait_already_open');
    end if;
    insert into public.zad_household_traits (user_id, member_id, trait, starts_on, source)
    values (p_uid, v_member, v_trait, coalesce(v_starts, current_date), v_source)
    returning id into v_row_id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', null::jsonb,
      'after', (select to_jsonb(t) from public.zad_household_traits t where t.id = v_row_id));
  else
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'trait_not_open');
    end if;
    if nullif(btrim(coalesce(v_payload ->> 'ends_on', '')), '') is not null then
      begin
        v_ends := left(btrim(v_payload ->> 'ends_on'), 10)::date;
      exception when others then
        return jsonb_build_object('ok', false, 'reason', 'trait_date_invalid');
      end;
    end if;
    v_ends := coalesce(v_ends, greatest(current_date, v_row.starts_on));
    if v_ends < v_row.starts_on then
      return jsonb_build_object('ok', false, 'reason', 'trait_date_invalid');
    end if;
    update public.zad_household_traits set ends_on = v_ends where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row),
      'after', (select to_jsonb(t) from public.zad_household_traits t where t.id = v_row_id));
  end if;

  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_trait(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;

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
  if v_kind is null or split_part(v_kind, '.', 1) not in ('inventory', 'shopping', 'pharmacy', 'money', 'subscription', 'debt',
                                                           'obligation', 'maintenance', 'document', 'appointment', 'settings', 'goal', 'trait') then
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
    end if;
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

revoke all on function public.zad_commit_intent(jsonb) from public, anon, authenticated;
grant execute on function public.zad_commit_intent(jsonb) to service_role;
