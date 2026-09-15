-- «زاد تزعل لو ماخدتش الدوا» من السيرفر مباشرة + «تصبح على خير» (٢٠٢٦-٠٩-١٥).
--
-- بلاغ: «ميزة إنها تزعل لو مخدتش الدوا كانت موجودة ومبقتش تبعت». القياس من الإنتاج:
--   - zad_enqueue_missed_doses كانت بتقرا zad_dose_log بس، والصفوف دي بيكتبها الموبايل لما منبه الجرعة
--     يرن. آخر أسبوع: صفوف أيام ٩ و١٠ و١٤ بس — ولا صف ١١ و١٢ و١٣. يعني لو المنبه مارنش أو التطبيق
--     مقفول، العقل مايعرفش إن فيه جرعة أصلاً.
--   - في نفس الوقت ٨ أدوية عندها dose_times متسجلة، وتليجرام مربوط، وفويس الجرعة الفايتة وصل فعلاً
--     يوم ١٤ (لوج `[voiceAlert] delivered`) — يعني التوصيل سليم والناقص هو إن اللحظة تتسجل.
--
-- دلوقتي المواعيد بتتحسب من zad_pharmacy_items.dose_times بتوقيت بلد العميل، والجرعة بتتحسب
-- «متاخدة» لو فيه تسجيل في zad_pharmacy_doses أو zad_dose_log من ٣ ساعات قبل ميعادها. الأدوية اللي
-- ميعادها واحد بتتجمع في لحظة واحدة (فويس واحد مش تلاتة)، وأقصى ٣ فويسات زعل في اليوم لكل عميل.

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
    and s.scheduled_at between now() - interval '3 hours' and now() - interval '30 minutes'
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

-- «تصبح على خير» الساعة ١١ بالليل بتوقيت العميل — نفس أهلية «صباح الخير» (014)، ومن غير حسابات الأطفال.
-- البيانات (مواعيد بكرة وأول دوا الصبح) بتتملى وقت الكتابة في zad-brain.
create or replace function public.zad_enqueue_good_night()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int;
begin
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select x.user_id, 'good_night',
         jsonb_build_object('local_date', x.local_date, 'time_zone', x.tz),
         'good_night:' || x.local_date
  from (
    select au.id as user_id,
           public.zad_market_timezone(u.country) as tz,
           to_char(now() at time zone public.zad_market_timezone(u.country), 'YYYY-MM-DD') as local_date,
           extract(hour from now() at time zone public.zad_market_timezone(u.country))::int as local_hour
    from auth.users au
    join public.zad_users u on u.id = au.id
    where au.last_sign_in_at > now() - interval '14 days'
       or exists (select 1 from public.zad_fcm_tokens t where t.user_id = au.id and t.updated_at > now() - interval '14 days')
       or exists (select 1 from public.telegram_bindings b where b.user_id = au.id and b.chat_id is not null)
       or exists (select 1 from public.zad_chat_turns c where c.user_id = au.id and c.created_at > now() - interval '14 days')
  ) x
  where x.local_hour = 23
    and not exists (select 1 from public.family_members fm where fm.user_id = x.user_id and fm.role = 'child')
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_good_night() from public;
revoke all on function public.zad_enqueue_good_night() from anon;
revoke all on function public.zad_enqueue_good_night() from authenticated;

select cron.unschedule('voice-moments-processor')
where exists (select 1 from cron.job where jobname = 'voice-moments-processor');

select cron.schedule(
  'voice-moments-processor',
  '*/5 * * * *',
  $$
  select public.zad_enqueue_missed_doses();
  select public.zad_enqueue_appointment_moments();
  select public.zad_enqueue_morning_fallback();
  select public.zad_enqueue_good_night();
  select public.zad_enqueue_weekly_money_story();
  select public.zad_evaluate_savings_challenges();
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
    where status = 'pending' and created_at > now() - interval '6 hours'
  );
  $$
);
