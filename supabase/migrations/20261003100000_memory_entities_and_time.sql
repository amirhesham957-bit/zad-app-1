-- =====================================================
-- الذاكرة بكيانات وزمن (docs/agent/ZAD_LIVING_BRAIN.md، الشريحة ١ — قرار المالك 2026-10-03).
--
-- `zad_memory` كانت جمل مسطّحة: «ماما بتاخد دوا الضغط الساعة ١٠» و«ماما بتحب الشاي» ملاحظتين
-- مالهمش أي صلة ببعض غير إن الاتنين فيهم كلمة «ماما». ومفيش زمن: «أخويا أحمد عندنا لحد
-- الجمعة» بتفضل صحيحة للأبد، و«بقيت بشرب شاي مش قهوة» كانت بتسيب القديمة حية بثقة أقل.
--
-- ده **توسيع لنفس الجدول**، مش الشبكة اللي EPIC_1_4 §0 رفضها: مفيش graph_nodes/graph_edges
-- عامة، ولا vector(1536)، ولا دالة traversal. الكيان اسم بتشاور عليه ملاحظات — زي نوت
-- أوبسيديان بتتعمل لما تكتب [[ماما]] — والزمن تلات أعمدة على zad_memory نفسها.
--
-- «حية» = superseded_by is null and (valid_until is null or valid_until > now()).
-- كل القراءات (البحث الدلالي، التعارض، كشف التناقض، التقليم، سناب شوت العقل) على الحية بس.
-- المنتهية مابتتمسحش — هي التاريخ («كان بيحب القهوة لحد أكتوبر»).
-- =====================================================

-- ── الزمن ────────────────────────────────────────────────────────────────────

alter table public.zad_memory
  add column if not exists valid_from timestamptz not null default now(),
  add column if not exists valid_until timestamptz,
  add column if not exists superseded_by uuid references public.zad_memory(id) on delete set null;

-- الصفوف القديمة خدت now() من الـdefault؛ بدايتها الحقيقية هي وقت كتابتها.
update public.zad_memory set valid_from = created_at where valid_from > created_at;

alter table public.zad_memory drop constraint if exists zad_memory_valid_range;
alter table public.zad_memory
  add constraint zad_memory_valid_range check (valid_until is null or valid_until >= valid_from);

alter table public.zad_memory drop constraint if exists zad_memory_not_superseded_by_self;
alter table public.zad_memory
  add constraint zad_memory_not_superseded_by_self check (superseded_by is null or superseded_by <> id);

create index if not exists idx_zad_memory_live
  on public.zad_memory (user_id, confidence desc)
  where superseded_by is null;

comment on column public.zad_memory.valid_from is
  'من إمتى الحقيقة دي صحيحة. الصفوف اللي قبل 20261003100000 = created_at.';
comment on column public.zad_memory.valid_until is
  'null = دائمة. تاريخ = حقيقة مؤقتة («عندنا ضيوف لحد الجمعة»)؛ بعده الملاحظة بتخرج من كل قراءة ومابتتمسحش.';
comment on column public.zad_memory.superseded_by is
  'الملاحظة اللي حلّت محلها لما العميل حسم تعارض. null = لسه الحقيقة الحالية.';

-- ── الكيانات ─────────────────────────────────────────────────────────────────

create table if not exists public.zad_memory_entities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  -- محصور عمداً، نفس سبب zad_memory_links.relation: نوع حر = كل تشغيلة تخترع اسم.
  kind text not null check (kind in ('person', 'place', 'item', 'org')),
  -- الاسم زي ما بيتعرض («ماما»، «كارفور المعادي»)، بعد التوحيد في zad-brain
  -- (normalizeForPerson / cleanText) — مصدر واحد للتوحيد، مش نسخة تانية هنا.
  name text not null check (char_length(name) between 1 and 60),
  -- مفتاح المقارنة (itemKey في zad-brain): من غير تشكيل، ألف/ياء/تاء مربوطة موحّدين.
  name_key text not null check (char_length(name_key) between 1 and 60),
  created_at timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  constraint zad_memory_entities_one_per_name unique (user_id, kind, name_key)
);

create index if not exists zad_memory_entities_user_idx on public.zad_memory_entities (user_id);

create table if not exists public.zad_memory_mentions (
  memory_id uuid not null references public.zad_memory(id) on delete cascade,
  entity_id uuid not null references public.zad_memory_entities(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (memory_id, entity_id)
);

create index if not exists zad_memory_mentions_entity_idx on public.zad_memory_mentions (entity_id);
create index if not exists zad_memory_mentions_user_idx on public.zad_memory_mentions (user_id);

-- العميل يقرا بتوعه بس؛ الكتابة للعقل (service_role) عبر الدالة تحت — نفس تقسيم
-- zad_memory_links. مسح ملاحظة من التطبيق بيمسح إشاراتها (cascade).
alter table public.zad_memory_entities enable row level security;
alter table public.zad_memory_mentions enable row level security;
-- Supabase بيدّي anon وauthenticated كل الصلاحيات على أي جدول جديد (default privileges)؛
-- نشيلها كلها ونرجّع القراية بس.
revoke all on public.zad_memory_entities from anon, authenticated;
revoke all on public.zad_memory_mentions from anon, authenticated;
grant select on public.zad_memory_entities to authenticated;
grant select on public.zad_memory_mentions to authenticated;

drop policy if exists "zad_memory_entities_select_own" on public.zad_memory_entities;
create policy "zad_memory_entities_select_own"
  on public.zad_memory_entities for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "zad_memory_mentions_select_own" on public.zad_memory_mentions;
create policy "zad_memory_mentions_select_own"
  on public.zad_memory_mentions for select to authenticated
  using ((select auth.uid()) = user_id);

comment on table public.zad_memory_entities is
  'الأشخاص والأماكن والأصناف والجهات اللي ملاحظات zad_memory بتشاور عليها. بيكتبها zad-brain بس عبر zad_memory_attach_entities().';
comment on table public.zad_memory_mentions is
  'ملاحظة ← كيان (٣ بالكتير لكل ملاحظة). زي [[رابط]] في أوبسيديان.';

/**
 * يربط ملاحظة بكياناتها. p_entities = [{"kind":"person","name":"ماما","key":"ماما"}, ...]
 * (متوحّدة في zad-brain). بيتأكد إن الملاحظة بتاعة p_user قبل أي كتابة — العقل شغال
 * بـservice_role وبيتخطى RLS، فـid مهلوس مايقدرش يربط ذاكرة عميل بكيانات عميل تاني.
 * أي عنصر ناقص أو نوعه مش معروف بيتجاهل. بيرجّع عدد الكيانات اللي اتربطت.
 */
create or replace function public.zad_memory_attach_entities(p_user uuid, p_note uuid, p_entities jsonb)
returns integer
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_item jsonb;
  v_kind text;
  v_name text;
  v_key text;
  v_entity uuid;
  v_count integer := 0;
begin
  if not exists (select 1 from public.zad_memory where id = p_note and user_id = p_user) then
    return 0;
  end if;
  if p_entities is null or jsonb_typeof(p_entities) <> 'array' then
    return 0;
  end if;

  for v_item in select value from jsonb_array_elements(p_entities) limit 3 loop
    v_kind := v_item ->> 'kind';
    v_name := left(btrim(coalesce(v_item ->> 'name', '')), 60);
    v_key := left(btrim(coalesce(v_item ->> 'key', '')), 60);
    continue when v_kind is null or v_kind not in ('person', 'place', 'item', 'org');
    continue when v_name = '' or v_key = '';

    insert into public.zad_memory_entities (user_id, kind, name, name_key)
    values (p_user, v_kind, v_name, v_key)
    on conflict (user_id, kind, name_key) do update set last_seen = now()
    returning id into v_entity;

    insert into public.zad_memory_mentions (memory_id, entity_id, user_id)
    values (p_note, v_entity, p_user)
    on conflict do nothing;
    v_count := v_count + 1;
  end loop;
  return v_count;
end
$function$;

revoke all on function public.zad_memory_attach_entities(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.zad_memory_attach_entities(uuid, uuid, jsonb) to service_role;

-- ── القراءة: الملاحظات الحية بكياناتها ────────────────────────────────────────

/**
 * سناب شوت العقل: أقوى p_limit ملاحظة **حية**، كل واحدة بأسماء كياناتها وتاريخ انتهائها
 * (لو مؤقتة) — عشان الموديل يشوف «ماما» و«لحد الجمعة» جنب الجملة.
 */
create or replace function public.zad_memory_live_notes(p_user uuid, p_limit integer default 20)
returns table (
  id uuid, scope text, note text, confidence real, evidence_count integer,
  last_seen timestamptz, valid_until timestamptz, about text[]
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
         ), '{}'::text[]) as about
    from public.zad_memory m
   where m.user_id = p_user
     and (auth.uid() is null or auth.uid() = p_user)
     and m.superseded_by is null
     and (m.valid_until is null or m.valid_until > now())
   order by m.confidence desc, m.last_seen desc
   limit greatest(1, least(coalesce(p_limit, 20), 60));
$function$;

revoke all on function public.zad_memory_live_notes(uuid, integer) from public, anon;
grant execute on function public.zad_memory_live_notes(uuid, integer) to authenticated, service_role;

/**
 * «ماما عاملة إيه؟» — كل الملاحظات الحية عن أي كيان اسمه موجود في الرسالة. p_text = نص
 * الرسالة بعد itemKey في zad-brain (وممكن نسخة تانية من غير حروف الجر في أول الكلمة، مفصولة
 * بـ « | »). المطابقة على كلمة كاملة أو عبارة كاملة، مش جزء من كلمة («ماما» مش جوه «ماماتهم»).
 */
create or replace function public.zad_memory_recall_entities(p_user uuid, p_text text, p_limit integer default 8)
returns table (
  id uuid, scope text, note text, confidence real, evidence_count integer,
  last_seen timestamptz, valid_until timestamptz, about text[]
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
         ), '{}'::text[]) as about
    from public.zad_memory m
   where m.user_id = p_user
     and m.superseded_by is null
     and (m.valid_until is null or m.valid_until > now())
     and exists (select 1 from public.zad_memory_mentions mm where mm.memory_id = m.id and mm.entity_id in (select id from hit))
   order by m.confidence desc, m.last_seen desc
   limit greatest(1, least(coalesce(p_limit, 8), 20));
$function$;

revoke all on function public.zad_memory_recall_entities(uuid, text, integer) from public, anon, authenticated;
grant execute on function public.zad_memory_recall_entities(uuid, text, integer) to service_role;

-- ── الكتابة: الدمج على الحية بس، والزمن ───────────────────────────────────────

-- توقيع جديد (p_valid_until) ⇒ القديم لازم يتشال، وإلا يبقى فيه نسختين والنداء بالأسماء
-- يبقى ملتبس — نفس اللي 20260901190000_drop_stale_memory_upsert_overload صلّحه قبل كده.
drop function if exists public.zad_memory_upsert(uuid, text, text, real, uuid);

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
  select id, note, similarity(note, p_note)
    into v_id, v_note, v_sim
    from public.zad_memory
   where user_id = p_user and scope = p_scope
     and superseded_by is null
     and (valid_until is null or valid_until > now())
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

-- anon بالاسم، مش public بس: Supabase بيدّي anon EXECUTE على أي دالة جديدة في public
-- (default privileges، اتقرت من المشروع الحي 2026-10-03)، والدالة دي بتعدّي auth.uid() الفاضي —
-- يعني من غير السطر ده أي حد بالمفتاح العام يكتب في ذاكرة أي عميل (نفس ثغرة 20260902005638).
revoke execute on function public.zad_memory_upsert(uuid, text, text, real, uuid, timestamptz) from public, anon;
grant execute on function public.zad_memory_upsert(uuid, text, text, real, uuid, timestamptz) to authenticated, service_role;

create or replace function public.zad_memory_conflict(p_user uuid, p_scope text, p_note text)
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $$
  select case
    when auth.uid() is not null and auth.uid() <> p_user then null::jsonb
    else (
      select jsonb_build_object(
        'id', m.id, 'note', m.note, 'confidence', m.confidence,
        'evidence_count', m.evidence_count, 'similarity', round(similarity(m.note, p_note)::numeric, 3)
      )
      from public.zad_memory m
      where m.user_id = p_user
        and m.scope = p_scope
        and m.superseded_by is null
        and (m.valid_until is null or m.valid_until > now())
        and similarity(m.note, p_note) >= 0.6
        and public.zad_text_has_negation(m.note) <> public.zad_text_has_negation(p_note)
      order by similarity(m.note, p_note) desc
      limit 1
    )
  end;
$$;

/**
 * العميل حسم التعارض. الجديدة بتتكتب، والقديمة **بتتقفل** (valid_until = دلوقتي،
 * superseded_by = الجديدة) بدل ما تفضل حية بثقة أقل — كانت بتظهر في «زاد عارف عني إيه»
 * جنب الجديدة كحقيقتين متناقضتين. رابط contradicts بيفضل، والجديدة بتورث كيانات القديمة
 * (نفس الموضوع: «ماما بتحب الشاي» ← «ماما بقت بتحب القهوة»).
 */
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
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'not_authorized';
  end if;

  -- Ownership check before anything: the brain runs as service_role and bypasses RLS, so
  -- a hallucinated id must not be able to touch another account's memory.
  if not exists (select 1 from public.zad_memory where id = p_old_id and user_id = p_user) then
    return jsonb_build_object('ok', false, 'reason', 'unknown_note');
  end if;

  insert into public.zad_memory(user_id, scope, note, confidence)
  values (p_user, p_scope, p_note, coalesce(p_conf, 0.6))
  returning id into v_new_id;

  update public.zad_memory
     set confidence = greatest(0.1, confidence - 0.3),
         last_seen = now(),
         superseded_by = v_new_id,
         -- >= valid_from: ملاحظة اتحلّ محلها في نفس اللحظة اللي اتكتبت فيها بتبقى فترة طولها صفر.
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

create or replace function public.zad_memory_semantic_search(
  p_user uuid,
  p_query_embedding vector,
  p_limit integer default 12
)
returns table (id uuid, note text, scope text, confidence real, evidence_count integer, similarity real)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select m.id, m.note, m.scope, m.confidence, m.evidence_count,
         1 - (m.embedding <=> p_query_embedding) as similarity
    from public.zad_memory m
    where m.user_id = p_user and m.embedding is not null
      and m.superseded_by is null
      and (m.valid_until is null or m.valid_until > now())
    order by m.embedding <=> p_query_embedding
    limit p_limit;
$function$;

create or replace function public.zad_memory_find_contradictions(p_user uuid)
returns table (from_id uuid, to_id uuid, from_note text, to_note text)
language sql
stable
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
  select a.id, b.id, a.note, b.note
    from public.zad_memory a
    join public.zad_memory b
      on a.user_id = b.user_id
     and a.scope = b.scope
     and a.id < b.id
   where a.user_id = p_user
     and a.superseded_by is null and (a.valid_until is null or a.valid_until > now())
     and b.superseded_by is null and (b.valid_until is null or b.valid_until > now())
     and similarity(a.note, b.note) >= 0.5
     and public.zad_text_has_negation(a.note) <> public.zad_text_has_negation(b.note)
     and not exists (
       select 1 from public.zad_memory_links l
        where l.user_id = p_user and l.relation = 'contradicts'
          and ((l.from_id = a.id and l.to_id = b.id) or (l.from_id = b.id and l.to_id = a.id))
     );
$function$;

/**
 * السقف ٦٠ ملاحظة لكل عميل زي ما هو، بس المنتهية والمتحلّ محلها بتتشال الأول — التاريخ
 * أرخص من الحاضر. والكيانات اللي مابقاش ليها ولا ملاحظة من شهر بتتشال (الكيان من غير
 * ملاحظات اسم فاضي).
 */
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
    ) ranked
    where rn > 60
  );

  delete from public.zad_memory_entities e
   where e.last_seen < now() - interval '30 days'
     and not exists (select 1 from public.zad_memory_mentions mm where mm.entity_id = e.id);
end $function$;
