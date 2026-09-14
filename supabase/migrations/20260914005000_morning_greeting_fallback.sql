-- "صباح الخير" احتياطي الساعة ١٠ بتوقيت العميل (٢٠٢٦-٠٩-١٤).
--
-- الطريق الأساسي: الموبايل بيلاحظ إن العميل صحى (أول فتح للقفل الصبح بعد ٣ ساعات شاشة
-- مقفولة، عن طريق خدمة قراءة إشعارات البنك اللي شغالة أصلاً) وبينادي zad-brain moment_event.
-- ده للعملاء اللي الخدمة دي مش متفعلة عندهم: لو لحد الساعة ١٠ مفيش تحية اتسجلت النهارده،
-- الكرون يسجّل واحدة. نفس dedupe_key بتاع التطبيق (morning:<تاريخ محلي>)، فمفيش تحيتين.
-- العقل بيملا أدوية ومواعيد النهارده والرصيد وقت الكتابة (voiceMoments.ts).
--
-- "نشط" = سجّل دخول أو حدّث توكن إشعارات آخر ١٤ يوم — مفيش صباح خير لحساب مهجور.

create or replace function public.zad_enqueue_morning_fallback()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_inserted int;
begin
  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select x.user_id, 'morning_greeting',
         jsonb_build_object('local_date', x.local_date, 'time_zone', x.tz, 'source', 'fallback_10am'),
         'morning:' || x.local_date
  from (
    select au.id as user_id,
           public.zad_market_timezone(u.country) as tz,
           to_char(now() at time zone public.zad_market_timezone(u.country), 'YYYY-MM-DD') as local_date,
           extract(hour from now() at time zone public.zad_market_timezone(u.country))::int as local_hour
    from auth.users au
    join public.zad_users u on u.id = au.id
    where au.last_sign_in_at > now() - interval '14 days'
       or exists (select 1 from public.zad_fcm_tokens t where t.user_id = au.id and t.updated_at > now() - interval '14 days')
  ) x
  where x.local_hour = 10
  on conflict (user_id, dedupe_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;

revoke all on function public.zad_enqueue_morning_fallback() from public;
revoke all on function public.zad_enqueue_morning_fallback() from anon;
revoke all on function public.zad_enqueue_morning_fallback() from authenticated;

select cron.unschedule('voice-moments-processor')
where exists (select 1 from cron.job where jobname = 'voice-moments-processor');

select cron.schedule(
  'voice-moments-processor',
  '*/5 * * * *',
  $$
  select public.zad_enqueue_missed_doses();
  select public.zad_enqueue_appointment_moments();
  select public.zad_enqueue_morning_fallback();
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
