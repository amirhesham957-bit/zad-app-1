-- «الكارت ظهر للعميل» — أساس التعلّم من رد الفعل (٢٠٢٦-١٠-١١).
--
-- مقيس على الحي: ٤٢ من ٤٩ كارت آخر ٣٠ يوم لسه pending، و٠ من ٤٣ آخر ٢١ يوم اتعمل بيها أو اترفضت.
-- engagement.ts بيعتبر أي كارت pending عدّى عليه ٤٨ ساعة «اتجاهل»، وبعد ٣ في نفس الموضوع بيسكّت الموضوع.
-- بس محدش بيكتب إن الكارت ظهر أصلاً: status = 'seen' مكتوبة في القيد ومفيش كود بيكتبها، و٣ من ٦
-- حسابات مالهمش لا إشعارات ولا تليجرام — كروتهم بتظهر في الرئيسية بس، لو فتحوا التطبيق. فـ«اتجاهل»
-- كانت بتخلط «ماشافوش» بـ«شافه وسابه».
--
-- seen_at عمود لوحده، مش status = 'seen': التطبيق بيجيب pending بس (الكارت كان هيختفي بعد أول نظرة)،
-- وopenCards وبوت تليجرام والتريجر وماسح «مصاريف من غير تصنيف» كلهم بيقروا pending.
--
-- التطبيق بيبعت اللحظة اللي الكارت اتعرض فيها (ممكن يكون من غير نت ويتبعت بعدين، والساعة دي هي اللي
-- هتتعلم منها مواعيد الإشعارات بعدين). السيرفر بيقصّها بين وقت كتابة الكارت ودلوقتي — ساعة الموبايل
-- مش مصدر ثقة — وأول مرة بتكسب. updated_at مابيتلمسش: «مش مهم ليا» بتتحسب منه.

alter table public.zad_insights
  add column if not exists seen_at timestamptz;

comment on column public.zad_insights.seen_at is
  'أول مرة الكارت اتعرض في التطبيق (الرئيسية أو الإشعارات). null = محدش شافه في التطبيق.';

create or replace function public.zad_mark_insight_seen(p_id uuid, p_at timestamptz)
returns timestamptz
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_uid uuid := auth.uid();
  v_seen timestamptz;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  update public.zad_insights i
     set seen_at = least(now(), greatest(i.created_at, coalesce(p_at, now())))
   where i.id = p_id and i.user_id = v_uid and i.seen_at is null;

  -- القراية بعد الكتابة: null = الكارت اتمسح أو مش بتاعه.
  select i.seen_at into v_seen
    from public.zad_insights i
   where i.id = p_id and i.user_id = v_uid;
  return v_seen;
end;
$fn$;

comment on function public.zad_mark_insight_seen(uuid, timestamptz) is
  'يسجّل أول ظهور لكارت العميل نفسه، والوقت متقصوص بين كتابته ودلوقتي. بيرجّع seen_at، أو null لو الكارت مش موجود.';

revoke execute on function public.zad_mark_insight_seen(uuid, timestamptz) from public, anon;
grant execute on function public.zad_mark_insight_seen(uuid, timestamptz) to authenticated, service_role;
