-- م٩.١ وم٩.٢ (ZAD_OR_PLAN، ٢٢/١١): الذاكرة الزمنية.
--
-- اللي كان موجود من 20261003100000: valid_from وvalid_until وsuperseded_by، والتعارض بيترفض ويتسأل عليه،
-- وzad_memory_resolve_conflict بتقفل القديمة. اللي كان ناقص:
--   ١. (م٩.٢) الحقيقة مش مربوطة بفرد من البيت: «الأخ بيروح الجيم» عن مين؟ ⇒ member_id على zad_household_members.
--   ٢. (م٩.٢) مفيش إيقاف مؤقت: «الأخ وقف الجيم أسبوع» كانت يا إما تتسجل تناقض (وتترفض) يا إما تقفل العادة للأبد.
--      ⇒ paused_until: العادة فاضلة حية بس متوقفة لحد تاريخ، ومعاها ملاحظة مؤقتة بالسبب (valid_until = نفس التاريخ)
--      مربوطة بيها بـ'explains'. بعد التاريخ العادة بترجع لوحدها من غير أي كتابة.
--   ٣. (م٩.١) الحقيقة الجديدة اللي ورثت التعارض مابتورثش الفرد. resolve_conflict بقت بتنقل member_id.
--   القرار إن كلام العميل نفسه في الشات بيقفل القديمة من غير سؤال في zad-brain (remember)، مش هنا.
--
-- المقاس على الحي ٢٢/١١: ٤٤ ملاحظة، ٣٨ حية، ٣ اتحلّ محلها، رابط contradicts واحد والطرفين لسه حيين.
-- zad_household_members فيه صف «أنا» بس لكل حساب (٣٠ صف).

alter table public.zad_memory
  add column if not exists member_id uuid references public.zad_household_members(id) on delete set null,
  add column if not exists paused_until timestamptz;

comment on column public.zad_memory.member_id is
  'م٩.٢: فرد البيت اللي الحقيقة عنه. null = العميل نفسه أو البيت كله. بيتحط من zad_memory_set_member بس (بيتأكد إن الفرد من نفس البيت).';
comment on column public.zad_memory.paused_until is
  'م٩.٢: العادة متوقفة مؤقتاً لحد التاريخ ده («وقف الجيم أسبوع»)، مش اتقفلت. بعده بترجع لوحدها. null = شغالة.';

create index if not exists idx_zad_memory_member on public.zad_memory (member_id) where member_id is not null;

-- ── الفرد ───────────────────────────────────────────────────────────────────────────────────────────────

create or replace function public.zad_memory_set_member(p_user uuid, p_note uuid, p_member uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'not_authorized';
  end if;
  if not exists (select 1 from public.zad_memory where id = p_note and user_id = p_user) then
    return jsonb_build_object('ok', false, 'reason', 'unknown_note');
  end if;
  if p_member is not null and not exists (
    select 1 from public.zad_household_members where id = p_member and user_id = p_user and archived_at is null
  ) then
    return jsonb_build_object('ok', false, 'reason', 'member_not_in_household');
  end if;
  update public.zad_memory set member_id = p_member where id = p_note and user_id = p_user;
  return jsonb_build_object('ok', true, 'note_id', p_note, 'member_id', p_member);
end
$function$;

-- ── الإيقاف المؤقت ──────────────────────────────────────────────────────────────────────────────────────

create or replace function public.zad_memory_pause(p_user uuid, p_note uuid, p_until timestamptz, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_old public.zad_memory%rowtype;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_new uuid;
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'not_authorized';
  end if;
  select * into v_old from public.zad_memory where id = p_note and user_id = p_user for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'unknown_note');
  end if;
  if v_old.superseded_by is not null or (v_old.valid_until is not null and v_old.valid_until <= now()) then
    return jsonb_build_object('ok', false, 'reason', 'note_not_live');
  end if;
  if p_until is null or p_until <= now() then
    return jsonb_build_object('ok', false, 'reason', 'pause_end_passed');
  end if;
  if p_until > now() + interval '366 days' then
    return jsonb_build_object('ok', false, 'reason', 'pause_too_long');
  end if;
  if char_length(v_reason) not between 3 and 200 then
    return jsonb_build_object('ok', false, 'reason', 'pause_reason_length');
  end if;

  update public.zad_memory set paused_until = p_until, last_seen = now() where id = v_old.id;

  insert into public.zad_memory (user_id, scope, note, confidence, family_id, valid_until, member_id)
  values (p_user, v_old.scope, v_reason, greatest(v_old.confidence, 0.6), v_old.family_id, p_until, v_old.member_id)
  returning id into v_new;

  insert into public.zad_memory_links (user_id, from_id, to_id, relation, strength, evidence_count)
  values (p_user, v_new, v_old.id, 'explains', 0.9, 1)
  on conflict do nothing;

  insert into public.zad_memory_mentions (memory_id, entity_id, user_id)
  select v_new, mm.entity_id, mm.user_id from public.zad_memory_mentions mm where mm.memory_id = v_old.id
  on conflict do nothing;

  return jsonb_build_object('ok', true, 'note_id', v_old.id, 'pause_note_id', v_new, 'paused_until', p_until);
end
$function$;

-- «رجع الجيم» قبل المعاد: العادة بتشتغل تاني، وملاحظة السبب بتتقفل (مش بتتمسح).
create or replace function public.zad_memory_resume(p_user uuid, p_note uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_paused timestamptz;
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'not_authorized';
  end if;
  select paused_until into v_paused from public.zad_memory where id = p_note and user_id = p_user for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'unknown_note');
  end if;
  if v_paused is null or v_paused <= now() then
    return jsonb_build_object('ok', false, 'reason', 'not_paused');
  end if;
  update public.zad_memory set paused_until = null, last_seen = now() where id = p_note;
  update public.zad_memory m
     set valid_until = greatest(m.valid_from, now())
   where m.user_id = p_user
     and m.valid_until > now()
     and m.id in (select l.from_id from public.zad_memory_links l
                   where l.user_id = p_user and l.to_id = p_note and l.relation = 'explains');
  return jsonb_build_object('ok', true, 'note_id', p_note);
end
$function$;

-- ── التعارض: الجديدة بتورث الفرد ───────────────────────────────────────────────────────────────────────

create or replace function public.zad_memory_resolve_conflict(
  p_user uuid,
  p_old_id uuid,
  p_scope text,
  p_note text,
  p_conf real default 0.6
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
declare
  v_new_id uuid;
  v_member uuid;
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'not_authorized';
  end if;

  select member_id into v_member from public.zad_memory where id = p_old_id and user_id = p_user;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'unknown_note');
  end if;

  insert into public.zad_memory(user_id, scope, note, confidence, member_id)
  values (p_user, p_scope, p_note, coalesce(p_conf, 0.6), v_member)
  returning id into v_new_id;

  update public.zad_memory
     set confidence = greatest(0.1, confidence - 0.3),
         last_seen = now(),
         superseded_by = v_new_id,
         valid_until = greatest(valid_from, least(coalesce(valid_until, now()), now()))
   where id = p_old_id;

  insert into public.zad_memory_links(user_id, from_id, to_id, relation, strength, evidence_count)
  values (p_user, v_new_id, p_old_id, 'contradicts', 0.8, 1)
  on conflict do nothing;

  insert into public.zad_memory_mentions (memory_id, entity_id, user_id)
  select v_new_id, mm.entity_id, mm.user_id
    from public.zad_memory_mentions mm
   where mm.memory_id = p_old_id
  on conflict do nothing;

  return jsonb_build_object('ok', true, 'new_id', v_new_id, 'old_id', p_old_id);
end
$function$;

-- ── القراية: الفرد والإيقاف بيبانوا للعقل ──────────────────────────────────────────────────────────────
-- نوع الرجوع اتغير ⇒ drop وcreate. نفس الشروط بالحرف، وزيادة paused_until (لو لسه جاي) واسم الفرد.

drop function if exists public.zad_memory_live_notes(uuid, integer);
create function public.zad_memory_live_notes(p_user uuid, p_limit integer default 20)
returns table (
  id uuid, scope text, note text, confidence real, evidence_count integer,
  last_seen timestamptz, valid_until timestamptz, about text[], paused_until timestamptz, member text
)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  select m.id, m.scope, m.note, m.confidence, m.evidence_count, m.last_seen, m.valid_until,
         coalesce(array(
           select e.name from public.zad_memory_mentions mm
             join public.zad_memory_entities e on e.id = mm.entity_id
            where mm.memory_id = m.id
            order by e.name
         ), '{}'::text[]) as about,
         case when m.paused_until > now() then m.paused_until end,
         hm.display_name
    from public.zad_memory m
    left join public.zad_household_members hm on hm.id = m.member_id and hm.user_id = m.user_id
   where m.user_id = p_user
     and (auth.uid() is null or auth.uid() = p_user)
     and m.superseded_by is null
     and (m.valid_until is null or m.valid_until > now())
   order by m.confidence desc, m.last_seen desc
   limit greatest(1, least(coalesce(p_limit, 20), 60));
$function$;

drop function if exists public.zad_memory_recall_entities(uuid, text, integer);
create function public.zad_memory_recall_entities(p_user uuid, p_text text, p_limit integer default 8)
returns table (
  id uuid, scope text, note text, confidence real, evidence_count integer,
  last_seen timestamptz, valid_until timestamptz, about text[], paused_until timestamptz, member text
)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  with hit as (
    select e.id
      from public.zad_memory_entities e
     where e.user_id = p_user
       and (auth.uid() is null or auth.uid() = p_user)
       and position(' ' || e.name_key || ' ' in ' ' || regexp_replace(coalesce(p_text, ''), '\s+', ' ', 'g') || ' ') > 0
  )
  select m.id, m.scope, m.note, m.confidence, m.evidence_count, m.last_seen, m.valid_until,
         coalesce(array(
           select e.name from public.zad_memory_mentions mm2
             join public.zad_memory_entities e on e.id = mm2.entity_id
            where mm2.memory_id = m.id
            order by e.name
         ), '{}'::text[]) as about,
         case when m.paused_until > now() then m.paused_until end,
         hm.display_name
    from public.zad_memory m
    left join public.zad_household_members hm on hm.id = m.member_id and hm.user_id = m.user_id
   where m.user_id = p_user
     and m.superseded_by is null
     and (m.valid_until is null or m.valid_until > now())
     and exists (select 1 from public.zad_memory_mentions mm where mm.memory_id = m.id and mm.entity_id in (select id from hit))
   order by m.confidence desc, m.last_seen desc
   limit greatest(1, least(coalesce(p_limit, 8), 20));
$function$;

revoke all on function public.zad_memory_live_notes(uuid, integer) from public, anon;
grant execute on function public.zad_memory_live_notes(uuid, integer) to authenticated, service_role;
revoke all on function public.zad_memory_recall_entities(uuid, text, integer) from public, anon, authenticated;
grant execute on function public.zad_memory_recall_entities(uuid, text, integer) to service_role;

revoke all on function public.zad_memory_set_member(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.zad_memory_pause(uuid, uuid, timestamptz, text) from public, anon, authenticated;
revoke all on function public.zad_memory_resume(uuid, uuid) from public, anon, authenticated;
grant execute on function public.zad_memory_set_member(uuid, uuid, uuid) to service_role;
grant execute on function public.zad_memory_pause(uuid, uuid, timestamptz, text) to service_role;
grant execute on function public.zad_memory_resume(uuid, uuid) to service_role;
revoke execute on function public.zad_memory_resolve_conflict(uuid, uuid, text, text, real) from public, anon, authenticated;
grant execute on function public.zad_memory_resolve_conflict(uuid, uuid, text, text, real) to service_role;
