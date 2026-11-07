-- النشرات الرسمية من موقع المحل نفسه (طلب المالك ٧/١١: «بدائل خفيفة» لأدوات الكشط، على الباقة المجانية).
--
--   • zad_flyer_reads — كل نشرة PDF اتقرت (أو فشلت) برابطها، عشان مابتتقريش تاني. النشرة الجديدة بتيجي برابط جديد
--     (اسم الملف هاش). اللي فشلت بتتجرب تاني بعد ٢٠ ساعة (storeDeals.ts: FLYER_RETRY_HOURS).
--   • كرون deals-flyers-daily: كل ١٠ دقايق من ٢:٠٧ لـ٣:٥٧ UTC — نشرة واحدة في كل نداء (PDF الدانوب ١٣–٤٢ ميجا
--     بياخد أغلب الـ١٥٠ ثانية). أول قايمة = ١٢ نشرة ⇒ يومين؛ بعدها النداء بيقرا صفحة المحل بس ويرجع.
-- القايمة والقواعد (robots.txt، المواقع المسموحة، شكل الرابط) في zad-core-intelligence/officialFlyers.ts.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

create table if not exists public.zad_flyer_reads (
  pdf_url text primary key check (pdf_url ~ '^https://' and char_length(pdf_url) <= 500),
  store text not null check (char_length(store) between 1 and 60),
  country text not null check (country ~ '^[A-Z]{2}$'),
  city text not null default '' check (char_length(city) <= 60),
  label text not null default '' check (char_length(label) <= 80),
  ok boolean not null,
  deals int not null default 0 check (deals >= 0),
  reason text check (reason is null or char_length(reason) <= 60),
  read_at timestamptz not null default now()
);

alter table public.zad_flyer_reads enable row level security;
revoke all on public.zad_flyer_reads from anon, authenticated;
grant all on public.zad_flyer_reads to service_role;

select cron.unschedule('deals-flyers-daily') where exists (select 1 from cron.job where jobname = 'deals-flyers-daily');
select cron.schedule('deals-flyers-daily', '7,17,27,37,47,57 2,3 * * *', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"deals_flyers_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id;
    $cron$);
