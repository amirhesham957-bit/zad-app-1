-- =====================================================
-- المناسبات في ذاكرة العقل: أعياد الميلاد وذكرى الجواز (قرار المالك 2026-10-05: «الخيار B»).
--
-- «عيد ميلاد ماما ١٢ مارس» حقيقة عن شخص — مكانها zad_memory زي أي حقيقة تانية
-- (ZAD_LIVING_BRAIN.md §١: «أي معرفة عن العميل مكانها zad_memory وتوابعها»، وجدول
-- family_birthdays منفصل كان هيبقى الذاكرة الموازية اللي اترفضت مرتين). الملاحظة نفسها
-- بتفضل جملة عادية بتظهر في الشات وشاشة الذاكرة، ومعاها ٣ أعمدة بيقراها الكود من غير موديل:
-- تحية الصبح (قبلها بـ٣ أيام ويومها) وكارت التطبيق.
--
--   occasion      birthday | anniversary
--   occasion_md   'MM-DD' — من غير سنة؛ ٢٩ فبراير بيتحسب ٢٨ في السنة البسيطة (في الكود).
--   occasion_for  اسم الشخص بعد normalizeForPerson («ماما»، «يوسف»)؛ null = العميل نفسه.
--
-- حاجتين كانوا هيمسحوا المناسبة بصمت، واتقفلوا هنا:
--   - التقليم (zad_memory_prune، ٦٠ ملاحظة لكل عميل بالثقة × الأدلة): عيد ميلاد اتقال مرة
--     واحدة ترتيبه واطي وكان هيتشال. المناسبات برّه الترتيب والعدّ.
--   - الدمج في zad_memory_upsert (تشابه ≥ ٠٫٦ بيكتب النص الجديد فوق القديم): «عيد ميلاد ماما
--     ١٥ مارس» من الاستخلاص كان هيغيّر الجملة ويسيب occasion_md القديم. المناسبات برّه الدمج؛
--     تعديلها من zad_memory_set_occasion بس.
-- =====================================================

alter table public.zad_memory
  add column if not exists occasion text,
  add column if not exists occasion_md text,
  add column if not exists occasion_for text;

alter table public.zad_memory drop constraint if exists zad_memory_occasion_kind;
alter table public.zad_memory
  add constraint zad_memory_occasion_kind check (occasion is null or occasion in ('birthday', 'anniversary'));

alter table public.zad_memory drop constraint if exists zad_memory_occasion_md_format;
alter table public.zad_memory
  add constraint zad_memory_occasion_md_format check (
    occasion_md is null or occasion_md ~ '^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'
  );

alter table public.zad_memory drop constraint if exists zad_memory_occasion_complete;
alter table public.zad_memory
  add constraint zad_memory_occasion_complete check (
    (occasion is null and occasion_md is null and occasion_for is null)
    or (occasion is not null and occasion_md is not null)
  );

alter table public.zad_memory drop constraint if exists zad_memory_occasion_for_length;
alter table public.zad_memory
  add constraint zad_memory_occasion_for_length check (
    occasion_for is null or char_length(occasion_for) between 1 and 60
  );

create index if not exists idx_zad_memory_occasions
  on public.zad_memory (user_id)
  where occasion is not null and superseded_by is null;

comment on column public.zad_memory.occasion is
  'birthday | anniversary — الملاحظة مناسبة سنوية. بيكتبها zad_memory_set_occasion بس.';
comment on column public.zad_memory.occasion_md is
  'يوم المناسبة كل سنة، MM-DD.';
comment on column public.zad_memory.occasion_for is
  'صاحب المناسبة («ماما»)؛ null = العميل نفسه.';

-- ── الكتابة ──────────────────────────────────────────────────────────────────

/**
 * يسجّل مناسبة أو يصحّحها: مناسبة حية لنفس الشخص ونفس النوع ⇒ التاريخ والجملة بيتغيّروا
 * (العميل صحّح)، وإلا ملاحظة جديدة. بيرجّع id الملاحظة عشان العقل يربطها بكيان الشخص.
 * أي مدخل مش مفهوم ⇒ exception برسالة واضحة، مش null صامت.
 */
create or replace function public.zad_memory_set_occasion(
  p_user uuid,
  p_occasion text,
  p_for text,
  p_md text,
  p_note text
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_for text := nullif(btrim(coalesce(p_for, '')), '');
  v_note text := btrim(coalesce(p_note, ''));
  v_id uuid;
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'zad_memory_set_occasion: p_user must match the authenticated caller';
  end if;
  if p_occasion is null or p_occasion not in ('birthday', 'anniversary') then
    raise exception 'zad_memory_set_occasion: unknown occasion %', p_occasion;
  end if;
  -- الشكل والتاريخ نفسه: ٣١-٠٤ شكلها صح ومالهاش يوم. طول الشهر من سنة كبيسة (٢٠٠٠)، فـ٢٩
  -- فبراير مقبول. (to_date على ٣٠ فبراير بيرمي خطأ تاريخ بدل رسالة مفهومة.)
  if p_md is null or p_md !~ '^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'
     or split_part(p_md, '-', 2)::int > extract(day from
          make_date(2000, split_part(p_md, '-', 1)::int, 1) + interval '1 month' - interval '1 day') then
    raise exception 'zad_memory_set_occasion: bad date %', p_md;
  end if;
  if v_for is not null and char_length(v_for) > 60 then
    raise exception 'zad_memory_set_occasion: name too long';
  end if;
  if char_length(v_note) not between 1 and 200 then
    raise exception 'zad_memory_set_occasion: note must be 1-200 characters';
  end if;

  select id into v_id
    from public.zad_memory
   where user_id = p_user
     and occasion = p_occasion
     and coalesce(lower(occasion_for), '') = coalesce(lower(v_for), '')
     and superseded_by is null
     and (valid_until is null or valid_until > now())
   order by last_seen desc
   limit 1;

  if v_id is not null then
    update public.zad_memory
       set occasion_md = p_md,
           note = v_note,
           embedding = null,
           evidence_count = evidence_count + 1,
           confidence = greatest(confidence, 0.9),
           last_seen = now()
     where id = v_id;
    return v_id;
  end if;

  insert into public.zad_memory (user_id, scope, note, confidence, occasion, occasion_md, occasion_for)
  values (p_user, 'general', v_note, 0.9, p_occasion, p_md, v_for)
  returning id into v_id;
  return v_id;
end
$function$;

-- Supabase بيدّي anon وauthenticated EXECUTE على أي دالة جديدة (default privileges) —
-- الشيل بالاسم، مش من public بس (فخ 20261003100000).
revoke all on function public.zad_memory_set_occasion(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.zad_memory_set_occasion(uuid, text, text, text, text) to service_role;

-- ── القراءة ──────────────────────────────────────────────────────────────────

/** مناسبات العميل الحية — تحية الصبح وكارت التطبيق (اللي بيحسب «النهارده» و«بعد ٣ أيام» بنفسه). */
create or replace function public.zad_memory_occasions(p_user uuid)
returns table (id uuid, occasion text, occasion_for text, occasion_md text, note text)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  select m.id, m.occasion, m.occasion_for, m.occasion_md, m.note
    from public.zad_memory m
   where m.user_id = p_user
     and (auth.uid() is null or auth.uid() = p_user)
     and m.occasion is not null
     and m.superseded_by is null
     and (m.valid_until is null or m.valid_until > now())
   order by m.occasion_md, m.occasion_for nulls first
   limit 100;
$function$;

revoke all on function public.zad_memory_occasions(uuid) from public, anon;
grant execute on function public.zad_memory_occasions(uuid) to authenticated, service_role;

-- ── التقليم: المناسبات برّه العدّ ─────────────────────────────────────────────

create or replace function public.zad_memory_prune()
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
begin
  delete from public.zad_memory m
  where id in (
    select id from (
      select id, row_number() over (
        partition by user_id
        order by (superseded_by is null and (valid_until is null or valid_until > now())) desc,
                 confidence * evidence_count desc, last_seen desc
      ) as rn
      from public.zad_memory
      -- عيد ميلاد اتقال مرة واحدة مايتشالش عشان ثقته × أدلته واطية (20261006000000).
      where occasion is null
    ) ranked
    where rn > 60
  );

  delete from public.zad_memory_entities e
   where e.last_seen < now() - interval '30 days'
     and not exists (select 1 from public.zad_memory_mentions mm where mm.entity_id = e.id);
end $function$;

-- مالهاش فحص auth.uid() وبتمسح عبر كل العملاء، والكرون الأسبوعي (0001_zad_brain.sql) هو
-- الوحيد اللي بيناديها، كـpostgres. لقاها اختبار الدالة دي: anon كان معاه EXECUTE من
-- الصلاحيات الافتراضية — أي حد بالمفتاح العام كان يقدر يشغّل التقليم.
revoke all on function public.zad_memory_prune() from public, anon, authenticated;
grant execute on function public.zad_memory_prune() to service_role;

-- ── الدمج: المناسبات برّه ─────────────────────────────────────────────────────
-- نفس جسم 20261003100000 بالحرف، غير سطر `occasion is null` في اختيار الملاحظة اللي تتدمج.

create or replace function public.zad_memory_upsert(
  p_user uuid,
  p_scope text,
  p_note text,
  p_conf real default 0.5,
  p_family_id uuid default null::uuid,
  p_valid_until timestamptz default null
)
returns text
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
declare
  v_id uuid;
  v_sim real;
  v_note text;
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'zad_memory_upsert: p_user must match the authenticated caller';
  end if;

  -- حقيقة خلصت قبل ما تتكتب مالهاش مكان في الحاضر.
  if p_valid_until is not null and p_valid_until <= now() then
    return 'expired';
  end if;

  -- الدمج على الحية بس: ملاحظة اتقفلت (اتحلّ محلها أو انتهت) تاريخ، مش حاجة تتقوّى.
  -- والمناسبة مابتتدمجش: تاريخها في occasion_md، والنص لوحده كان هيبقى غلط (20261006000000).
  select id, note, similarity(note, p_note)
    into v_id, v_note, v_sim
    from public.zad_memory
   where user_id = p_user and scope = p_scope
     and superseded_by is null
     and (valid_until is null or valid_until > now())
     and occasion is null
   order by similarity(note, p_note) desc
   limit 1;

  if v_id is not null and v_sim >= 0.6 then
    if public.zad_text_has_negation(v_note) <> public.zad_text_has_negation(p_note) then
      return 'conflict';
    end if;

    update public.zad_memory
       set evidence_count = evidence_count + 1,
           confidence = least(1.0, confidence + 0.1),
           last_seen = now(),
           note = p_note,
           embedding = null,
           family_id = coalesce(p_family_id, family_id),
           -- تكرار من غير تاريخ مايلغيش انتهاء معروف («عندنا ضيوف» بعد «لحد الجمعة»).
           valid_until = coalesce(p_valid_until, valid_until)
     where id = v_id;
    return 'strengthened';
  end if;

  insert into public.zad_memory(user_id, scope, note, confidence, family_id, valid_until)
  values (p_user, p_scope, p_note, coalesce(p_conf, 0.5), p_family_id, p_valid_until);
  return 'inserted';
end
$function$;
