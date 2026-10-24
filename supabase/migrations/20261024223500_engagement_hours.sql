-- الوقت اللي العميل بيرد فيه (ZAD_PLAN ١.٦، طلب المالك ٢٤/١٠: «البوت يبقى إنتراكتف مش مواعيد ثابتة»).
--
-- ٢٤ رقم: كام مرة العميل ده عمل حاجة في كل ساعة محلية (توقيت سوقه) آخر ٣٠ يوم — كتب في الشات أو
-- تليجرام، رد على سؤال المخزون، فتح التطبيق، قفل يومه، أو اتصرّف في رسالة حارس. zad-brain
-- (responsiveHourDecision) بيأجّل المبادرات الاختيارية لأقرب ساعة منهم، ولو المجموع أقل من ١٢ بيسيب
-- الافتراضي. المقاس ٢٤/١٠: ١٧ رسالة شات، ٤٠ رد مخزون، ٥٩ حدث تطبيق، ٢ قفلة في ٣٠ يوم.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

create or replace function public.zad_engagement_hours(p_user uuid)
returns int[]
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_tz text;
  v_since timestamptz := now() - interval '30 days';
  v_hours int[];
begin
  select public.zad_market_timezone(u.country) into v_tz from public.zad_users u where u.id = p_user;
  if v_tz is null then
    return null;
  end if;
  with acts(at) as (
    select c.created_at from public.zad_chat_turns c
     where c.user_id = p_user and c.role = 'user' and c.created_at > v_since
    union all
    select p.answered_at from public.telegram_checkin_prompts p
     where p.user_id = p_user and p.answered_at > v_since
    union all
    select e.at from public.zad_product_events e
     where e.user_id = p_user and e.at > v_since
    union all
    select d.created_at from public.zad_day_closes d
     where d.user_id = p_user and d.created_at > v_since
    union all
    select g.delivered_at from public.zad_guardian_outcomes g
     where g.user_id = p_user and g.delivered_at > v_since and (g.acted_within_2h or g.replied_within_day)
  )
  select array_agg(coalesce(n, 0) order by h) into v_hours
    from generate_series(0, 23) h
    left join (select extract(hour from a.at at time zone v_tz)::int hr, count(*)::int n from acts a group by 1) c on c.hr = h;
  return v_hours;
end;
$function$;

revoke all on function public.zad_engagement_hours(uuid) from public, anon, authenticated;
grant execute on function public.zad_engagement_hours(uuid) to service_role;
