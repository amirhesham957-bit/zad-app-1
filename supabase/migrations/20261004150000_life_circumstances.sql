-- =====================================================
-- حالة البيت (docs/agent/ZAD_LIVING_BRAIN.md الشرايح ٢٩–٣٠، طلب المالك 2026-10-04: «رادار الظروف الاستثنائية»،
-- «وعي فترة التعافي»، «مستشعر التحول السلوكي»).
--
-- ظرف = فترة ليها بداية ونهاية بتغيّر زاد بيتكلم قد إيه:
--   - exceptional: ظرف طارئ في البيت (حد عيان، طوارئ) — **العميل اللي بيقوله** (أداة set_life_circumstance)؛ زاد
--     مابيستنتجش مرض ولا مزاج (§٨). التذكيرات غير العاجلة بتتأجل، والجرعات والمواعيد والأمان زي ما هي.
--   - exams: فترة امتحانات — العميل بيقولها برضه. نفس الهدوء.
--   - travel: رحلة خلصت (zad_travel_report بيسجّلها لما الموبايل يرجع البلد) — بعدها فترة تعافي.
--   - shift_*: تحول في نمط المعيشة (الشريحة ٣٠) — مستشعر بالكود، بيتسأل عنه العميل مرة.
-- بعد أي ظرف يخلص (exceptional/exams/travel): ٤٨ ساعة «تعافي» — تنبيهات أقل.
--
-- العميل بيقرا ظروفه ويقدر ينهي أي واحد بدري (zad_circumstance_end) — «رجّع التنبيهات». الكتابة من السيرفر بس.
-- =====================================================

create table if not exists public.zad_life_circumstances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('exceptional', 'exams', 'travel', 'shift_spending', 'shift_income', 'shift_new_expense')),
  source text not null check (source in ('customer', 'travel', 'detected')),
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  -- العميل أنهاه بدري («رجّع التنبيهات»)، أو أكّد/نفى التحول.
  ended_at timestamptz,
  -- أرقام بس (التحول: المتوسط قبل وبعد، الفئة). مفيش نص حر عن الظرف نفسه — «عيان» مابيتخزنش.
  detail jsonb not null default '{}'::jsonb,
  -- التحول: null = لسه ماتسألش، true = العميل أكّد، false = نفى.
  confirmed boolean,
  created_at timestamptz not null default now(),
  check (ends_at >= started_at),
  check (ends_at <= started_at + interval '120 days')
);

create index if not exists zad_life_circumstances_recent
  on public.zad_life_circumstances (user_id, ends_at desc);

alter table public.zad_life_circumstances enable row level security;
revoke all on table public.zad_life_circumstances from anon, authenticated;
grant select on table public.zad_life_circumstances to authenticated;

drop policy if exists "life circumstances: owner reads" on public.zad_life_circumstances;
create policy "life circumstances: owner reads" on public.zad_life_circumstances
  for select using (auth.uid() = user_id);

-- «رجّع التنبيهات»: العميل بينهي ظرف هادي (exceptional/exams) دلوقتي. التعافي مابيبدأش بعده — هو اللي طلب الكلام يرجع.
create or replace function public.zad_circumstance_end(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_row public.zad_life_circumstances%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  select * into v_row from public.zad_life_circumstances where id = p_id and user_id = v_uid;
  if not found or v_row.kind not in ('exceptional', 'exams') then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_row.ended_at is not null or v_row.ends_at <= now() then
    return jsonb_build_object('ok', true, 'already', true);
  end if;
  update public.zad_life_circumstances
     set ended_at = now(), ends_at = greatest(started_at, now()),
         detail = detail || jsonb_build_object('ended_by_customer', true)
   where id = p_id;
  return jsonb_build_object('ok', true);
end
$function$;

revoke all on function public.zad_circumstance_end(uuid) from public, anon;
grant execute on function public.zad_circumstance_end(uuid) to authenticated;

-- نفس zad_travel_report (20261003140000) + لما الموبايل يرجع البلد بعد رحلة يومين أو أكتر، الرحلة بتتسجل ظرف خلص —
-- عشان ٤٨ ساعة تعافي بعدها.
create or replace function public.zad_travel_report(p_country text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_home text;
  v_prev text;
  v_since timestamptz;
  v_new text := upper(btrim(coalesce(p_country, '')));
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  select upper(nullif(btrim(country), '')), travel_country, travel_since into v_home, v_prev, v_since
    from public.zad_users where id = v_me;
  if v_home is null then
    -- من غير سوق مختار مانعرفش «برّه» يعني إيه.
    return jsonb_build_object('ok', false, 'reason', 'no_home_market');
  end if;

  if v_new !~ '^[A-Z]{2}$' or v_new = v_home then
    update public.zad_users set travel_country = null, travel_since = null
     where id = v_me and travel_country is not null;
    if v_prev is not null and v_since is not null and now() - v_since >= interval '2 days' then
      insert into public.zad_life_circumstances (user_id, kind, source, started_at, ends_at, ended_at, detail)
      values (v_me, 'travel', 'travel', v_since, now(), now(), jsonb_build_object('country', v_prev));
    end if;
    return jsonb_build_object('ok', true, 'status', 'home');
  end if;

  if v_prev = v_new then
    return jsonb_build_object('ok', true, 'status', 'away', 'country', v_new);
  end if;

  update public.zad_users set travel_country = v_new, travel_since = now() where id = v_me;
  -- مرة واحدة لكل بلد في اليوم، حتى لو الموبايل فتح وقفل عشر مرات.
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  values (
    v_me, 'travel_arrived',
    jsonb_build_object('country', v_new, 'home_country', v_home),
    'travel:' || v_new || ':' || to_char(now(), 'YYYY-MM-DD')
  )
  on conflict (user_id, dedupe_key) do nothing;
  return jsonb_build_object('ok', true, 'status', 'arrived', 'country', v_new);
end $$;

-- anon بالاسم: Supabase بيدّيه EXECUTE على أي دالة جديدة (ZAD_LIVING_BRAIN.md §٧).
revoke all on function public.zad_travel_report(text) from public, anon;
grant execute on function public.zad_travel_report(text) to authenticated;
