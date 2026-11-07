-- تيك توك من غير كشط (طلب المالك ٧/١١: «تيك توك أساسي جداً»). zad-core-intelligence/tiktokDeals.ts:
-- محرك البحث بـsite:tiktok.com ⇐ نص نتايج الفيديوهات (العنوان والوصف زي ما المحرك فهرسهم) ⇐ جيميناي ⇐ العرض برابط
-- الفيديو والكود في zad_deal_codes. مفيش طلب واحد لتيك توك نفسه (ولا معاينة صفحة — pagePreview بيتخطى tiktok.com).
-- oEmbed الرسمي اتقاس ٧/١١ وبقى من غير كابشن ولا غلاف؛ والكشط (TikTok-Api، RSSHub) مرفوض في جدول المستودعات.
--
--   • zad_deals.source_kind و zad_deal_search_log.source بيقبلوا 'tiktok' (zad_deal_codes كان بيقبله من ٤/١١).
--   • كرون deals-tiktok-daily: ٦ نداءات × ٤ محلات (TIKTOK_STORES_PER_RUN) — كل يوم وقت الموسم، والخميس بس بعده؛
--     بيتنادى بس لو فيه محل جه دوره (zad_deal_source_targets بـ'tiktok').
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

alter table public.zad_deals drop constraint if exists zad_deals_source_kind_check;
alter table public.zad_deals add constraint zad_deals_source_kind_check
  check (source_kind = any (array['receipt', 'search', 'flyer', 'partner', 'youtube', 'instagram', 'email', 'tiktok']));

alter table public.zad_deal_search_log drop constraint if exists zad_deal_search_log_source_check;
alter table public.zad_deal_search_log add constraint zad_deal_search_log_source_check
  check (source = any (array['search', 'youtube', 'instagram', 'tiktok']));

select cron.unschedule('deals-tiktok-daily') where exists (select 1 from cron.job where jobname = 'deals-tiktok-daily');
select cron.schedule('deals-tiktok-daily', '23,43 10,11,12 * * *', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"deals_tiktok_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id
    where (extract(isodow from now()) = 4 or public.zad_deal_season_on())
      and exists (select 1 from public.zad_deal_source_targets(1, 'tiktok'));
    $cron$);
