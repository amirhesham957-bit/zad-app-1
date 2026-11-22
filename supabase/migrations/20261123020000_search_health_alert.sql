-- م٥.٧: تنبيه المالك لما مزودات البحث تقع (محركات خلصت حصتها أو البحث بيرجّع صفر).
-- zad-telegram-bot ?job=search_health بيقرر (searchHealthAlert.ts) وبيبعت لشات الأدمن بس (ZAD_ADMIN_CHAT_ID)،
-- ومرة كل ١٢ ساعة. الحالة هنا: آخر مرة اتبعت.

create table if not exists public.zad_admin_alert_log (
  kind text primary key,
  last_sent timestamptz not null
);
alter table public.zad_admin_alert_log enable row level security;
-- من غير سياسات: السيرفر بس (service role).

select cron.unschedule('search-health-daily') where exists (select 1 from cron.job where jobname = 'search-health-daily');
select cron.schedule('search-health-daily', '37 */6 * * *', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=search_health',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 30000
      ) as request_id;
    $cron$);
