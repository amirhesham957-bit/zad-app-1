-- «مخدتهاش» إجابة، ومتابعة الدوا بتقرا الجدول الصح (٢٠٢٦-٠٩-٢٥).
--
-- بلاغ من العميل: «لما بدوس مخدتش الدوا مش بيقراها… حاسس إن فيه مسارين مش مسار واحد».
-- الاتنين طلعوا حقيقيين:
--
-- ١) مفيش طريقة تقول «مخدتهاش». البوت دلوقتي بيكتب صف status = 'skipped' في
--    zad_pharmacy_doses لنفس الخانة الزمنية (زرار «❌ مخدتهاش» أو رد مكتوب). بس الدالة
--    اللي بتولّد «فاتتك الجرعة» كانت بتعتبر 'taken' بس إجابة — فالعميل اللي قال
--    «مخدتهاش» كان هيفضل يتعاتب عليها ساعتين. هنا 'skipped' بقت إجابة زي 'taken'.
--    ('missed' مش إجابة: ده حكم النظام، مش كلام العميل.)
--
-- ٢) مسارين للجرعات: كل الكتابة الحالية (زرار تليجرام، zad_log_pharmacy_dose_atomic،
--    التطبيق الجديد) بتروح zad_pharmacy_doses، لكن _agent_med_followup_for_user كانت
--    بتقرا zad_dose_log بس — الجدول القديم. يعني أي حد بيسجّل من الزرار كان هيجيله كل يوم
--    «مبيظهرش إنك سجلت أي خدّ» وهو مسجّل. دلوقتي بتقرا الاتنين، وبتتجاهل الأدوية اللي
--    رصيدها خلص (نفس شرط مولّد التذكيرات: مفيش تذكير لدوا مش موجود).
--
-- الدالتين هنا نسخة من المنشور على الـlive (pg_get_functiondef، ٢٠٢٦-٠٩-٢٥) بالتعديلات
-- دي بس — مش من آخر ملف في الريبو، عشان مانرجّعش أي فرق.

create or replace function public.zad_enqueue_missed_doses()
 returns integer
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_inserted int := 0;
  v_count int;
begin
  create temporary table if not exists pg_temp.zad_due_doses (
    user_id uuid, item_id uuid, item_name text, scheduled_at timestamptz, tz text
  ) on commit drop;
  truncate pg_temp.zad_due_doses;

  insert into pg_temp.zad_due_doses
  select p.user_id, p.id, p.name, s.scheduled_at, s.tz
  from public.zad_pharmacy_items p
  join public.zad_users u on u.id = p.user_id
  cross join lateral (select public.zad_market_timezone(u.country) as tz) z
  cross join lateral unnest(string_to_array(p.dose_times, ',')) as t(raw)
  cross join lateral (values (0), (1)) as d(days_back)
  cross join lateral (
    select z.tz,
           (((now() at time zone z.tz)::date - d.days_back) + btrim(t.raw)::time) at time zone z.tz as scheduled_at
  ) s
  where coalesce(p.dose_times, '') <> ''
    and coalesce(p.has_invalid_dose_time, false) = false
    and (p.remaining_quantity is null or p.remaining_quantity > 0)
    and btrim(t.raw) ~ '^([01]?[0-9]|2[0-3]):[0-5][0-9]$'
    and s.scheduled_at between now() - interval '3 hours' and now()
    and s.scheduled_at > p.created_at
    -- إجابة العميل على الجرعة: أخدها ('taken') أو قال مخدهاش ('skipped', ٢٠٢٦-٠٩-٢٥).
    and not exists (
      select 1 from public.zad_pharmacy_doses pd
      where pd.user_id = p.user_id and pd.item_id = p.id and pd.status in ('taken', 'skipped')
        and coalesce(pd.taken_at, pd.scheduled_at) >= s.scheduled_at - interval '3 hours'
    )
    and not exists (
      select 1 from public.zad_dose_log l
      where l.user_id = p.user_id and l.pharmacy_item_id = p.id
        and l.taken_at >= s.scheduled_at - interval '3 hours'
    )
    -- العميل داس «فكّرني بعدين» على الجرعة دي بالظبط — سكوت لحد ما الوقت يعدّي.
    and not exists (
      select 1 from public.zad_dose_snoozes sn
      where sn.user_id = p.user_id and sn.item_id = p.id
        and sn.scheduled_at = s.scheduled_at and sn.snooze_until > now()
    );

  -- dose_due (بصوتها، حنينة): أول ١٠ دقايق من الميعاد.
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select g.user_id, 'dose_due',
         jsonb_build_object('item_name', g.names, 'item_ids', g.ids, 'scheduled_at', g.scheduled_at, 'time_zone', g.tz),
         'dose_due:' || g.user_id || ':' || floor(extract(epoch from g.scheduled_at))::bigint
  from (
    select user_id, scheduled_at, tz, string_agg(item_name, ' و' order by item_name) as names, jsonb_agg(item_id) as ids
    from pg_temp.zad_due_doses
    where scheduled_at between now() - interval '10 minutes' and now()
    group by user_id, scheduled_at, tz
  ) g
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;
  v_inserted := v_inserted + v_count;

  -- تأجيل خلص ولسه الجرعة ماتاخدتش ⇒ تذكير واحد جديد. dedupe_key فيه وقت التأجيل
  -- نفسه، فكل ضغطة «أجّل» بتنتج تذكير واحد بالظبط مهما الكرون لفّ.
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select sn.user_id, 'dose_due',
         jsonb_build_object(
           'item_name', p.name, 'item_ids', jsonb_build_array(sn.item_id),
           'scheduled_at', sn.scheduled_at, 'time_zone', public.zad_market_timezone(u.country),
           'snoozed', true
         ),
         'dose_snooze:' || sn.user_id || ':' || sn.item_id || ':' || floor(extract(epoch from sn.snooze_until))::bigint
  from public.zad_dose_snoozes sn
  join public.zad_pharmacy_items p on p.id = sn.item_id and p.user_id = sn.user_id
  left join public.zad_users u on u.id = sn.user_id
  where sn.snooze_until between now() - interval '10 minutes' and now()
    and not exists (
      select 1 from public.zad_pharmacy_doses pd
      where pd.user_id = sn.user_id and pd.item_id = sn.item_id and pd.status in ('taken', 'skipped')
        and coalesce(pd.taken_at, pd.scheduled_at) >= sn.scheduled_at - interval '3 hours'
    )
    and not exists (
      select 1 from public.zad_dose_log l
      where l.user_id = sn.user_id and l.pharmacy_item_id = sn.item_id
        and l.taken_at >= sn.scheduled_at - interval '3 hours'
    )
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;
  v_inserted := v_inserted + v_count;

  -- dose_nudge (مكتوب بس): ٣٠–٦٠ دقيقة بعد الميعاد.
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select g.user_id, 'dose_nudge',
         jsonb_build_object('item_name', g.names, 'item_ids', g.ids, 'scheduled_at', g.scheduled_at, 'time_zone', g.tz),
         'dose_nudge:' || g.user_id || ':' || floor(extract(epoch from g.scheduled_at))::bigint
  from (
    select user_id, scheduled_at, tz, string_agg(item_name, ' و' order by item_name) as names, jsonb_agg(item_id) as ids
    from pg_temp.zad_due_doses
    where scheduled_at between now() - interval '60 minutes' and now() - interval '30 minutes'
    group by user_id, scheduled_at, tz
  ) g
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;
  v_inserted := v_inserted + v_count;

  -- dose_missed / dose_missed_again (بصوتها): ساعة لـ٣ ساعات، بحد ٣ في اليوم المحلي.
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select g.user_id,
         case when g.missed_today > 0 then 'dose_missed_again' else 'dose_missed' end,
         jsonb_build_object('item_name', g.names, 'item_ids', g.ids, 'scheduled_at', g.scheduled_at, 'time_zone', g.tz),
         'dose_missed:' || g.user_id || ':' || floor(extract(epoch from g.scheduled_at))::bigint
  from (
    select x.user_id, x.scheduled_at, x.tz, string_agg(x.item_name, ' و' order by x.item_name) as names, jsonb_agg(x.item_id) as ids,
           (select count(*) from public.zad_voice_moments m
             where m.user_id = x.user_id and m.moment in ('dose_missed', 'dose_missed_again')
               and m.created_at >= (date_trunc('day', now() at time zone x.tz) at time zone x.tz)) as missed_today
    from pg_temp.zad_due_doses x
    where x.scheduled_at between now() - interval '3 hours' and now() - interval '60 minutes'
    group by x.user_id, x.scheduled_at, x.tz
  ) g
  where g.missed_today < 3
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;
  v_inserted := v_inserted + v_count;

  return v_inserted;
end;
$function$;

create or replace function public._agent_med_followup_for_user(p_user uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  -- نفس فكرة spending_ahead بالظبط، بس للدوا. بنقرا الجرعات المتجددة (is_recurring)
  -- اللي آخر إجابة عليها — في zad_pharmacy_doses (المسار الحالي) **أو** zad_dose_log
  -- (القديم) — أقدم من يوم. لو لقينا، نزرع task kind=med_followup بنفس قفل عدم التكرار
  -- اليومي، ونفس خط المعالج يوصّلها.
  if exists (
    select 1
    from public.zad_pharmacy_items p
    left join lateral (
      select max(x.at) as last_answer
      from (
        select d.taken_at as at
        from public.zad_dose_log d
        where d.pharmacy_item_id = p.id
          and d.taken_at is not null
        union all
        select coalesce(pd.taken_at, pd.scheduled_at)
        from public.zad_pharmacy_doses pd
        where pd.item_id = p.id and pd.user_id = p_user
          and pd.status in ('taken', 'skipped')
      ) x
    ) d on true
    where p.user_id = p_user
      and coalesce(p.is_recurring, false) is true
      and (p.remaining_quantity is null or p.remaining_quantity > 0)
      and (d.last_answer is null or d.last_answer < now() - interval '1 day')
      and not exists (
        select 1
        from public.agent_tasks t
        where t.user_id = p_user
          and t.kind = 'med_followup'
          and date_trunc('day', t.created_at) = date_trunc('day', now() at time zone 'utc')
      )
  ) then
    insert into public.agent_tasks (user_id, kind, task_description, scheduled_for)
    values (
      p_user,
      'med_followup',
      $t$[متابعة دوا] عندك دوا متجدد شغال مع جدولة، ومبيظهرش إنك سجلت أي خدّ
في آخر يوم. فكّر في مراجعة الجدولة لو الجرعة اتأجلت$t$,
      now()
    )
    on conflict (user_id, kind, ((created_at at time zone 'UTC')::date))
      where kind in ('spending_ahead','med_followup','bill_reminder')
    do nothing;
  end if;
exception
  when unique_violation then
    return;
  when others then
    raise;
end;
$function$;

-- create or replace بيحافظ على الصلاحيات، بس نثبّتها صراحة زي 20260813190358: الدالة
-- داخلية ومش لأي حد غير الـservice role.
revoke execute on function public._agent_med_followup_for_user(uuid) from public, anon, authenticated;
grant execute on function public._agent_med_followup_for_user(uuid) to service_role;
