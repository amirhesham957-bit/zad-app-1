-- م٦.٣: الكرون اليومي بتاع zad-trend-surge (منفصل عن الجدول عشان تست السكراتش مفيهوش pg_cron).
-- كرون يومي 5:10 UTC (بعد ما اليوم اللي فات يقفل). لازم سر الإيدج ZAD_TREND_CRON_SECRET يساوي سر الـVault zad_trend_cron_secret؛
-- لحد ما يتظبط الدالة بترفض بـ401 (بتفشل مقفولة).
select cron.schedule(
  'zad-trend-surge-daily',
  '10 5 * * *',
  $cron$
  select net.http_post(
    url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-trend-surge',
    headers := jsonb_build_object(
      'X-Trend-Cron-Secret', public.zad_cron_secret('zad_trend_cron_secret'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 55000
  );
  $cron$
);
