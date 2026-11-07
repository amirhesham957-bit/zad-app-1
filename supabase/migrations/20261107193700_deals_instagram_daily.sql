-- إنستجرام كل يوم (سؤال المالك ٧/١١: «ليه مش كل يوم»).
--
-- الاتنين والخميس كانوا عشان حد Meta: ٣٠ هاشتاج مختلف في الأسبوع على الحساب. بس أكونت المحل نفسه (Business
-- Discovery) مابيعدّش من الـ٣٠. فدلوقتي: الكرون كل يوم، وzad-brain (isInstagramHashtagDay) بيقرا أكونت المحل كل
-- يوم، والهاشتاج — للمحل اللي مالوش أكونت — الاتنين والخميس بس زي الأول. نفس الـ٦ نداءات × ٣ محلات في اليوم،
-- ونفس فترة التحديث (zad_deal_refresh_interval) جوه zad_deal_source_targets.

select cron.unschedule('deals-instagram-weekly') where exists (select 1 from cron.job where jobname = 'deals-instagram-weekly');
select cron.schedule('deals-instagram-weekly', '7,27,47 8,9 * * *', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"deals_instagram_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id
    where exists (select 1 from public.zad_deal_source_targets(1, 'instagram'));
    $cron$);
