-- م٩.١ وم٩.٢: الفرد على الحقيقة، والإيقاف المؤقت، والتعارض بيورّث الفرد. بعد memory_temporal_scaffold.sql والمايجريشن.

\set ON_ERROR_STOP on

do $$
declare
  a constant uuid := '00000000-0000-0000-0000-0000000000a1';
  b constant uuid := '00000000-0000-0000-0000-0000000000b1';
  gym constant uuid := 'aaaaaaaa-0000-0000-0000-000000000001';
  coffee constant uuid := 'aaaaaaaa-0000-0000-0000-000000000002';
  ahmed constant uuid := '22222222-0000-0000-0000-0000000000a1';
  b_self constant uuid := '11111111-0000-0000-0000-0000000000b1';
  r jsonb;
  v_pause uuid;
  n int;
  v_member text;
  v_paused timestamptz;
begin
  -- ── الفرد ──
  r := public.zad_memory_set_member(a, gym, ahmed);
  if (r ->> 'ok')::boolean is not true then raise exception 'set_member: %', r; end if;
  if (select member_id from public.zad_memory where id = gym) <> ahmed then raise exception 'member not set'; end if;

  r := public.zad_memory_set_member(a, gym, b_self);
  if r ->> 'reason' <> 'member_not_in_household' then raise exception 'foreign member accepted: %', r; end if;
  r := public.zad_memory_set_member(b, gym, b_self);
  if r ->> 'reason' <> 'unknown_note' then raise exception 'foreign note accepted: %', r; end if;

  -- ── الإيقاف المؤقت: «أحمد وقف الجيم أسبوع» ──
  r := public.zad_memory_pause(a, gym, now() - interval '1 day', 'أحمد وقف الجيم أسبوع');
  if r ->> 'reason' <> 'pause_end_passed' then raise exception 'past pause accepted: %', r; end if;
  r := public.zad_memory_pause(a, gym, now() + interval '400 days', 'أحمد وقف الجيم');
  if r ->> 'reason' <> 'pause_too_long' then raise exception 'long pause accepted: %', r; end if;
  r := public.zad_memory_pause(b, gym, now() + interval '7 days', 'أحمد وقف الجيم');
  if r ->> 'reason' <> 'unknown_note' then raise exception 'foreign pause accepted: %', r; end if;

  r := public.zad_memory_pause(a, gym, now() + interval '7 days', 'أحمد وقف الجيم أسبوع عشان رجله');
  if (r ->> 'ok')::boolean is not true then raise exception 'pause: %', r; end if;
  v_pause := (r ->> 'pause_note_id')::uuid;

  -- العادة ما اتقفلتش ولا اتمسحت: لسه حية، ومتوقفة.
  select count(*) into n from public.zad_memory where id = gym and superseded_by is null and valid_until is null;
  if n <> 1 then raise exception 'habit closed instead of paused'; end if;
  -- ملاحظة السبب مؤقتة لنفس التاريخ، وبتورث الفرد والكيان، ومربوطة بـexplains.
  select count(*) into n from public.zad_memory p
   where p.id = v_pause and p.valid_until = (select paused_until from public.zad_memory where id = gym) and p.member_id = ahmed;
  if n <> 1 then raise exception 'pause note wrong'; end if;
  if not exists (select 1 from public.zad_memory_links where from_id = v_pause and to_id = gym and relation = 'explains') then
    raise exception 'pause link missing';
  end if;
  if not exists (select 1 from public.zad_memory_mentions where memory_id = v_pause) then raise exception 'pause entity not inherited'; end if;

  -- العقل بيشوف الإيقاف واسم الفرد.
  select l.member, l.paused_until into v_member, v_paused from public.zad_memory_live_notes(a, 20) l where l.id = gym;
  if v_member is distinct from 'أحمد' or v_paused is null then raise exception 'live_notes: member=% paused=%', v_member, v_paused; end if;
  select count(*) into n from public.zad_memory_recall_entities(a, 'احمد', 8) l where l.id = gym and l.paused_until is not null;
  if n <> 1 then raise exception 'recall_entities misses the pause'; end if;

  -- بعد التاريخ العادة بترجع لوحدها (paused_until مابيرجعش).
  update public.zad_memory set paused_until = now() - interval '1 minute' where id = gym;
  select l.paused_until into v_paused from public.zad_memory_live_notes(a, 20) l where l.id = gym;
  if v_paused is not null then raise exception 'expired pause still shown'; end if;
  update public.zad_memory set paused_until = now() + interval '7 days' where id = gym;

  -- «رجع الجيم» بدري: العادة شغالة، وملاحظة السبب اتقفلت (مش اتمسحت).
  r := public.zad_memory_resume(a, gym);
  if (r ->> 'ok')::boolean is not true then raise exception 'resume: %', r; end if;
  if (select paused_until from public.zad_memory where id = gym) is not null then raise exception 'still paused'; end if;
  if not exists (select 1 from public.zad_memory where id = v_pause and valid_until <= now()) then raise exception 'pause note not closed'; end if;
  r := public.zad_memory_resume(a, gym);
  if r ->> 'reason' <> 'not_paused' then raise exception 'double resume: %', r; end if;

  -- ── م٩.١: التعارض بيقفل القديمة والجديدة بتورث الفرد ──
  perform public.zad_memory_set_member(a, coffee, ahmed);
  r := public.zad_memory_resolve_conflict(a, coffee, 'general', 'بطل القهوة وبقى بيشرب شاي', 0.7);
  if (r ->> 'ok')::boolean is not true then raise exception 'resolve: %', r; end if;
  if (select member_id from public.zad_memory where id = (r ->> 'new_id')::uuid) is distinct from ahmed then
    raise exception 'new fact lost the member';
  end if;
  select count(*) into n from public.zad_memory_live_notes(a, 60) l where l.id = coffee;
  if n <> 0 then raise exception 'old fact still live'; end if;
  r := public.zad_memory_pause(a, coffee, now() + interval '3 days', 'وقف القهوة يومين');
  if r ->> 'reason' <> 'note_not_live' then raise exception 'superseded note paused: %', r; end if;
  r := public.zad_memory_resolve_conflict(b, gym, 'general', 'حاجة تانية خالص', 0.7);
  if r ->> 'reason' <> 'unknown_note' then raise exception 'foreign resolve: %', r; end if;
end $$;

-- الصلاحيات: الدوال الجديدة للعقل (service_role) بس.
do $$ begin
  if has_function_privilege('authenticated', 'public.zad_memory_pause(uuid, uuid, timestamptz, text)', 'execute')
     or has_function_privilege('anon', 'public.zad_memory_set_member(uuid, uuid, uuid)', 'execute')
     or has_function_privilege('authenticated', 'public.zad_memory_resume(uuid, uuid)', 'execute') then
    raise exception 'memory functions open to clients';
  end if;
end $$;

select 'memory_temporal: all checks passed';
