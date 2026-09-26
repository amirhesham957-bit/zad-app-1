-- تذكيرات الدوا المتقاربة في رسالة واحدة، ومتابعة واحدة بس (٢٠٢٦-٠٩-٢٦).
--
-- بلاغ المالك: «البوت بيكررها كتير». المقاس على الـlive (٢٠٢٦-٠٩-٢٣/٢٤): دوائين
-- بينهم نص ساعة (01:00 و01:30) كانوا بيمشوا كل واحد في سلسلة لوحده —
-- dose_due(A) ← dose_nudge(A)+dose_due(B) ← dose_missed(A)+dose_nudge(B) ← dose_missed_again(B)
-- يعني ٦ رسايل في كل ميعاد لو محدش رد، وكمان كل «أخدته» ماكانتش بتتقرا بالكلام.
--
-- القاعدة الجديدة (قرار المالك ٢٠٢٦-٠٩-٢٦):
--   • الخانات اللي بين كل واحدة واللي بعدها ٣٠ دقيقة أو أقل = مجموعة واحدة.
--     المجموعة بتتحسب من **المواعيد** مش من الإجابات، عشان «أخدت الأول» ماتخليش التاني
--     يبقى مجموعة لوحده ويطلع له تذكير تاني في ميعاده.
--   • رسالة واحدة (dose_due) أول ما أول خانة في المجموعة تيجي، فيها كل الأدوية اللي لسه
--     ماتجاوبش عليها بمواعيدها.
--   • متابعة واحدة بالكتير (dose_missed / dose_missed_again) بعد ساعة من آخر خانة في
--     المجموعة، للي لسه ماتجاوبش عليه بس. الحد اليومي (٣) زي ما هو.
--   • dose_nudge (مكتوب بعد نص ساعة) اتشال — كان تكرار تاني فوق الاتنين دول.
--
-- facts.slots بقت بتحمل خانة كل دوا (item_id + scheduled_at) عشان البوت يسجّل كل جرعة
-- في خانتها الصح (zad_pharmacy_doses فهرسه الفريد على user_id,item_id,scheduled_at).
-- facts.scheduled_at = أول خانة في المجموعة، وfacts.item_ids زي ما هي — البوت القديم
-- بيفضل شغال على رسالة فيها دوا واحد.
--
-- مفتاح التكرار dose_due:<user>:<epoch أول خانة> — لمجموعة فيها دوا واحد ده نفس المفتاح
-- القديم بالظبط، فالنشر في نص ميعاد مابيبعتش نفس التذكير مرتين.
--
-- الإجابة = 'taken' أو 'skipped' (20260925120000)، والتأجيل بيفضل لكل دوا لوحده.

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
  create temporary table if not exists pg_temp.zad_dose_slots (
    user_id uuid, item_id uuid, item_name text, scheduled_at timestamptz, tz text,
    open boolean, anchor timestamptz, last_at timestamptz
  ) on commit drop;
  truncate pg_temp.zad_dose_slots;

  -- كل الخانات من ٤ ساعات فاتت لحد نص ساعة جاية — المفتوحة والمتجاوب عليها، عشان
  -- المجموعات تتحسب من المواعيد. open = لسه محدش ردّ عليها ومش متأجلة.
  insert into pg_temp.zad_dose_slots (user_id, item_id, item_name, scheduled_at, tz, open, anchor, last_at)
  with slots as (
    select p.user_id, p.id as item_id, p.name as item_name, s.scheduled_at, s.tz,
           (
             not exists (
               select 1 from public.zad_pharmacy_doses pd
               where pd.user_id = p.user_id and pd.item_id = p.id and pd.status in ('taken', 'skipped')
                 and coalesce(pd.taken_at, pd.scheduled_at) >= s.scheduled_at - interval '3 hours'
             )
             and not exists (
               select 1 from public.zad_dose_log l
               where l.user_id = p.user_id and l.pharmacy_item_id = p.id
                 and l.taken_at >= s.scheduled_at - interval '3 hours'
             )
             and not exists (
               select 1 from public.zad_dose_snoozes sn
               where sn.user_id = p.user_id and sn.item_id = p.id
                 and sn.scheduled_at = s.scheduled_at and sn.snooze_until > now()
             )
           ) as open
    from public.zad_pharmacy_items p
    join public.zad_users u on u.id = p.user_id
    cross join lateral (select public.zad_market_timezone(u.country) as tz) z
    cross join lateral unnest(string_to_array(p.dose_times, ',')) as t(raw)
    -- -1: خانة بكرة بعد نص الليل ممكن تقع جوه «نص ساعة جاية».
    cross join lateral (values (-1), (0), (1)) as d(days_back)
    cross join lateral (
      select z.tz,
             (((now() at time zone z.tz)::date - d.days_back) + btrim(t.raw)::time) at time zone z.tz as scheduled_at
    ) s
    where coalesce(p.dose_times, '') <> ''
      and coalesce(p.has_invalid_dose_time, false) = false
      and (p.remaining_quantity is null or p.remaining_quantity > 0)
      and btrim(t.raw) ~ '^([01]?[0-9]|2[0-3]):[0-5][0-9]$'
      and s.scheduled_at between now() - interval '4 hours' and now() + interval '30 minutes'
      and s.scheduled_at > p.created_at
  ),
  gaps as (
    select *, lag(scheduled_at) over (partition by user_id order by scheduled_at, item_id) as prev
    from slots
  ),
  grouped as (
    select *, sum(case when prev is null or scheduled_at - prev > interval '30 minutes' then 1 else 0 end)
                over (partition by user_id order by scheduled_at, item_id rows unbounded preceding) as grp
    from gaps
  )
  select user_id, item_id, item_name, scheduled_at, tz, open,
         min(scheduled_at) over (partition by user_id, grp) as anchor,
         max(scheduled_at) over (partition by user_id, grp) as last_at
  from grouped;

  -- dose_due: رسالة واحدة للمجموعة، أول ١٠ دقايق من أول خانة فيها.
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select g.user_id, 'dose_due',
         jsonb_build_object(
           'item_name', g.names, 'item_ids', g.ids, 'scheduled_at', g.anchor, 'time_zone', g.tz,
           'slots', g.slots,
           'schedule_text', case when g.distinct_times > 1 then g.schedule_text end
         ),
         'dose_due:' || g.user_id || ':' || floor(extract(epoch from g.anchor))::bigint
  from (
    select user_id, anchor, tz,
           string_agg(item_name, ' و' order by scheduled_at, item_name) as names,
           jsonb_agg(item_id order by scheduled_at, item_name) as ids,
           jsonb_agg(jsonb_build_object('item_id', item_id, 'scheduled_at', scheduled_at) order by scheduled_at, item_name) as slots,
           string_agg(item_name || ' ' || to_char(scheduled_at at time zone tz, 'HH24:MI'), '، ' order by scheduled_at, item_name) as schedule_text,
           count(distinct scheduled_at) as distinct_times
    from pg_temp.zad_dose_slots
    where open
    group by user_id, anchor, tz
  ) g
  where g.anchor between now() - interval '10 minutes' and now()
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;
  v_inserted := v_inserted + v_count;

  -- تأجيل خلص ولسه الجرعة ماتاخدتش ⇒ تذكير واحد جديد (لكل دوا لوحده، زي ما كان).
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select sn.user_id, 'dose_due',
         jsonb_build_object(
           'item_name', p.name, 'item_ids', jsonb_build_array(sn.item_id),
           'scheduled_at', sn.scheduled_at, 'time_zone', public.zad_market_timezone(u.country),
           'slots', jsonb_build_array(jsonb_build_object('item_id', sn.item_id, 'scheduled_at', sn.scheduled_at)),
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

  -- متابعة واحدة للمجموعة: من ساعة لـ٣ ساعات بعد آخر خانة، للي لسه مفتوح بس.
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select g.user_id,
         case when g.missed_today > 0 then 'dose_missed_again' else 'dose_missed' end,
         jsonb_build_object(
           'item_name', g.names, 'item_ids', g.ids, 'scheduled_at', g.anchor, 'time_zone', g.tz,
           'slots', g.slots
         ),
         'dose_missed:' || g.user_id || ':' || floor(extract(epoch from g.anchor))::bigint
  from (
    select x.user_id, x.anchor, x.tz, max(x.last_at) as last_at,
           string_agg(x.item_name, ' و' order by x.scheduled_at, x.item_name) as names,
           jsonb_agg(x.item_id order by x.scheduled_at, x.item_name) as ids,
           jsonb_agg(jsonb_build_object('item_id', x.item_id, 'scheduled_at', x.scheduled_at) order by x.scheduled_at, x.item_name) as slots,
           (select count(*) from public.zad_voice_moments m
             where m.user_id = x.user_id and m.moment in ('dose_missed', 'dose_missed_again')
               and m.created_at >= (date_trunc('day', now() at time zone x.tz) at time zone x.tz)) as missed_today
    from pg_temp.zad_dose_slots x
    where x.open
    group by x.user_id, x.anchor, x.tz
  ) g
  where g.last_at between now() - interval '3 hours' and now() - interval '60 minutes'
    and g.missed_today < 3
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_count = row_count;
  v_inserted := v_inserted + v_count;

  return v_inserted;
end;
$function$;
