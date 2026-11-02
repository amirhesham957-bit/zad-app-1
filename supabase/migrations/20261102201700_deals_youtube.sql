-- يوتيوب مصدر عروض أسبوعي لوحده (ZAD_PLAN ٤.١١): نفس المحلات اللي البحث بيدوّر عليها، بس كل مصدر ليه أسبوعه.
--
-- zad_deal_search_targets كانت بتشيل المحل لو اتبحث الأسبوع ده في البحث، فيوتيوب بعدها يوم الخميس كان هيلاقي صفر محل.
--   • zad_deal_search_log.source — المصدر اللي اتبحث ('search' أو 'youtube')؛ الصفوف القديمة كلها بحث.
--   • zad_deal_source_targets(p_limit, p_source) — الجسم نفسه، بالمصدر. zad_deal_search_targets(p_limit) بقت غلاف بـ'search'،
--     فالبحث والكرون واختباراته مااتغيروش.
--   • deals-youtube-weekly — الخميس ٦–٧ الصبح UTC بعد البحث، كل ١٠ دقايق لحد ما المحلات تخلص (٣ محلات في النداء: قراية
--     الفيديو أبطأ من نتايج البحث).
-- السيرفر بس. رقم الإصدار مش على ساعة مدوّرة عن قصد.

alter table public.zad_deal_search_log add column if not exists source text not null default 'search';
alter table public.zad_deal_search_log drop constraint if exists zad_deal_search_log_source_check;
alter table public.zad_deal_search_log add constraint zad_deal_search_log_source_check check (source in ('search', 'youtube'));

create or replace function public.zad_deal_source_targets(p_limit int default 10, p_source text default 'search')
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
  ),
  customers as (
    select g.country, g.store_key, g.store, g.currency, g.homes, g.seen, 0 as tier
      from grouped g
     where g.receipts > 0 or g.bank_homes >= 2
  ),
  seeds as (
    select s.country, public.zad_inventory_name_key(s.store) as store_key, s.store, s.currency, 0 as homes, 0 as seen, 1 as tier
      from public.zad_deal_seed_stores s
     where s.active
  ),
  candidates as (
    select distinct on (x.country, x.store_key) x.*
      from (select * from customers union all select * from seeds) x
     order by x.country, x.store_key, x.tier
  )
  select c.country, c.store, c.currency, c.homes, c.seen
    from candidates c
   where not exists (
       select 1 from public.zad_deals d
        where d.source_kind = p_source and d.country = c.country and d.store_key = c.store_key
          and d.found_at > now() - interval '6 days'
     )
     and not exists (
       select 1 from public.zad_deal_search_log l
        where l.source = p_source and l.country = c.country and l.store_key = c.store_key
          and l.searched_at > now() - interval '6 days'
     )
   order by c.tier, c.homes desc, c.seen desc, c.country, c.store
   limit greatest(0, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function public.zad_deal_source_targets(int, text) from public, anon, authenticated;
grant execute on function public.zad_deal_source_targets(int, text) to service_role;

create or replace function public.zad_deal_search_targets(p_limit int default 10)
returns table (country text, store text, currency text, homes int, seen int)
language sql
stable
security definer
set search_path to 'public'
as $$
  select * from public.zad_deal_source_targets(p_limit, 'search');
$$;
revoke all on function public.zad_deal_search_targets(int) from public, anon, authenticated;
grant execute on function public.zad_deal_search_targets(int) to service_role;

do $cron$
begin
  if to_regnamespace('cron') is null or to_regprocedure('public.zad_cron_secret(text)') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.schedule(
    'deals-youtube-weekly',
    '17,27,37,47,57 6,7 * * 4',
    $job$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"deals_youtube_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id
    where exists (select 1 from public.zad_deal_source_targets(1, 'youtube'));
    $job$
  );
end
$cron$;
