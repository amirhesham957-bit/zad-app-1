-- تنبيه المالك لما قراية العروض الأسبوعية تفشل أو ترجّع صفر صفقات.
-- zad-telegram-bot ?job=flyer_health بيقرر (flyerHealthAlert.ts) وبيبعت لشات الأدمن بس،
-- ومرة كل ٢٤ ساعة. الحالة متخزنة في zad_admin_alert_log (اتعملت في المايجريشن بتاع البحث).

select cron.unschedule('flyer-health-daily') where exists (select 1 from cron.job where jobname = 'flyer-health-daily');
select cron.schedule('flyer-health-daily', '17 5 * * *', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=flyer_health',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 30000
      ) as request_id;
    $cron$);
