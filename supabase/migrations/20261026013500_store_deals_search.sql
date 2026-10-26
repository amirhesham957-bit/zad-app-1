-- المصدر التاني للعروض (ZAD_PLAN ٤.٣): بحث أسبوعي لكل محل مهم في كل بلد فيه عملاء، والنتيجة في zad_deals.
--
-- بحث واحد بيخدم كل عملاء البلد: «عروض كيو السعودية» مرة في الأسبوع، مش مرة لكل بيت. المدينة '' = المحل في
-- البلد كله، لأن الحساب مافيهوش مدينة (zad_users فيها البلد ونقطة تقريبية بس) — المدن والفروع مع ٤.٧.
--
-- المحلات منين (zad_deal_search_targets):
--   • الفواتير (price_index، crowdsource): الفاتورة المطبوعة اسمها اسم محل، فبيت واحد كفاية.
--   • حركات البنك: التاجر بيتحسب بس لو بيتين مختلفين (العيلة بيت واحد) دفعوله آخر ٦٠ يوم. «التاجر» في
--     حركة بيت واحد ممكن يكون شخص اتحوّله فلوس، واسمه مايروحش لمحرك بحث أبداً. التحويلات برّه خالص.
--   • محل اتدوّر عليه آخر ٦ أيام (صف search لسه طازة) مايتدوّرش عليه تاني.
--
-- الكاتب: zad-brain (deals_search_run) بينادي zad-core-intelligence (store_deals) لكل محل، وكل عرض بيدخل من
-- zad_deal_put برابطه. السقف: ١٠ محلات في الأسبوع، جوه ZAD_SEARCH_DAILY_CAP.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

create or replace function public.zad_deal_search_targets(p_limit int default 10)
returns table (country text, store text, currency text, homes int, seen int)
language sql
stable
security definer
set search_path to 'public'
as $$
  with raw as (
    select upper(btrim(u.country)) as country,
           btrim(regexp_replace(p.store_name, '\s+', ' ', 'g')) as store,
           upper(btrim(p.currency)) as currency,
           coalesce((select m.family_id::text from public.family_members m where m.user_id = p.user_id limit 1),
                    p.user_id::text) as home,
           'receipt' as origin
      from public.price_index p
      join public.zad_users u on u.id = p.user_id
     where p.source = 'crowdsource'
       and p."timestamp" > now() - interval '60 days'
       and p.currency ~ '^[A-Z]{3}$'
    union all
    select upper(btrim(u.country)),
           btrim(regexp_replace(t.merchant_name, '\s+', ' ', 'g')),
           upper(btrim(coalesce(t.currency, u.currency))),
           coalesce((select m.family_id::text from public.family_members m where m.user_id = t.user_id limit 1),
                    t.user_id::text),
           'bank'
      from public.zad_transactions t
      join public.zad_users u on u.id = t.user_id
     where t.txn_kind = 'expense'
       and coalesce(t.is_expense, true)
       and t.transfer_to is null
       and t.created_at > now() - interval '60 days'
  ),
  clean as (
    select r.*, public.zad_inventory_name_key(r.store) as store_key
      from raw r
     where r.country ~ '^[A-Z]{2}$'
       and r.currency ~ '^[A-Z]{3}$'
       and char_length(coalesce(r.store, '')) between 2 and 60
  ),
  grouped as (
    select c.country, c.store_key,
           mode() within group (order by c.store) as store,
           mode() within group (order by c.currency) as currency,
           count(distinct c.home)::int as homes,
           count(distinct c.home) filter (where c.origin = 'bank')::int as bank_homes,
           count(*) filter (where c.origin = 'receipt')::int as receipts,
           count(*)::int as seen
      from clean c
     where c.store_key <> ''
     group by c.country, c.store_key
  )
  select g.country, g.store, g.currency, g.homes, g.seen
    from grouped g
   where (g.receipts > 0 or g.bank_homes >= 2)
     and not exists (
       select 1 from public.zad_deals d
        where d.source_kind = 'search' and d.country = g.country and d.store_key = g.store_key
          and d.found_at > now() - interval '6 days'
     )
   order by g.homes desc, g.seen desc, g.store
   limit greatest(0, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function public.zad_deal_search_targets(int) from public, anon, authenticated;
grant execute on function public.zad_deal_search_targets(int) to service_role;

-- الخميس ٣:٤١ UTC: عروض الأسبوع في الخليج ومصر بتنزل الأربع والخميس.
do $cron$
begin
  if to_regnamespace('cron') is null or to_regprocedure('public.zad_cron_secret(text)') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.schedule(
    'deals-search-weekly',
    '41 3 * * 4',
    $job$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"deals_search_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id;
    $job$
  );
end
$cron$;
