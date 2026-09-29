-- update-behavior-profile بقى يطلب هيدر ZAD-PROACTIVE-CRON-SECRET (بند 30.11). الكرون كان
-- بيبعت مفتاح الديمو المحلي ("iss":"supabase-demo"، 20260721150210) — مابيفتحش حاجة،
-- والدالة كانت شغالة بس لأنها مفتوحة للإنترنت أصلاً. نفس السر اللي brain-daily-analysis
-- بيبعته، من الـvault، ونفس الميعاد والمهلة.
-- إعادة جدولة بنفس الاسم بتستبدل الجوب الموجود (نفس نمط 20260905150000).
select cron.schedule(
  'update-behavior-profile-daily',
  '0 23 * * *',
  $job$
  select net.http_post(
      url:='https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/update-behavior-profile',
      headers:=jsonb_build_object(
        'Content-Type', 'application/json',
        'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
      ),
      body:='{}'::jsonb,
      timeout_milliseconds:=60000
    ) as request_id;
  $job$
);
