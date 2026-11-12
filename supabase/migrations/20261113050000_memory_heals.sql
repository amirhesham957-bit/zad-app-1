-- ZAD_PLAN ١٠.٢(ب): الذاكرة بتصلّح نفسها.
--
-- اتقاس ١٣/١١ على الحي: ٣١ ملاحظة حية عند ٧ عملا، وصفر ملاحظة اتحلّ محلها في تاريخ الجدول، وصفر رابط contradicts —
-- مع إن الليل بيدوّر على التناقض كل يوم (zad_memory_find_contradictions: نفي مقلوب بتشابه ≥ ٠٫٥ بس). وفيه ٥ أزواج
-- في نفس النطاق بتشابه ٠٫٣٥–٠٫٦ (تحت حد الدمج): اتنين منهم نفس الحقيقة بكلام تاني (القسط، والكلام مع الوالدة)،
-- وواحد رفضين لنفس التنبيه، واتنين حقايق مختلفة فعلاً (عيد ميلاد العميل وابنه). يعني التشابه لوحده مايفرّقش،
-- والحقيقة بتتكرر بدل ما تتصلح.
--
-- الحل: مرة في الأسبوع لكل عميل، بالليل، الأزواج المرشحة (SQL، ببلاش) بتتعرض على موديل خفيف يحكم: same / update /
-- contradiction / distinct. والحكم بيتطبق هنا بس: same ⇒ القديمة بتتدمج في الجديدة (الأدلة بتتجمع)، update ⇒ القديمة
-- بتبقى تاريخ (superseded_by + رابط contradicts)، contradiction ⇒ رابط بس (العميل هو اللي يحسم بالنهار)، distinct ⇒
-- بيتسجل عشان مايتسألش تاني. **مفيش مسح**: الملاحظة اللي اتحلّ محلها بتفضل في الجدول تاريخ، زي zad_memory_resolve_conflict.

create table if not exists public.zad_memory_reviews (
  user_id uuid not null references auth.users (id) on delete cascade,
  older_id uuid not null,
  newer_id uuid not null,
  verdict text not null check (verdict in ('same', 'update', 'contradiction', 'distinct')),
  reviewed_at timestamptz not null default now(),
  primary key (user_id, older_id, newer_id)
);
create index if not exists zad_memory_reviews_at on public.zad_memory_reviews (user_id, reviewed_at desc);

-- العميل مابيقراش ولا بيكتب هنا: العقل بس (service role) من خلال الدوال تحت.
alter table public.zad_memory_reviews enable row level security;
revoke all on table public.zad_memory_reviews from anon, authenticated;

/**
 * الأزواج اللي تستاهل مراجعة: نفس العميل ونفس النطاق، الاتنين حيين، تشابه نص ≥ ٠٫٣٥ أو تشابه معنى ≥ ٠٫٨٥،
 * ومااتراجعوش قبل كده. فاضي لو اتعملت مراجعة للعميل ده في آخر p_min_days — مرة في الأسبوع بالكتير.
 * النطاقات اللي نسخة واحدة (بتتكتب delete-then-insert) مالهاش أزواج أصلاً.
 */
create or replace function public.zad_memory_review_candidates(p_user uuid, p_limit integer default 8, p_min_days integer default 7)
returns table (older_id uuid, newer_id uuid, scope text, older_note text, newer_note text, similarity real)
language sql
stable
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
  with live as (
    select m.id, m.scope, m.note, m.created_at, m.embedding
      from public.zad_memory m
     where m.user_id = p_user
       and m.superseded_by is null
       and (m.valid_until is null or m.valid_until > now())
  )
  select a.id, b.id, a.scope, a.note, b.note,
         greatest(similarity(a.note, b.note),
                  case when a.embedding is not null and b.embedding is not null
                       then (1 - (a.embedding <=> b.embedding))::real else 0 end)::real
    from live a
    join live b
      on a.scope = b.scope
     and a.id <> b.id
     and (a.created_at, a.id) < (b.created_at, b.id)
   where not exists (
           select 1 from public.zad_memory_reviews r
            where r.user_id = p_user and r.reviewed_at > now() - make_interval(days => greatest(p_min_days, 0)))
     and not exists (
           select 1 from public.zad_memory_reviews r
            where r.user_id = p_user and r.older_id = a.id and r.newer_id = b.id)
     and (similarity(a.note, b.note) >= 0.35
          or (a.embedding is not null and b.embedding is not null and 1 - (a.embedding <=> b.embedding) >= 0.85))
   order by 6 desc
   limit greatest(least(p_limit, 20), 0);
$function$;

/**
 * يطبّق حكم واحد على زوج. الاتنين لازم يكونوا بتوع p_user وحيين — العقل شغال بـservice role، فـid مهلوس من الموديل
 * مايقدرش يلمس ذاكرة حد تاني. الحكم بيتسجل في كل الحالات (حتى لو الزوج اتقفل من حاجة تانية في النص).
 */
create or replace function public.zad_memory_heal(p_user uuid, p_older uuid, p_newer uuid, p_verdict text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'extensions', 'pg_temp'
as $function$
declare
  v_old public.zad_memory%rowtype;
  v_new public.zad_memory%rowtype;
begin
  if p_verdict is null or p_verdict not in ('same', 'update', 'contradiction', 'distinct') then
    return jsonb_build_object('ok', false, 'reason', 'bad_verdict');
  end if;
  if p_older = p_newer then
    return jsonb_build_object('ok', false, 'reason', 'same_note');
  end if;
  select * into v_old from public.zad_memory where id = p_older and user_id = p_user and superseded_by is null;
  select * into v_new from public.zad_memory where id = p_newer and user_id = p_user and superseded_by is null;
  if v_old.id is null or v_new.id is null then
    return jsonb_build_object('ok', false, 'reason', 'unknown_note');
  end if;
  if v_old.scope <> v_new.scope then
    return jsonb_build_object('ok', false, 'reason', 'different_scope');
  end if;

  insert into public.zad_memory_reviews (user_id, older_id, newer_id, verdict)
  values (p_user, p_older, p_newer, p_verdict)
  on conflict (user_id, older_id, newer_id) do update set verdict = excluded.verdict, reviewed_at = now();

  if p_verdict in ('same', 'update') then
    if p_verdict = 'same' then
      -- نفس الحقيقة اتقالت مرتين: الجديدة بتاخد أدلة القديمة وثقتها لو أعلى.
      update public.zad_memory
         set evidence_count = coalesce(evidence_count, 1) + coalesce(v_old.evidence_count, 1),
             confidence = greatest(confidence, v_old.confidence),
             last_seen = now()
       where id = p_newer;
    end if;
    update public.zad_memory
       set superseded_by = p_newer,
           confidence = case when p_verdict = 'update' then greatest(0.1, confidence - 0.3) else confidence end,
           last_seen = now(),
           valid_until = greatest(valid_from, least(coalesce(valid_until, now()), now()))
     where id = p_older;
    insert into public.zad_memory_mentions (memory_id, entity_id, user_id)
    select p_newer, mm.entity_id, mm.user_id
      from public.zad_memory_mentions mm
     where mm.memory_id = p_older
    on conflict do nothing;
  end if;

  if p_verdict in ('update', 'contradiction') then
    insert into public.zad_memory_links (user_id, from_id, to_id, relation, strength, evidence_count)
    values (p_user, p_newer, p_older, 'contradicts', case when p_verdict = 'update' then 0.8 else 0.7 end, 1)
    on conflict do nothing;
  end if;

  return jsonb_build_object('ok', true, 'verdict', p_verdict);
end
$function$;

revoke all on function public.zad_memory_review_candidates(uuid, integer, integer) from public, anon, authenticated;
revoke all on function public.zad_memory_heal(uuid, uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.zad_memory_review_candidates(uuid, integer, integer) to service_role;
grant execute on function public.zad_memory_heal(uuid, uuid, uuid, text) to service_role;
