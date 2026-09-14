-- «أرخص سعر حواليك» من بلاغات مجتمع زاد + بوست يومي لقناة تليجرام (٢٠٢٦-٠٩-١٤).
--
-- price_index فيه بلاغات العملاء (source = 'crowdsource') بالمدينة اللي كتبوها. كان ناقصه اسم
-- المحل (الشاشة بتسأل عنه وبيترمي)، ومفيش طريقة تجاوب «فين أرخص طماطم؟» غير إنك تلف على
-- الصفوف كلها على الموبايل.
--
-- zad_cheapest_prices: لكل صنف في عملة (وممكن مدينة) آخر N يوم — أرخص سعر، ومكانه ومحله،
-- والمتوسط، وعدد البلاغات. الأسماء بتتوحّد بالشكل (مسافات/حروف كبيرة) بس، مش بالمعنى.
-- security invoker: price_index قراءته عامة أصلاً (price_index_public_read)، فمفيش حاجة تتكشف.

alter table public.price_index
  add column if not exists store_name text check (store_name is null or char_length(store_name) <= 60);

create index if not exists idx_price_index_crowd_recent
  on public.price_index (currency, timestamp desc) where source = 'crowdsource';

create or replace function public.zad_cheapest_prices(
  p_currency text,
  p_location text default null,
  p_days int default 14,
  p_limit int default 20
)
returns table (
  item_name text,
  min_price double precision,
  avg_price double precision,
  reports int,
  cheapest_location text,
  cheapest_store text,
  last_reported timestamptz
)
language sql
stable
set search_path to 'public'
as $function$
  with recent as (
    select lower(btrim(regexp_replace(p.item_name, '\s+', ' ', 'g'))) as item_key,
           btrim(p.item_name) as item_name, p.price, p.location, p.store_name, p."timestamp" as reported_at
    from public.price_index p
    where p.source = 'crowdsource'
      and p.currency = p_currency
      and p.price > 0
      and p."timestamp" > now() - make_interval(days => greatest(1, least(coalesce(p_days, 14), 60)))
      and (p_location is null or btrim(p_location) = '' or p.location ilike '%' || btrim(p_location) || '%')
  ),
  stats as (
    select item_key, min(price) as min_price, avg(price) as avg_price, count(*)::int as reports, max(reported_at) as last_reported
    from recent group by item_key
  ),
  cheapest as (
    select distinct on (item_key) item_key, item_name, location, store_name
    from recent order by item_key, price asc, reported_at desc
  )
  select c.item_name, s.min_price, round(s.avg_price::numeric, 2)::double precision, s.reports,
         c.location, c.store_name, s.last_reported
  from stats s join cheapest c using (item_key)
  order by s.reports desc, s.last_reported desc
  limit greatest(1, least(coalesce(p_limit, 20), 50));
$function$;

revoke all on function public.zad_cheapest_prices(text, text, int, int) from public;
revoke all on function public.zad_cheapest_prices(text, text, int, int) from anon;
grant execute on function public.zad_cheapest_prices(text, text, int, int) to authenticated, service_role;

-- بوست يومي الساعة ٦ مساءً UTC (٩ بالليل القاهرة/الرياض). البوت بيتخطى بهدوء لو قناة المجتمع
-- مش متظبطة (TELEGRAM_COMMUNITY_CHAT_ID)، ومش بيبعت بوست فاضي.
select cron.unschedule('community-prices-daily')
where exists (select 1 from cron.job where jobname = 'community-prices-daily');

select cron.schedule(
  'community-prices-daily',
  '0 18 * * *',
  $$
  select net.http_post(
    url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=community_prices',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
  $$
);
