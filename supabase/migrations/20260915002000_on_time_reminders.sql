-- التذكير في وقته بالظبط (٢٠٢٦-٠٩-١٥).
--
-- بلاغ: «بقوله يفكرني بالميعاد… عاوزك تتأكد إن مواعيد التذكير دقيقة» و«بتفكرني بعد ٣ ساعات».
-- القياس من الإنتاج نفس اليوم:
--   - «أشرب مية» اتطلبت ٠٤:٠٤ لـ٠٤:١٤ (بتوقيت مصر). remind_minutes_before الافتراضي ٣٠، فوقت التذكير
--     (٠٣:٤٤) كان فات لحظة الحفظ ⇒ التذكير اتبعت ٠٤:٠٥ — ٩ دقايق بدري، مش في الوقت اللي اتطلب.
--   - «اشرب مياه» من تليجرام: remind_minutes_before = 0. الشرط كان `now() >= starts_at - 0 and now() < starts_at`
--     — فترة فاضية. **تذكير بصفر دقيقة عمره ما كان بيتبعت**، والمتكرر كان بيتنقل لبكرة كل يوم من غير تذكير.
--   - «فكرني كل ساعة» اتسجل daily: recurrence ماكانش فيها hourly، فالموديل مالقاش طريقة يقولها.
--   - جرعة ٠٦:٠٠: أول حاجة على تليجرام كانت فويس «نسيت الدوا؟» ٠٧:٠٠. السيرفر ماكانش بيبعت تذكير في
--     الميعاد نفسه أصلاً — كان معتمد على منبه الموبايل، واللي فوقه تذكير مكتوب بعد ٣٠ دقيقة للموبايل بس.
--   - الكرون كل ٥ دقايق ⇒ أي تذكير ممكن يتأخر لحد ٥ دقايق حتى لو الحسبة صح.
--
-- التعديلات:
--   1. recurrence = hourly.
--   2. وقت التذكير: قبلها بـremind_minutes_before لو فيه وقت كفاية من ساعة الحفظ/آخر تعديل، وإلا في وقت الميعاد
--      نفسه. والنافذة مفتوحة لحد ١٠ دقايق بعد الميعاد (صفر دقيقة بقى بيشتغل، وكرون متأخر دقيقة مابيضيّعوش).
--   3. المتكرر بيتنقل للمرة الجاية بعد ١٠ دقايق من ميعاده (كان ساعة — ماينفعش مع hourly).
--   4. dose_due: فويس حنين في ميعاد الجرعة (أول ١٠ دقايق)، على تليجرام — الموبايل عنده منبه دقيق بيتكلم لوحده.
--   5. كرون كل دقيقة للمواعيد والجرعات، والعقل بيتنادى بس لو فيه لحظة منهم مستنية.
--   6. status = sending + claimed_at: كرونين (دقيقة و٥ دقايق) أو التطبيق ممكن يعالجوا نفس الطابور في نفس
--      اللحظة. من غير حجز ذرّي نفس الفويس كان هيتبعت مرتين.

alter table public.zad_appointments drop constraint if exists zad_appointments_recurrence_check;
alter table public.zad_appointments add constraint zad_appointments_recurrence_check
  check (recurrence in ('once', 'hourly', 'daily', 'weekly', 'monthly'));

alter table public.zad_voice_moments add column if not exists claimed_at timestamptz;
alter table public.zad_voice_moments drop constraint if exists zad_voice_moments_status_check;
alter table public.zad_voice_moments add constraint zad_voice_moments_status_check
  check (status in ('pending', 'sending', 'sent', 'skipped', 'failed'));

create or replace function public.zad_enqueue_appointment_moments()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int;
begin
  -- الميعاد المتكرر اللي عدّى عليه أكتر من ١٠ دقايق يتنقل لأول مرة جاية (ممكن كذا خطوة لو فات وقت طويل).
  update public.zad_appointments a
  set starts_at = a.starts_at + (
        case a.recurrence
          when 'hourly' then interval '1 hour'
          when 'daily' then interval '1 day'
          when 'weekly' then interval '7 days'
          else interval '1 month'
        end
      ) * greatest(1, ceil(
        extract(epoch from (now() - interval '10 minutes' - a.starts_at)) /
        extract(epoch from case a.recurrence
          when 'hourly' then interval '1 hour'
          when 'daily' then interval '1 day'
          when 'weekly' then interval '7 days'
          else interval '30 days'
        end)
      ))::int,
      updated_at = now()
  where a.status = 'upcoming'
    and a.recurrence <> 'once'
    and a.starts_at < now() - interval '10 minutes';

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

-- نفس 20260915001000 بالظبط، زايد dose_due في الميعاد (النافذة بقت لحد دلوقتي بدل ٣٠ دقيقة فاتت).
create or replace function public.zad_enqueue_missed_doses()
returns int
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
    and not exists (
      select 1 from public.zad_pharmacy_doses pd
      where pd.user_id = p.user_id and pd.item_id = p.id and pd.status = 'taken'
        and coalesce(pd.taken_at, pd.scheduled_at) >= s.scheduled_at - interval '3 hours'
    )
    and not exists (
      select 1 from public.zad_dose_log l
      where l.user_id = p.user_id and l.pharmacy_item_id = p.id
        and l.taken_at >= s.scheduled_at - interval '3 hours'
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

revoke all on function public.zad_enqueue_missed_doses() from public;
revoke all on function public.zad_enqueue_missed_doses() from anon;
revoke all on function public.zad_enqueue_missed_doses() from authenticated;

-- كل دقيقة: المواعيد والجرعات بس. الكرون التاني (كل ٥ دقايق) فضل زي ما هو للباقي؛ لو الاتنين سجّلوا نفس
-- اللحظة dedupe_key بيمنع التكرار، ولو الاتنين عالجوا الطابور مع بعض الحجز (sending) بيمنع فويس مكرر.
select cron.unschedule('reminders-minutely')
where exists (select 1 from cron.job where jobname = 'reminders-minutely');

select cron.schedule(
  'reminders-minutely',
  '* * * * *',
  $$
  select public.zad_enqueue_appointment_moments();
  select public.zad_enqueue_missed_doses();
  select net.http_post(
      url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
      ),
      body := '{"action":"process_voice_moments"}'::jsonb,
      timeout_milliseconds := 55000
    ) as request_id
  where exists (
    select 1 from public.zad_voice_moments
    where status = 'pending'
      and moment in ('appointment_soon', 'dose_due')
      and created_at > now() - interval '15 minutes'
  );
  $$
);
