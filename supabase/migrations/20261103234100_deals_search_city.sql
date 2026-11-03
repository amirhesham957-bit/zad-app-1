-- البحث الأسبوعي لكل مدينة (ZAD_PLAN ٤.٣): «عروض كيو الرياض» بدل «عروض كيو السعودية» لما زاد يعرف المدينة.
--
-- الحساب مافيهوش مدينة، والعميل مابيتسألش. المدينة بتتعرف من نقطته التقريبية (zad_users.last_lat/last_lon، مقرّبة
-- لخانتين ≈ ١ كم) بـLocationIQ reverse — نفس المفتاح ونفس المزوّد بتوع nearby_pois — وبتتخزن هنا اسم بس:
--   • zad_user_city — المدينة (عربي لو المزوّد قالها) والبلد اللي هي فيه وإمتى اتعرفت. النقطة نفسها مابتتخزنش هنا
--     أبداً. '' = اتسأل ومالقيناش مدينة، فمايتسألش تاني قبل ٣٠ يوم. السيرفر بس (RLS من غير سياسات): العميل
--     مايقدرش يكتب مدينة بإيده فيدخّل كلام في محرك البحث.
--   • zad_users_needing_city(p_limit) — مين محتاج مدينة: نقطة عمرها أقل من أسبوع، مش مسافر، ومدينته مش معروفة أو
--     أقدم من ٣٠ يوم أو من بلد تاني. بترجع النقطة مقرّبة بس.
--   • zad_deal_search_log.city — «اتبحث الأسبوع ده» بقى لكل (محل، مدينة).
--   • zad_deal_source_targets بترجع city (آخر عمود). للبحث بس ('search'): التجميع بقى (بلد، مدينة، محل)، والمدينة
--     '' فضلت للعملاء اللي مدينتهم مش معروفة. محلات البداية (zad_deal_seed_stores) بتتبحث في البلد كله زي الأول،
--     وفي كل مدينة فيها بيتين أو أكتر — بيت واحد في مدينة بيتخدم من بحث البلد، وده بيحافظ على السقف. يوتيوب
--     وإنستجرام زي ما هم: البلد كله (city = '').
-- بحث واحد لكل (محل، مدينة) بيخدم كل عملاء المدينة. السيرفر بس. رقم الإصدار مش على ساعة مدوّرة عن قصد.

create table if not exists public.zad_user_city (
  user_id uuid primary key references public.zad_users(id) on delete cascade,
  country text not null check (country ~ '^[A-Z]{2}$'),
  city text not null default '' check (char_length(city) <= 60),
  found_at timestamptz not null default now()
);

alter table public.zad_user_city enable row level security;
revoke all on public.zad_user_city from anon, authenticated;
grant all on public.zad_user_city to service_role;

comment on table public.zad_user_city is
  'The city of a customer''s coarse point (LocationIQ reverse, ZAD_PLAN 4.3): a name and when it was found, never the point. '
  'An empty city = asked and none found. Server only.';

create or replace function public.zad_users_needing_city(p_limit int default 10)
returns table (user_id uuid, country text, lat double precision, lon double precision)
language sql
stable
security definer
set search_path to 'public'
as $$
  select u.id, upper(btrim(u.country)),
         round(u.last_lat::numeric, 2)::double precision, round(u.last_lon::numeric, 2)::double precision
    from public.zad_users u
    left join public.zad_user_city c on c.user_id = u.id
   where upper(btrim(coalesce(u.country, ''))) ~ '^[A-Z]{2}$'
     and u.last_lat is not null and u.last_lon is not null
     and u.last_location_at > now() - interval '7 days'
     and u.travel_country is null
     and (c.user_id is null
          or c.found_at < now() - interval '30 days'
          or c.country <> upper(btrim(u.country)))
   order by c.found_at nulls first, u.last_location_at desc
   limit greatest(0, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function public.zad_users_needing_city(int) from public, anon, authenticated;
grant execute on function public.zad_users_needing_city(int) to service_role;

alter table public.zad_deal_search_log add column if not exists city text not null default '';
create index if not exists zad_deal_search_log_recent_city
  on public.zad_deal_search_log (country, city, store_key, searched_at desc);

-- عمود جديد في الرجوع ⇒ لازم drop. الكرونات بتنادي بالاسم بس، فبتلاقيها بعد ما تتعمل تاني.
drop function if exists public.zad_deal_search_targets(int);
drop function if exists public.zad_deal_source_targets(int, text);

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
  select c.country, c.store, c.currency, c.homes, c.seen, c.city
    from candidates c
   where not exists (
       select 1 from public.zad_deals d
        where d.source_kind = p_source and d.country = c.country and d.city = c.city and d.store_key = c.store_key
          and d.found_at > now() - interval '6 days'
     )
     and not exists (
       select 1 from public.zad_deal_search_log l
        where l.source = p_source and l.country = c.country and l.city = c.city and l.store_key = c.store_key
          and l.searched_at > now() - interval '6 days'
     )
   order by c.tier, c.homes desc, c.seen desc, c.country, c.store, c.city
   limit greatest(0, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function public.zad_deal_source_targets(int, text) from public, anon, authenticated;
grant execute on function public.zad_deal_source_targets(int, text) to service_role;

create or replace function public.zad_deal_search_targets(p_limit int default 10)
returns table (country text, store text, currency text, homes int, seen int, city text)
language sql
stable
security definer
set search_path to 'public'
as $$
  select * from public.zad_deal_source_targets(p_limit, 'search');
$$;
revoke all on function public.zad_deal_search_targets(int) from public, anon, authenticated;
grant execute on function public.zad_deal_search_targets(int) to service_role;
