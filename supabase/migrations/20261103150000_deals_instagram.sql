-- إنستجرام مصدر عروض أسبوعي لوحده (ZAD_PLAN ٤.١٢): نفس المحلات بأسبوعها، زي يوتيوب (20261102201700).
--
-- ٣/١١: المالك حط INSTAGRAM_BUSINESS_ACCOUNT_ID، وفحص ما بعد النشر قال الحساب ٢٠٠ والبحث بالهاشتاج ٢٠٠ (Public Content
-- Access متاح). قبلها مكانش فيه غير الفحص — ولا بوست بيتقري.
--   • zad_deal_search_log.source يقبل 'instagram'.
--   • deals-instagram-weekly — الخميس ٨–٩ الصبح UTC بعد يوتيوب، كل ٢٠ دقيقة (٦ نداءات × ٣ محلات = ١٨ محل بالكتير):
--     الحساب ليه ٣٠ هاشتاج جديد في ٧ أيام، والفحص بياخد واحد.
-- السيرفر بس. رقم الإصدار مش على ساعة مدوّرة عن قصد.

alter table public.zad_deal_search_log drop constraint if exists zad_deal_search_log_source_check;
alter table public.zad_deal_search_log add constraint zad_deal_search_log_source_check
  check (source in ('search', 'youtube', 'instagram'));

do $cron$
begin
  if to_regnamespace('cron') is null or to_regprocedure('public.zad_cron_secret(text)') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.schedule(
    'deals-instagram-weekly',
    '7,27,47 8,9 * * 4',
    $job$
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
    $job$
  );
end
$cron$;
