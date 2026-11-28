-- P3.1: سؤال الحقيقة اليومي. حقيقة مستنتجة (source = inferred) بتتسأل مرة في اليوم بالكتير:
--   «آه» = profile.fact_set source said ثقة ١ (قالها)؛ «لأ» = profile.fact_deny (بتتقفل ومابتتسألش ولا بتتستنتج ١٨٠ يوم).
--   profile.fact_asked = علّم إن السؤال اتبعت (asked_at). كله من الباب الوحيد، مفيش كتابة تانية.
--   fact_set inferred على (فرد، مفتاح) اتنفى من أقل من ١٨٠ يوم ⇒ fact_denied_recently.

alter table public.zad_member_facts add column if not exists asked_at timestamptz;
alter table public.zad_member_facts add column if not exists denied_at timestamptz;
create index if not exists zad_member_facts_denied_idx on public.zad_member_facts (member_id, key) where denied_at is not null;

create or replace function public.zad_intent_profile(p_uid uuid, p_kind text, p_payload jsonb, p_occurred timestamptz)
returns jsonb
language plpgsql
set search_path = public
as $fn$
declare
  v_payload jsonb := p_payload;
  v_member uuid;
  v_key text := btrim(coalesce(p_payload ->> 'key', ''));
  v_value text;
  v_source text;
  v_conf numeric;
  v_evidence text;
  v_expires timestamptz;
  v_row public.zad_member_facts%rowtype;
  v_row_id uuid;
begin
  if p_kind not in ('profile.fact_set', 'profile.fact_forget', 'profile.fact_asked', 'profile.fact_deny') then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
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
  if length(v_key) not between 1 and 60 then
    return jsonb_build_object('ok', false, 'reason', 'fact_invalid');
  end if;

  select * into v_row from public.zad_member_facts
   where member_id = v_member and user_id = p_uid and key = v_key and expires_at is null for update;

  if p_kind = 'profile.fact_set' then
    v_value := btrim(coalesce(v_payload ->> 'value', ''));
    v_source := v_payload ->> 'source';
    v_evidence := nullif(btrim(coalesce(v_payload ->> 'evidence', '')), '');
    if length(v_value) not between 1 and 500 or length(coalesce(v_evidence, '')) > 500 then
      return jsonb_build_object('ok', false, 'reason', 'fact_invalid');
    end if;
    if v_source is null or v_source not in ('said', 'observed', 'inferred') then
      return jsonb_build_object('ok', false, 'reason', 'bad_source');
    end if;
    begin
      v_conf := coalesce(nullif(btrim(coalesce(v_payload ->> 'confidence', '')), '')::numeric, case when v_source = 'said' then 1 else null end);
      if nullif(btrim(coalesce(v_payload ->> 'expires_at', '')), '') is not null then
        v_expires := (v_payload ->> 'expires_at')::timestamptz;
      end if;
    exception when others then
      return jsonb_build_object('ok', false, 'reason', 'fact_invalid');
    end;
    if v_source = 'inferred' and (v_conf is null or v_conf > 0.8 or v_evidence is null) then
      return jsonb_build_object('ok', false, 'reason', 'inferred_needs_evidence');
    end if;
    -- «لأ» = مايتسألش ولا يتستنتج تاني ١٨٠ يوم (P3.1).
    if v_source = 'inferred' and exists (
      select 1 from public.zad_member_facts
       where member_id = v_member and user_id = p_uid and key = v_key and denied_at is not null and denied_at > now() - interval '180 days'
    ) then
      return jsonb_build_object('ok', false, 'reason', 'fact_denied_recently');
    end if;
    v_conf := coalesce(v_conf, 1);
    if v_conf not between 0 and 1 then
      return jsonb_build_object('ok', false, 'reason', 'fact_invalid');
    end if;
    if v_expires is not null and v_expires <= now() then
      return jsonb_build_object('ok', false, 'reason', 'fact_invalid');
    end if;

    if v_row.id is not null then
      update public.zad_member_facts
         set value = v_value, source = v_source, confidence = v_conf, evidence = v_evidence,
             expires_at = v_expires, updated_at = now(),
             asked_at = case when v_row.value is distinct from v_value and v_source = 'inferred' then null else asked_at end
       where id = v_row.id;
      v_row_id := v_row.id;
    else
      insert into public.zad_member_facts (user_id, member_id, key, value, source, confidence, evidence, expires_at)
      values (p_uid, v_member, v_key, v_value, v_source, v_conf, v_evidence, v_expires)
      returning id into v_row_id;
    end if;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', case when v_row.id is null then null else to_jsonb(v_row) end,
      'after', (select to_jsonb(t) from public.zad_member_facts t where t.id = v_row_id));
  elsif p_kind = 'profile.fact_asked' then
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'fact_not_found');
    end if;
    update public.zad_member_facts set asked_at = now(), updated_at = now() where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row),
      'after', (select to_jsonb(t) from public.zad_member_facts t where t.id = v_row_id));
  elsif p_kind = 'profile.fact_deny' then
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'fact_not_found');
    end if;
    update public.zad_member_facts set expires_at = now(), denied_at = now(), updated_at = now() where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row),
      'after', (select to_jsonb(t) from public.zad_member_facts t where t.id = v_row_id));
  else
    if v_row.id is null then
      return jsonb_build_object('ok', false, 'reason', 'fact_not_found');
    end if;
    update public.zad_member_facts set expires_at = now(), updated_at = now() where id = v_row.id;
    v_row_id := v_row.id;
    v_payload := v_payload || jsonb_build_object('row_id', v_row_id, 'before', to_jsonb(v_row),
      'after', (select to_jsonb(t) from public.zad_member_facts t where t.id = v_row_id));
  end if;

  return jsonb_build_object('ok', true, 'row_id', v_row_id, 'payload', v_payload);
end;
$fn$;

revoke all on function public.zad_intent_profile(uuid, text, jsonb, timestamptz) from public, anon, authenticated, service_role;
