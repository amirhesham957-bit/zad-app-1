-- م٥.٧: تنبيه المالك على الأعطال (كرون فشل أو اتأخر، مهمة طابور فشلت، مفتاح وقف اتقفل).
-- zad-telegram-bot ?job=ops_alert بيقرر (_shared/opsAlert.ts) وبيبعت لشات الأدمن بس، مرة كل ٦ ساعات.
-- الحالة في zad_admin_alert_log (kind='ops_alert').

select cron.unschedule('ops-alert-15min') where exists (select 1 from cron.job where jobname = 'ops-alert-15min');
select cron.schedule('ops-alert-15min', '*/15 * * * *', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=ops_alert',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 30000
      ) as request_id;
    $cron$);
