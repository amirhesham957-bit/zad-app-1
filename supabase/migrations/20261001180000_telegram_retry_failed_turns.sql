-- Telegram messages the brain could not answer are retried (zad-telegram-bot ?job=retry_failed).
--
-- When the brain failed, the bot used to answer from a second, read-only model with its own
-- instructions — and did not store that reply, so the question came back unanswered later
-- (2026-10-01: «مرحبا» at 20:02 got the 14:52 gold question). The bot now tells the customer
-- the message is kept, queues it in zad_brain_queue (trigger = 'telegram_retry'), and this job
-- answers it in the same chat when the brain is back. zad_brain_queue had a writer and no
-- reader until now.
--
-- Every two minutes, and only when something is queued: the check runs in SQL, so an empty
-- queue costs no function call.
select cron.unschedule('telegram-retry-failed')
where exists (select 1 from cron.job where jobname = 'telegram-retry-failed');

select cron.schedule(
  'telegram-retry-failed',
  '*/2 * * * *',
  $$
  select net.http_post(
    url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=retry_failed',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Checkin-Cron-Secret', public.zad_cron_secret('zad_checkin_cron_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  )
  where exists (select 1 from public.zad_brain_queue where trigger = 'telegram_retry');
  $$
);
