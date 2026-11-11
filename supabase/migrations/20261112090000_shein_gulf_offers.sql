-- عروض SHEIN للخليج (SA، AE) — المالك ١١/١١. مصر فاضلة على أمازون.
--
-- الرابط اللي بيتخزن هو رابط لوحة SHEIN نفسه (onelink.shein.com): النسبة جواه، ومفيش باراميتر
-- بنزوّده على رابط منتج عادي بيكسب حاجة (shein-link-converter/shein.ts). الـCHECK بيقفل ده على مستوى
-- الداتابيز، حتى لو حد كتب صف من محرر SQL.
--
-- الكتابة من service_role بس (shein-link-converter، بعد ما يتأكد إن صفحة الرابط شايلة koc_id بتاعنا)،
-- والقراية للمسجّلين، العروض الشغالة بس.

create table if not exists public.zad_affiliate_offers (
  id uuid primary key default gen_random_uuid(),
  network text not null default 'shein' check (network = 'shein'),
  title text not null check (char_length(title) between 1 and 120),
  image_url text check (image_url is null or image_url ~ '^https://'),
  raw_url text check (raw_url is null or raw_url ~ '^https://([a-z0-9-]+\.)*shein\.com/'),
  affiliate_url text not null unique
    check (affiliate_url ~ '^https://onelink\.shein\.com/[0-9]+/[A-Za-z0-9]+/?(\?|$)'),
  koc_id text not null check (koc_id ~ '^[0-9]{4,20}$'),
  -- كود خصم للمشتري بس. كود إحالة المالك مش خصم ومابيتخزنش هنا.
  coupon_code text check (coupon_code is null or coupon_code ~ '^[A-Z0-9-]{3,20}$'),
  target_countries text[] not null default array['SA', 'AE']
    check (cardinality(target_countries) > 0 and target_countries <@ array['SA', 'AE']),
  category text not null default 'fashion_home',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists zad_affiliate_offers_active_idx
  on public.zad_affiliate_offers (created_at desc) where is_active;

alter table public.zad_affiliate_offers enable row level security;

drop policy if exists zad_affiliate_offers_read on public.zad_affiliate_offers;
create policy zad_affiliate_offers_read on public.zad_affiliate_offers
  for select to authenticated using (is_active);

revoke all on public.zad_affiliate_offers from anon;
revoke insert, update, delete on public.zad_affiliate_offers from authenticated;
grant select on public.zad_affiliate_offers to authenticated;
grant all on public.zad_affiliate_offers to service_role;
