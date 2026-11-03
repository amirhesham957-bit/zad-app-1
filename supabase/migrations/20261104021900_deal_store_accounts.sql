-- أكونتات المحلات الرسمية على إنستجرام (ZAD_PLAN ٤.١٢، طلب المالك ٤/١١: عروض نينجا وكيتا من أكونتاتهم).
--
-- store_deals_instagram بقى يقرا بوستات أكونت المحل نفسه بـBusiness Discovery الرسمي قبل الهاشتاج. اليوزرنيم
-- بيتلاقي من بحث واحد ويتقبل بس لو Meta قالت إنه أكونت Business وعنده ٢٠ ألف متابع أو أكتر (MIN_STORE_FOLLOWERS)؛
-- username = null يعني «اتدوّر ومالقيناش». الصف بيتقري ٣٠ يوم وبعدها بيتدوّر تاني.
-- مفيش يوزرنيمز مكتوبة باليد هنا عن قصد: تخمين أكونت غلط ممكن يجيب عروض أكونت مقلّد.
-- السيرفر بس. رقم الإصدار مش على ساعة مدوّرة عن قصد.

create table if not exists public.zad_deal_store_accounts (
  country text not null check (country ~ '^[A-Z]{2}$'),
  store text not null check (char_length(store) between 2 and 60),
  platform text not null default 'instagram' check (platform in ('instagram')),
  username text check (username ~ '^[a-z0-9._]{1,30}$'),
  followers integer check (followers >= 0),
  checked_at timestamptz not null default now(),
  primary key (country, store, platform)
);

alter table public.zad_deal_store_accounts enable row level security;
revoke all on public.zad_deal_store_accounts from anon, authenticated;
grant all on public.zad_deal_store_accounts to service_role;
