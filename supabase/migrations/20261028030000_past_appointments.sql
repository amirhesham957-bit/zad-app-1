-- الميعاد اللي فات (ZAD_PLAN ٨ج.٤).
--
-- اتقاس على الحي ٢٨/١٠ ٠٢:٤٠ UTC: الـ٦ اللي «لسه جاي» ووقتهم عدّى كلهم مرة واحدة (منبهات صحيان من
-- تليجرام ٣٠/٩–١٣/١٠). مفيش حاجة كانت بتقفل المرة الواحدة — تنضيف 20260919000000 اتعمل مرة واحدة بس.
-- والمتكرر كان بيتحرّك فعلاً (الـ٤ اليومي اتحرّكوا امبارح)، بس بخطوة UTC: `+ interval '1 day'` على
-- timestamptz وجلسة الكرون UTC، فـ«اشرب مياه» ٨:٢٠ القاهرة (05:20Z) كانت هتبقى ٧:٢٠ من ٣٠/١٠ لما
-- مصر ترجع للتوقيت الشتوي — اتقاس بـtzdata الداتابيز نفسه.
--
-- ١. المتكرر بيتحرّك بساعة الحيطة في بلد الحساب (zad_market_timezone): ٨:٢٠ تفضل ٨:٢٠ قبل وبعد تغيير
--    الساعة. «كل ساعة» بيفضل ساعات مطلقة. المعادلة القديمة كانت بتقرّب الشهر لـ٣٠ يوم، والجديدة بتصحّح.
-- ٢. المرة الواحدة بتتقفل `done` بعد ساعتين من ميعادها — نفس نافذة الـsnapshot (starts_at ≥ now − 2h)،
--    فالعقل بيفضل شايف «الميعاد اللي لسه فات» لحد ما يخرج من نافذته. التطبيق بيعرضه في «اللي فات»
--    في الحالتين. الـ٦ بيتقفلوا في أول لفة كرون بعد النشر.

/** المرة رقم [p_n] بعد [p_starts]. */
create or replace function public.zad_appointment_occurrence(
  p_starts timestamptz, p_recurrence text, p_tz text, p_n int
) returns timestamptz
language sql stable set search_path to 'public' as $$
  select case p_recurrence
    when 'hourly' then p_starts + interval '1 hour' * p_n
    when 'daily' then ((p_starts at time zone p_tz) + interval '1 day' * p_n) at time zone p_tz
    when 'weekly' then ((p_starts at time zone p_tz) + interval '7 days' * p_n) at time zone p_tz
    when 'monthly' then ((p_starts at time zone p_tz) + interval '1 month' * p_n) at time zone p_tz
  end;
$$;

/**
 * أول مرة للميعاد بعد [p_after]. اليومي والأسبوعي والشهري بساعة الحيطة في [p_tz]؛ «كل ساعة» ساعات مطلقة.
 * ميعاد لسه جاي (أو تكرار مش معروف) بيرجع زي ما هو.
 */
create or replace function public.zad_next_appointment_start(
  p_starts timestamptz, p_recurrence text, p_tz text, p_after timestamptz
) returns timestamptz
language plpgsql stable set search_path to 'public' as $$
declare
  v_n int;
begin
  if p_starts > p_after or p_recurrence not in ('hourly', 'daily', 'weekly', 'monthly') then
    return p_starts;
  end if;
  -- تقدير بالثواني، وبعدين تصحيح بخطوة: يوم تغيير الساعة ٢٣ أو ٢٥ ساعة، والشهر مش ٣٠ يوم.
  v_n := greatest(1, ceil(extract(epoch from (p_after - p_starts)) / extract(epoch from case p_recurrence
    when 'hourly' then interval '1 hour' when 'daily' then interval '1 day'
    when 'weekly' then interval '7 days' else interval '30 days' end))::int);
  while public.zad_appointment_occurrence(p_starts, p_recurrence, p_tz, v_n) <= p_after loop
    v_n := v_n + 1;
  end loop;
  while v_n > 1 and public.zad_appointment_occurrence(p_starts, p_recurrence, p_tz, v_n - 1) > p_after loop
    v_n := v_n - 1;
  end loop;
  return public.zad_appointment_occurrence(p_starts, p_recurrence, p_tz, v_n);
end;
$$;

revoke all on function public.zad_appointment_occurrence(timestamptz, text, text, int) from public, anon, authenticated;
revoke all on function public.zad_next_appointment_start(timestamptz, text, text, timestamptz) from public, anon, authenticated;

create or replace function public.zad_enqueue_appointment_moments()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int;
begin
  -- الميعاد المتكرر اللي عدّى عليه أكتر من ١٠ دقايق يتنقل لأول مرة جاية، بساعة بلد الحساب (٨ج.٤).
  update public.zad_appointments a
  set starts_at = public.zad_next_appointment_start(
        a.starts_at, a.recurrence,
        public.zad_market_timezone((select u.country from public.zad_users u where u.id = a.user_id)),
        now() - interval '10 minutes'),
      updated_at = now()
  where a.status = 'upcoming'
    and a.recurrence <> 'once'
    and a.starts_at < now() - interval '10 minutes';

  -- المرة الواحدة اللي عدّى عليها ساعتين بتتقفل (٨ج.٤) — كانت بتفضل «جاي» للأبد.
  update public.zad_appointments a
  set status = 'done', updated_at = now()
  where a.status = 'upcoming'
    and a.recurrence = 'once'
    and a.starts_at < now() - interval '2 hours';

  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select a.user_id, 'appointment_soon',
         jsonb_build_object(
           'appointment_id', a.id,
           'title', a.title,
           'kind', a.kind,
           'starts_at', a.starts_at,
           'place_label', a.place_label,
           'recurrence', a.recurrence,
           'minutes_left', greatest(0, floor(extract(epoch from (a.starts_at - now())) / 60))::int,
           'time_zone', public.zad_market_timezone(u.country)
         ),
         'appt_soon:' || a.id || ':' || floor(extract(epoch from a.starts_at))::bigint
  from public.zad_appointments a
  join auth.users au on au.id = a.user_id
  left join public.zad_users u on u.id = a.user_id
  where a.status = 'upcoming'
    and now() >= case
          -- مفيش وقت كفاية للتذكير المسبق من ساعة ما اتسجل ⇒ في الميعاد نفسه، مش فوراً.
          when a.starts_at - make_interval(mins => a.remind_minutes_before) < a.updated_at then a.starts_at
          else a.starts_at - make_interval(mins => a.remind_minutes_before)
        end
    and now() < a.starts_at + interval '10 minutes'
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_appointment_moments() from public;
revoke all on function public.zad_enqueue_appointment_moments() from anon;
revoke all on function public.zad_enqueue_appointment_moments() from authenticated;
