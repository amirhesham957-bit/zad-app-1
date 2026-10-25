-- جدول العروض zad_deals (ZAD_PLAN ٤.١) وأول مصدر ليه: فواتير العملاء (٤.٢).
--
-- المرحلة ٤ عايزة زاد يقول «الزيت اللي ناقصك أرخص في كيو اللي جنبك»، وده محتاج مكان واحد فيه السعر بمحله
-- وبلده ومدينته ومصدره وتاريخه. الأسعار اللي عندنا متفرقة: price_index (فواتير وبلاغات العملاء، بصاحبها)،
-- وzad_web_prices (بحث النت، من غير محل غالباً ولا فرع). zad_deals هو اللي الترشيح (٤.٨) هيقرا منه.
--
-- قرارات:
--   • مفيش user_id في الجدول. القراية لكل عملاء نفس البلد (RLS)، فأي صف فيه هو سعر عام بالضرورة. سعر
--     العميل نفسه بيفضل في price_index وبيشوفه هو على طول من هناك.
--   • الفواتير بتدخل بس بأرضية الجمهور (crowdFloor.ts و20261011250000): نفس الصنف في نفس المحل في نفس
--     المدينة من ٣ بيوت مختلفة آخر ٧ أيام، بعد شيل الشاذ، والسعر = الوسيط مش سعر بيت بعينه.
--   • الكتابة من السيرفر بس: zad_deal_put للمصادر الجاية (البحث ٤.٣، النشرات ٤.٤، الشراكات ٤.٥، يوتيوب
--     ٤.١١، إنستجرام ٤.١٢، الإيميل ٤.١٣)، وzad_deals_from_receipts للفواتير. مفيش كتابة من التطبيق.
--   • كل صف بيخلص لوحده: expires_at = آخر يوم العرض لو معروف، وإلا ٧ أيام من ما اتلاقى. كرون يومي بيمسح
--     اللي خلص وبيعيد نشر الفواتير.
--   • الفرع: place_id من Google Places لما المصدر يعرفه (٤.٧)، وإلا '' = المحل في المدينة كلها.
--
-- المقاس ٢٥/١٠ (من خطة ٢٤/١٠): price_index ٢٨ صف كلهم لبيت واحد، فالفواتير هتنشر صفر لحد ما ٣ بيوت
-- يشتروا من نفس المحل (المرحلة ٦). البحث واقف على ٣.٩. الجدول بيتملا لما المصادر تشتغل.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

create table if not exists public.zad_deals (
  id uuid primary key default gen_random_uuid(),
  country text not null check (country ~ '^[A-Z]{2}$'),
  city text not null default '' check (char_length(city) <= 60),
  store text not null check (char_length(store) between 1 and 60),
  store_key text generated always as (public.zad_inventory_name_key(store)) stored,
  place_id text not null default '' check (char_length(place_id) <= 255),
  lat double precision check (lat is null or lat between -90 and 90),
  lng double precision check (lng is null or lng between -180 and 180),
  item_name text not null check (char_length(item_name) between 2 and 80),
  item_key text generated always as (public.zad_inventory_name_key(item_name)) stored,
  price numeric not null check (price > 0 and price <= 1000000),
  price_before numeric check (price_before is null or price_before > price),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  unit text check (unit is null or char_length(unit) <= 20),
  size numeric check (size is null or size > 0),
  deal_kind text not null default 'price'
    check (deal_kind in ('price', 'discount', 'multi_buy', 'bundle', 'other')),
  valid_from timestamptz,
  valid_until timestamptz,
  source_kind text not null
    check (source_kind in ('receipt', 'search', 'flyer', 'partner', 'youtube', 'instagram', 'email')),
  source_url text check (source_url is null or (source_url ~ '^https://' and char_length(source_url) <= 500)),
  confidence numeric not null check (confidence between 0 and 1),
  homes int check (homes is null or homes >= 3),
  found_at timestamptz not null default now(),
  expires_at timestamptz not null,
  constraint zad_deals_window check (valid_until is null or valid_from is null or valid_until > valid_from),
  constraint zad_deals_receipt_floor check ((source_kind = 'receipt') = (homes is not null)),
  constraint zad_deals_sourced check (source_kind = 'receipt' or source_url is not null)
);

create unique index if not exists zad_deals_one_per_source
  on public.zad_deals (country, city, store_key, place_id, item_key, source_kind);
create index if not exists zad_deals_country_item on public.zad_deals (country, item_key);
create index if not exists zad_deals_expires on public.zad_deals (expires_at);

alter table public.zad_deals enable row level security;
revoke all on table public.zad_deals from anon, authenticated;
grant select on table public.zad_deals to authenticated;
grant all on table public.zad_deals to service_role;

drop policy if exists zad_deals_same_country on public.zad_deals;
create policy zad_deals_same_country on public.zad_deals for select to authenticated
  using (
    expires_at > now()
    and country = (select upper(u.country) from public.zad_users u where u.id = (select auth.uid()))
  );

comment on table public.zad_deals is
  'Prices and offers by store, city and country, each with its source and date (ZAD_PLAN 4.1). No customer data: '
  'receipts enter only as the median of 3+ homes (zad_deals_from_receipts). Written by the server only.';

/**
 * باب الكتابة للمصادر (٤.٣ وبعده). صف واحد لكل محل/فرع/صنف/مصدر: نفس المصدر بيحدّث صفه. بيرجع
 * {ok, id} أو {ok:false, reason}. اللي تاريخه خلص مابيدخلش.
 */
create or replace function public.zad_deal_put(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_until timestamptz := nullif(p ->> 'valid_until', '')::timestamptz;
  v_id uuid;
begin
  if coalesce(p ->> 'source_kind', '') = 'receipt' then
    return jsonb_build_object('ok', false, 'reason', 'receipts_go_through_the_floor');
  end if;
  if v_until is not null and v_until <= now() then
    return jsonb_build_object('ok', false, 'reason', 'already_over');
  end if;

  insert into public.zad_deals as d
    (country, city, store, place_id, lat, lng, item_name, price, price_before, currency, unit, size,
     deal_kind, valid_from, valid_until, source_kind, source_url, confidence, found_at, expires_at)
  values (
    upper(btrim(p ->> 'country')),
    coalesce(btrim(p ->> 'city'), ''),
    btrim(p ->> 'store'),
    coalesce(btrim(p ->> 'place_id'), ''),
    (p ->> 'lat')::double precision,
    (p ->> 'lng')::double precision,
    btrim(regexp_replace(p ->> 'item_name', '\s+', ' ', 'g')),
    (p ->> 'price')::numeric,
    (p ->> 'price_before')::numeric,
    upper(btrim(p ->> 'currency')),
    nullif(btrim(p ->> 'unit'), ''),
    (p ->> 'size')::numeric,
    coalesce(p ->> 'deal_kind', 'price'),
    nullif(p ->> 'valid_from', '')::timestamptz,
    v_until,
    p ->> 'source_kind',
    p ->> 'source_url',
    (p ->> 'confidence')::numeric,
    now(),
    coalesce(v_until, now() + interval '7 days')
  )
  on conflict (country, city, store_key, place_id, item_key, source_kind) do update
    set store = excluded.store, lat = excluded.lat, lng = excluded.lng, item_name = excluded.item_name,
        price = excluded.price, price_before = excluded.price_before, currency = excluded.currency,
        unit = excluded.unit, size = excluded.size, deal_kind = excluded.deal_kind,
        valid_from = excluded.valid_from, valid_until = excluded.valid_until,
        source_url = excluded.source_url, confidence = excluded.confidence,
        found_at = excluded.found_at, expires_at = excluded.expires_at
  returning d.id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id);
exception
  when check_violation or not_null_violation or invalid_text_representation
    or invalid_datetime_format or datetime_field_overflow or numeric_value_out_of_range then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input', 'detail', sqlerrm);
end;
$$;

revoke all on function public.zad_deal_put(jsonb) from public, anon, authenticated;
grant execute on function public.zad_deal_put(jsonb) to service_role;

/**
 * الفواتير ⇐ zad_deals بأرضية الجمهور. لكل بلد/مدينة/محل/صنف في price_index (crowdsource، آخر ٧ أيام):
 * الشاذ بيتشال (أكتر من ٣ أضعاف الوسيط أو أقل من تلته)، ولو اللي فاضل من ٣ بيوت مختلفة على الأقل (العيلة
 * بيت واحد) بيتنشر الوسيط. البلد من حساب المبلّغ، والعملة لازم تكون واحدة في المجموعة. اللي ماعدّاش الأرضية
 * النهارده بيتمسح من الجدول. بيرجع عدد الصفوف المنشورة.
 */
create or replace function public.zad_deals_from_receipts()
returns int
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_n int;
begin
  create temporary table if not exists pg_temp.receipt_deals (
    country text, city text, store text, item_name text, price numeric, currency text, homes int, found_at timestamptz
  ) on commit drop;
  truncate pg_temp.receipt_deals;

  insert into pg_temp.receipt_deals
  with recent as (
    select upper(btrim(u.country)) as country,
           coalesce(btrim(p.location), '') as city,
           btrim(p.store_name) as store,
           public.zad_inventory_name_key(p.store_name) as store_key,
           btrim(regexp_replace(p.item_name, '\s+', ' ', 'g')) as item_name,
           public.zad_inventory_name_key(p.item_name) as item_key,
           p.price::numeric as price, p.currency, p."timestamp" as reported_at,
           coalesce((select m.family_id::text from public.family_members m where m.user_id = p.user_id limit 1),
                    p.user_id::text) as home
      from public.price_index p
      join public.zad_users u on u.id = p.user_id
     where p.source = 'crowdsource'
       and p.price > 0
       and p.user_id is not null
       and nullif(btrim(p.store_name), '') is not null
       and char_length(btrim(p.item_name)) between 2 and 80
       and upper(btrim(coalesce(u.country, ''))) ~ '^[A-Z]{2}$'
       and p.currency ~ '^[A-Z]{3}$'
       and p."timestamp" > now() - interval '7 days'
  ),
  medians as (
    select country, city, store_key, item_key, percentile_cont(0.5) within group (order by price) as median
      from recent group by 1, 2, 3, 4
  ),
  kept as (
    select r.* from recent r join medians m using (country, city, store_key, item_key)
     where r.price <= m.median * 3 and r.price >= m.median / 3
  )
  select country, city,
         (array_agg(store order by reported_at desc))[1],
         (array_agg(item_name order by reported_at desc))[1],
         round((percentile_cont(0.5) within group (order by price))::numeric, 2),
         min(currency),
         count(distinct home)::int,
         max(reported_at)
    from kept
   group by country, city, store_key, item_key
  having count(distinct home) >= 3 and count(distinct currency) = 1;

  delete from public.zad_deals d
   where d.source_kind = 'receipt'
     and not exists (
       select 1 from pg_temp.receipt_deals r
        where r.country = d.country and r.city = d.city
          and public.zad_inventory_name_key(r.store) = d.store_key
          and public.zad_inventory_name_key(r.item_name) = d.item_key
     );

  insert into public.zad_deals as d
    (country, city, store, item_name, price, currency, source_kind, confidence, homes, found_at, expires_at)
  select country, city, store, item_name, price, currency, 'receipt',
         least(1, homes / 5.0), homes, found_at, found_at + interval '7 days'
    from pg_temp.receipt_deals
  on conflict (country, city, store_key, place_id, item_key, source_kind) do update
    set store = excluded.store, item_name = excluded.item_name, price = excluded.price,
        currency = excluded.currency, confidence = excluded.confidence, homes = excluded.homes,
        found_at = excluded.found_at, expires_at = excluded.expires_at;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke all on function public.zad_deals_from_receipts() from public, anon, authenticated;
grant execute on function public.zad_deals_from_receipts() to service_role;

do $cron$
begin
  if to_regnamespace('cron') is null then
    return; -- قاعدة سكراتش للاختبار
  end if;
  perform cron.schedule(
    'deals-daily',
    '23 2 * * *',
    $job$
  delete from public.zad_deals where expires_at < now();
  select public.zad_deals_from_receipts();
    $job$
  );
end
$cron$;
