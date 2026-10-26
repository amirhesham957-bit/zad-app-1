-- محلات البداية لكل بلد (ZAD_PLAN ٤.١٦، قرار المالك ٢٦/١٠).
--
-- zad_deal_search_targets كان بيختار بس المحلات اللي العملاء اشتروا منها (فاتورة، أو تاجر دفعله بيتين). المقاس
-- ٢٦/١٠: ٧ محلات كلهم مصر، وصفر محل سعودي — فبحث الخميس كان هيعدّي السعودية كلها. دلوقتي:
--
--   • zad_deal_seed_stores — قايمة المالك لكل بلد (ومعاها كيتا وباقي التطبيقات والسوبرماركت الكبيرة، طلب المالك): السوبرماركت، وتطبيقات التوصيل (صفحاتها وإعلاناتها العامة بس،
--     من غير دخول التطبيق — قرار المالك)، والمتاجر. بتدخل بعد محلات العملاء، ومن غير تكرار لنفس المحل.
--   • zad_deal_search_log — كل محل اتبحث، حتى لو ماطلعش عرض. قبل كده «اتبحث الأسبوع ده» كان بيتعرف من zad_deals
--     بس، فمحل من غير نتايج كان بيرجع في كل نداء وياخد دور غيره.
--   • الكرون كل ١٠ دقايق من ٣:٤١ لـ٥:٥١ UTC يوم الخميس، وبيتنادى بس لو فيه محل مستني. النداء الواحد بيخلص في
--     دقيقتين (٣–١٠ محلات)، فمرة واحدة في الأسبوع ماكانتش هتكفي القايمة.
-- السيرفر بس. رقم الإصدار مش على ساعة مدوّرة عن قصد.

create table if not exists public.zad_deal_seed_stores (
  country text not null check (country ~ '^[A-Z]{2}$'),
  store text not null check (char_length(store) between 2 and 60),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  kind text not null check (kind in ('grocery', 'delivery', 'marketplace')),
  active boolean not null default true,
  primary key (country, store)
);

alter table public.zad_deal_seed_stores enable row level security;
revoke all on public.zad_deal_seed_stores from anon, authenticated;
grant all on public.zad_deal_seed_stores to service_role;

insert into public.zad_deal_seed_stores (country, store, currency, kind) values
  ('SA', 'كيو', 'SAR', 'grocery'),
  ('SA', 'بنده', 'SAR', 'grocery'),
  ('SA', 'العثيم', 'SAR', 'grocery'),
  ('SA', 'لولو', 'SAR', 'grocery'),
  ('SA', 'نعناع', 'SAR', 'delivery'),
  ('SA', 'جاهز', 'SAR', 'delivery'),
  ('SA', 'هنقرستيشن', 'SAR', 'delivery'),
  ('SA', 'تو يو', 'SAR', 'delivery'),
  ('SA', 'نينجا', 'SAR', 'delivery'),
  ('SA', 'نون', 'SAR', 'marketplace'),
  ('SA', 'أمازون السعودية', 'SAR', 'marketplace'),
  ('SA', 'كيتا', 'SAR', 'delivery'),
  ('SA', 'مرسول', 'SAR', 'delivery'),
  ('SA', 'كارفور السعودية', 'SAR', 'grocery'),
  ('SA', 'التميمي', 'SAR', 'grocery'),
  ('SA', 'الدانوب', 'SAR', 'grocery'),
  ('SA', 'بن داود', 'SAR', 'grocery'),
  ('EG', 'كارفور', 'EGP', 'grocery'),
  ('EG', 'خير زمان', 'EGP', 'grocery'),
  ('EG', 'أولاد رجب', 'EGP', 'grocery'),
  ('EG', 'كازيون', 'EGP', 'grocery'),
  ('EG', 'بيم', 'EGP', 'grocery'),
  ('EG', 'سبينيس', 'EGP', 'grocery'),
  ('EG', 'طلبات', 'EGP', 'delivery'),
  ('EG', 'نون', 'EGP', 'marketplace'),
  ('EG', 'أمازون مصر', 'EGP', 'marketplace'),
  ('EG', 'هايبر وان', 'EGP', 'grocery'),
  ('EG', 'مترو ماركت', 'EGP', 'grocery'),
  ('EG', 'أوسكار', 'EGP', 'grocery'),
  ('EG', 'بريدفاست', 'EGP', 'delivery'),
  ('EG', 'رابيت', 'EGP', 'delivery'),
  ('EG', 'إنستاشوب', 'EGP', 'delivery')
on conflict (country, store) do nothing;

create table if not exists public.zad_deal_search_log (
  id bigint generated always as identity primary key,
  country text not null check (country ~ '^[A-Z]{2}$'),
  store_key text not null,
  searched_at timestamptz not null default now(),
  hits int not null default 0,
  put int not null default 0
);

create index if not exists zad_deal_search_log_recent on public.zad_deal_search_log (country, store_key, searched_at desc);

alter table public.zad_deal_search_log enable row level security;
revoke all on public.zad_deal_search_log from anon, authenticated;
grant all on public.zad_deal_search_log to service_role;

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
        where d.source_kind = 'search' and d.country = c.country and d.store_key = c.store_key
          and d.found_at > now() - interval '6 days'
     )
     and not exists (
       select 1 from public.zad_deal_search_log l
        where l.country = c.country and l.store_key = c.store_key
          and l.searched_at > now() - interval '6 days'
     )
   order by c.tier, c.homes desc, c.seen desc, c.country, c.store
   limit greatest(0, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function public.zad_deal_search_targets(int) from public, anon, authenticated;
grant execute on function public.zad_deal_search_targets(int) to service_role;

do $cron$
begin
  if to_regnamespace('cron') is null or to_regprocedure('public.zad_cron_secret(text)') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.schedule(
    'deals-search-weekly',
    '41,51 3 * * 4',
    $job$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"deals_search_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id
    where exists (select 1 from public.zad_deal_search_targets(1));
    $job$
  );
  perform cron.schedule(
    'deals-search-weekly-more',
    '1,11,21,31,41,51 4,5 * * 4',
    $job$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"deals_search_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id
    where exists (select 1 from public.zad_deal_search_targets(1));
    $job$
  );
end
$cron$;
