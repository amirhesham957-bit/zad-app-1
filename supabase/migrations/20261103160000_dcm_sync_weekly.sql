-- مزامنة DCM الأسبوعية (ZAD_PLAN ٤.٥).
--
-- أول تجربة dry على الحي ٣/١١ (بسر كرون المشروع، #٣٧٨): ٢٠٠، Codes Hub = ٠ كوبون (الرد success والقايمة فاضية —
-- الحساب لسه مالوش كوبونات متوافق عليها)، وHasOffers = ٨٣ عرض ⇒ ٣٣٧ صف حسب البلد، منهم ٦٩ محتاجين المالك يوافق على
-- شروطهم في لوحة DCM قبل ما يطلعلهم رابط. المابينج اشتغل، فالمزامنة بالكتابة تبدأ: الأربع ٥:١٣ UTC، قبل كرون العروض بتاع
-- الخميس. الصف اللي المزامنة ماشافتهوش بيتقفل (active = false)، فالعرض اللي اتشال من DCM مابيفضلش.
-- السيرفر بس. رقم الإصدار مش على ساعة مدوّرة عن قصد.

do $cron$
begin
  if to_regnamespace('cron') is null or to_regprocedure('public.zad_cron_secret(text)') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.schedule(
    'dcm-sync-weekly',
    '13 5 * * 3',
    $job$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/sync-dcm-offers',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id;
    $job$
  );
end
$cron$;
