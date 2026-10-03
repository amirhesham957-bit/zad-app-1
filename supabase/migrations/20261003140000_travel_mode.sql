-- =====================================================
-- وضع السفر (docs/agent/ZAD_LIVING_BRAIN.md، الشريحة ٦ — قرار المالك 2026-10-03).
--
-- «سفرت مثلاً يرشحلي أماكن، يعرف السوبرماركت اللي فيها المنتجات الشبيهة اللي بحبها».
--
-- الموبايل كان عارف إنه برّه بلده من قبل كده (MainActivity، قناة zad/travel: بلد شبكة الموبايل —
-- صح وانت roaming — وإلا لغة الجهاز)، بس كان بيستخدمها لعرض واحد: «أحوّل العملة؟». العقل ماكانش
-- يعرف إنك مسافر خالص. الملف ده بيخلّي السيرفر يعرف:
--   - zad_users.travel_country/travel_since: البلد اللي الموبايل فيه لو مختلف عن سوق الحساب
--     (zad_users.country). **السوق نفسه مابيتغيرش** — الميزانية والعملة زي ما هم؛ ده سياق بس.
--   - zad_travel_report: الموبايل بيبلّغ بلد الشبكة وقت الفتح. نفس بلد السوق ⇒ رجع (السفر بيتمسح).
--     بلد جديد ⇒ بداية رحلة + لحظة travel_arrived مرة واحدة («شكلك في الإمارات! أرشحلك…؟»).
-- مستوى البلد بس — مفيش موقع ولا إحداثيات.
-- =====================================================

alter table public.zad_users
  add column if not exists travel_country text,
  add column if not exists travel_since timestamptz;

alter table public.zad_users drop constraint if exists zad_users_travel_country_iso;
alter table public.zad_users
  add constraint zad_users_travel_country_iso check (travel_country is null or travel_country ~ '^[A-Z]{2}$');

comment on column public.zad_users.travel_country is
  'بلد الموبايل (ISO alpha-2) لو مختلف عن country — العميل مسافر. null = في بلده. بيتكتب من zad_travel_report بس.';
comment on column public.zad_users.travel_since is
  'من إمتى في travel_country.';

create or replace function public.zad_travel_report(p_country text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_home text;
  v_prev text;
  v_new text := upper(btrim(coalesce(p_country, '')));
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  select upper(nullif(btrim(country), '')), travel_country into v_home, v_prev
    from public.zad_users where id = v_me;
  if v_home is null then
    -- من غير سوق مختار مانعرفش «برّه» يعني إيه.
    return jsonb_build_object('ok', false, 'reason', 'no_home_market');
  end if;

  if v_new !~ '^[A-Z]{2}$' or v_new = v_home then
    update public.zad_users set travel_country = null, travel_since = null
     where id = v_me and travel_country is not null;
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
