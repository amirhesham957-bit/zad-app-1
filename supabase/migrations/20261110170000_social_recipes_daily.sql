-- وصفات التريند كل يوم بدل الأحد والأربع (طلب المالك ١٠/١١: «مش بيجيلي ترندات الوصفات»).
--
-- الكرون اتعمل ٨/١١ الساعة ٢١:٣١، بعد نوبة الأحد، فأول تشغيل كان هيبقى الأربع ١١/١١: لحد النهارده
-- ماشتغلش ولا مرة (cron.job_run_details فاضي). ومع حساب نادية السيد وهاشتاجات الترند بقى فيه ٣٢ مصدر على ٣
-- نوبات، والنوبة بتقف عند ١١٠ ثانية، فمرتين في الأسبوع كانت هتسيب مصادر كتير من غير ما تتقري. كل يوم +
-- rotateForDay (بداية مختلفة كل يوم) = كل مصدر بيتقري خلال كام يوم. نفس النداء بالحرف، الميعاد بس.

select cron.unschedule('social-recipes-twice-weekly') where exists (select 1 from cron.job where jobname = 'social-recipes-twice-weekly');
select cron.unschedule('social-recipes-daily') where exists (select 1 from cron.job where jobname = 'social-recipes-daily');
select cron.schedule('social-recipes-daily', '7,27,47 11 * * *', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := jsonb_build_object('action', 'social_recipes_run', 'slot', (extract(minute from now())::int / 20)),
        timeout_milliseconds := 150000
      ) as request_id;
    $cron$);
