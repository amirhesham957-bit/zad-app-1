-- موسم العروض: الجمعة البيضاء / البلاك فرايداي (طلب المالك ٤/١١: «العروض كتير، عاوز الإيجنت يرصد ويبعت للعملاء
-- أحسن العروض اللي محتاجينها بالصور واللينكات على البوت»).
--
--   • zad_deal_seasons — مواسم العروض بتاريخها (البلد null = كل البلاد). أول موسم: الجمعة البيضاء ٤/١١ → ٢/١٢.
--   • وقت الموسم: البحث ويوتيوب بيدوّروا كل يوم مش الخميس بس، والمحل بيتبحث تاني بعد ٢٠ ساعة مش ٦ أيام
--     (zad_deal_refresh_interval). إنستجرام الاتنين والخميس بس: حد Meta ٣٠ هاشتاج في الأسبوع.
--     بره الموسم كل حاجة زي ما هي: الخميس، و٦ أيام.
--   • zad_deal_digest_sent — اللي اتبعت لكل عميل في رسالة الموسم (seasonDigest.ts)، عشان نفس العرض مايتبعتش تاني.
--   • كرون deals-season-digest كل يوم ١٦:١٣ UTC (٦:١٣ مسا القاهرة، ٧:١٣ الرياض) — بيتنادى بس وقت الموسم.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

create table if not exists public.zad_deal_seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 40),
  country text check (country ~ '^[A-Z]{2}$'),
  starts_on date not null,
  ends_on date not null check (ends_on >= starts_on),
  refresh_hours int not null default 20 check (refresh_hours between 6 and 144),
  unique (name, starts_on)
);

alter table public.zad_deal_seasons enable row level security;
revoke all on public.zad_deal_seasons from anon, authenticated;
grant all on public.zad_deal_seasons to service_role;

insert into public.zad_deal_seasons (name, country, starts_on, ends_on, refresh_hours)
values ('الجمعة البيضاء', null, date '2026-11-04', date '2026-12-02', 20)
on conflict (name, starts_on) do nothing;

-- الموسم الشغال النهارده لبلد (أو لأي بلد لو null)، باسمه.
create or replace function public.zad_deal_season_name(p_country text default null)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select s.name
    from public.zad_deal_seasons s
   where current_date between s.starts_on and s.ends_on
     and (p_country is null or s.country is null or s.country = upper(p_country))
   order by s.starts_on desc
   limit 1;
$$;

create or replace function public.zad_deal_season_on(p_country text default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.zad_deal_season_name(p_country) is not null;
$$;

-- المحل بيتبحث تاني بعد قد إيه: ٦ أيام، ووقت الموسم ساعات الموسم.
create or replace function public.zad_deal_refresh_interval(p_country text)
returns interval
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select make_interval(hours => s.refresh_hours)
       from public.zad_deal_seasons s
      where current_date between s.starts_on and s.ends_on
        and (s.country is null or s.country = upper(p_country))
      order by s.refresh_hours
      limit 1),
    interval '6 days');
$$;

revoke all on function public.zad_deal_season_name(text) from public, anon, authenticated;
grant execute on function public.zad_deal_season_name(text) to service_role;
revoke all on function public.zad_deal_season_on(text) from public, anon, authenticated;
grant execute on function public.zad_deal_season_on(text) to service_role;
revoke all on function public.zad_deal_refresh_interval(text) from public, anon, authenticated;
grant execute on function public.zad_deal_refresh_interval(text) to service_role;

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
          and d.found_at > now() - public.zad_deal_refresh_interval(c.country)
     )
     and not exists (
       select 1 from public.zad_deal_search_log l
        where l.source = p_source and l.country = c.country and l.city = c.city and l.store_key = c.store_key
          and l.searched_at > now() - public.zad_deal_refresh_interval(c.country)
     )
   order by c.tier, c.homes desc, c.seen desc, c.country, c.store, c.city
   limit greatest(0, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function public.zad_deal_source_targets(int, text) from public, anon, authenticated;
grant execute on function public.zad_deal_source_targets(int, text) to service_role;

create table if not exists public.zad_deal_digest_sent (
  user_id uuid not null references auth.users (id) on delete cascade,
  deal_key text not null check (char_length(deal_key) between 3 and 200),
  sent_at timestamptz not null default now(),
  primary key (user_id, deal_key)
);

alter table public.zad_deal_digest_sent enable row level security;
revoke all on public.zad_deal_digest_sent from anon, authenticated;
grant all on public.zad_deal_digest_sent to service_role;

-- نفس أوامر الكرون بالظبط، والجدول بس اتغيّر: كل يوم، وبيتنادى الخميس أو وقت الموسم.
select cron.schedule('deals-search-weekly', '41,51 3 * * *', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"deals_search_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id
    where (extract(isodow from now()) = 4 or public.zad_deal_season_on())
      and exists (select 1 from public.zad_deal_search_targets(1));
    $cron$);

select cron.schedule('deals-search-weekly-more', '1,11,21,31,41,51 4,5 * * *', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"deals_search_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id
    where (extract(isodow from now()) = 4 or public.zad_deal_season_on())
      and exists (select 1 from public.zad_deal_search_targets(1));
    $cron$);

select cron.schedule('deals-youtube-weekly', '17,27,37,47,57 6,7 * * *', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"deals_youtube_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id
    where (extract(isodow from now()) = 4 or public.zad_deal_season_on())
      and exists (select 1 from public.zad_deal_source_targets(1, 'youtube'));
    $cron$);

select cron.schedule('deals-instagram-weekly', '7,27,47 8,9 * * 1,4', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"deals_instagram_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id
    where (extract(isodow from now()) = 4 or public.zad_deal_season_on())
      and exists (select 1 from public.zad_deal_source_targets(1, 'instagram'));
    $cron$);

select cron.schedule('deals-season-digest', '13 16 * * *', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"deals_season_digest_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id
    where public.zad_deal_season_on();
    $cron$);

