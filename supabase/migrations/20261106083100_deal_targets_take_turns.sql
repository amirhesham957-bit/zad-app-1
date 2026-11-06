-- البلاد بتتبادل الدور في محلات يوتيوب وإنستجرام والبحث (مراجعة ٦/١١، طلب المالك).
--
-- الترتيب كان «tier، البيوت، المرات، **البلد**، المحل»، ومن غير عملاء لسه كل المحلات صفر بيوت ⇐ الترتيب بقى أبجدي بالبلد:
-- AE ثم EG ثم QA ثم SA. كل جري بيوصل لسقفه قبل السعودية، فآخر ٤ أيام: يوتيوب السعودية صفر جري، وإنستجرام السعودية صفر
-- (كيتا ونينجا وبنده والعثيم وكيو موجودين في القايمة ومااتدوّرش عليهم). دلوقتي المحل الأول في كل بلد، بعده التاني في كل بلد…
-- باقي الدالة زي الحي بالظبط (20261104234500).

create or replace function public.zad_deal_source_targets(p_limit int default 10, p_source text default 'search')
returns table (country text, store text, currency text, homes int, seen int, city text)
language sql
stable
security definer
set search_path to 'public'
as $$
  with homes_of as (
    select u.id as user_id,
           upper(btrim(u.country)) as country,
           -- المدينة للبحث بس، ولازم تكون في بلد الحساب. غير كده '' = البلد كله.
           case when p_source = 'search'
                then coalesce((select c.city from public.zad_user_city c
                                where c.user_id = u.id and c.country = upper(btrim(u.country))), '')
                else '' end as city,
           u.currency,
           coalesce((select m.family_id::text from public.family_members m where m.user_id = u.id limit 1),
                    u.id::text) as home
      from public.zad_users u
  ),
  raw as (
    select h.country, h.city,
           btrim(regexp_replace(p.store_name, '\s+', ' ', 'g')) as store,
           upper(btrim(p.currency)) as currency,
           h.home,
           'receipt' as origin
      from public.price_index p
      join homes_of h on h.user_id = p.user_id
     where p.source = 'crowdsource'
       and p."timestamp" > now() - interval '60 days'
       and p.currency ~ '^[A-Z]{3}$'
    union all
    select h.country, h.city,
           btrim(regexp_replace(t.merchant_name, '\s+', ' ', 'g')),
           upper(btrim(coalesce(t.currency, h.currency))),
           h.home,
           'bank'
      from public.zad_transactions t
      join homes_of h on h.user_id = t.user_id
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
    select c.country, c.city, c.store_key,
           mode() within group (order by c.store) as store,
           mode() within group (order by c.currency) as currency,
           count(distinct c.home)::int as homes,
           count(*) filter (where c.origin = 'receipt')::int as receipts,
           count(*)::int as seen
      from clean c
     where c.store_key <> ''
     group by c.country, c.city, c.store_key
  ),
  -- «بيتين دفعوله» بيتعد في البلد كله زي الأول: تاجر دفعله بيت في الرياض وبيت في جدة محل، مش شخص.
  bank_by_country as (
    select c.country, c.store_key, count(distinct c.home)::int as bank_homes
      from clean c
     where c.origin = 'bank'
     group by c.country, c.store_key
  ),
  customers as (
    select g.country, g.city, g.store_key, g.store, g.currency, g.homes, g.seen, 0 as tier
      from grouped g
      left join bank_by_country b on b.country = g.country and b.store_key = g.store_key
     where g.receipts > 0 or coalesce(b.bank_homes, 0) >= 2
  ),
  -- المدن اللي فيها بيتين أو أكتر — محلات البداية بتتبحث فيها، وفي البلد كله ('') دايماً.
  cities as (
    select h.country, h.city, count(distinct h.home)::int as homes
      from homes_of h
     where h.city <> ''
     group by h.country, h.city
    having count(distinct h.home) >= 2
    union all
    select distinct s.country, '' as city, 0 as homes from public.zad_deal_seed_stores s
  ),
  seeds as (
    select s.country, k.city, public.zad_inventory_name_key(s.store) as store_key, s.store, s.currency,
           k.homes, 0 as seen, 1 as tier
      from public.zad_deal_seed_stores s
      join cities k on k.country = s.country
     where s.active
  ),
  candidates as (
    select distinct on (x.country, x.city, x.store_key) x.*
      from (select * from customers union all select * from seeds) x
     order by x.country, x.city, x.store_key, x.tier
  )
  , due as (
  select c.*,
         -- دور المحل جوه بلده: الأول في كل بلد، بعده التاني في كل بلد… عشان البلاد تتبادل.
         row_number() over (partition by c.tier, c.country order by c.homes desc, c.seen desc, c.store, c.city) as turn
    from candidates c
   where not exists (
       select 1 from public.zad_deals d
        where d.source_kind = p_source and d.country = c.country and d.city = c.city and d.store_key = c.store_key
          and d.found_at > now() - public.zad_deal_refresh_interval(c.country)
     )
     and not exists (
       select 1 from public.zad_deal_search_log l
        where l.source = p_source and l.country = c.country and l.city = c.city and l.store_key = c.store_key
          and l.searched_at > now() - public.zad_deal_refresh_interval(c.country)
     )
  )
  select d.country, d.store, d.currency, d.homes, d.seen, d.city
    from due d
   order by d.tier, d.turn, d.homes desc, d.country, d.store, d.city
   limit greatest(0, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function public.zad_deal_source_targets(int, text) from public, anon, authenticated;
grant execute on function public.zad_deal_source_targets(int, text) to service_role;
