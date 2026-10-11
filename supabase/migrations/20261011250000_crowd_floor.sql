-- أرضية الجمهور في SQL (الموجة ٨، ٢٠٢٦-١٠-١١). نفس قاعدة zad-brain/crowdFloor.ts.
--
-- قرار المالك: «أرضية الـ٣ بيوت والتأمين الخصوصي للبلاغات». مكانين في SQL بيقولوا أرقام من الجمهور:
--
--   zad_cheapest_prices — صفحة الأسعار في التطبيق وبوست قناة المجتمع في تليجرام كل يوم. كانت بتعرض أي صنف
--     ليه بلاغ واحد: المحل والسعر والوقت — يعني مشترى بيت بعينه. دلوقتي الصنف بيظهر بس لو بلّغ عنه ٣ بيوت
--     مختلفة على الأقل (أفراد العيلة بيت واحد)، والبلاغات الشاذة (أكتر من ٣ أضعاف الوسيط أو أقل من تلته)
--     بتتشال قبل الحساب والأرخص. الأعمدة والصلاحيات زي ما هي.
--   _agent_predicted_shortage_for_user — «أرخص سعر متسجّل X في Y» جوه سؤال «هيخلص إمتى؟»: بيتقال بس لو
--     الصنف ليه بلاغات من ٣ بيوت (آخر ١٤ يوم، بعملة العميل). تعديل جملة واحدة على النص الحي.
--
-- zad_cheapest_prices بتتكتب من جديد بالكامل (أسهل وأوضح من تعديل جمل)، بس بعد ما المايجريشن تتأكد إن النص الحي
-- هو الشكل المتوقع (20260921160000): وإلا بتقف.

do $guard$
declare v_def text;
begin
  select pg_get_functiondef('public.zad_cheapest_prices(text, text, integer, integer)'::regprocedure) into v_def;
  if regexp_count(v_def, 'stats\s+as\s+\(') <> 1 or regexp_count(v_def, 'cheapest\s+as\s+\(') <> 1
     or regexp_count(v_def, 'source\s*=\s*''crowdsource''') <> 1 then
    raise exception 'crowd floor: zad_cheapest_prices is not the expected shape — read it before replacing';
  end if;
end
$guard$;

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
security definer
set search_path to 'public'
as $function$
  with recent as (
    select lower(btrim(regexp_replace(p.item_name, '\s+', ' ', 'g'))) as item_key,
           btrim(p.item_name) as item_name, p.price, p.location, p.store_name, p."timestamp" as reported_at,
           coalesce((select m.family_id::text from public.family_members m where m.user_id = p.user_id limit 1),
                    p.user_id::text) as home
    from public.price_index p
    where p.source = 'crowdsource'
      and p.currency = p_currency
      and p.price > 0
      and p.user_id is not null
      and p."timestamp" > now() - make_interval(days => greatest(1, least(coalesce(p_days, 14), 60)))
      and (p_location is null or btrim(p_location) = '' or p.location ilike '%' || btrim(p_location) || '%')
  ),
  medians as (
    select item_key, percentile_cont(0.5) within group (order by price) as median
    from recent group by item_key
  ),
  kept as (
    select r.* from recent r join medians m using (item_key)
    where r.price <= m.median * 3 and r.price >= m.median / 3
  ),
  stats as (
    select item_key, min(price) as min_price, avg(price) as avg_price, count(*)::int as reports,
           max(reported_at) as last_reported
    from kept group by item_key
    having count(distinct home) >= 3
  ),
  cheapest as (
    select distinct on (item_key) item_key, item_name, location, store_name
    from kept where item_key in (select item_key from stats)
    order by item_key, price asc, reported_at desc
  )
  select c.item_name, s.min_price, round(s.avg_price::numeric, 2)::double precision, s.reports,
         c.location, c.store_name, s.last_reported
  from stats s join cheapest c using (item_key)
  order by s.reports desc, s.last_reported desc
  limit greatest(1, least(coalesce(p_limit, 20), 50));
$function$;

do $migrate$
declare
  v_def text;
  v_pat text;
  v_hits int;
begin
  select pg_get_functiondef('public._agent_predicted_shortage_for_user(uuid)'::regprocedure) into v_def;
  v_pat := regexp_replace('and pi.price > 0', '([.*+?^${}()|\[\]\\])', '\\\1', 'g');
  v_pat := regexp_replace(v_pat, ' ', '\\s+', 'g');
  v_hits := regexp_count(v_def, v_pat);
  if v_hits <> 1 then
    raise exception 'crowd floor: _agent_predicted_shortage_for_user has % matches, expected 1', v_hits;
  end if;
  execute regexp_replace(v_def, v_pat,
    'and pi.price > 0 and (select count(distinct coalesce((select fm.family_id::text from public.family_members fm '
    || 'where fm.user_id = x.user_id limit 1), x.user_id::text)) from public.price_index x '
    || 'where lower(trim(x.item_name)) = lower(trim(i.item_name)) and x.source = ''crowdsource'' and x.price > 0 '
    || 'and x.currency = v_currency and x."timestamp" > now() - interval ''14 days'') >= 3');
end
$migrate$;
