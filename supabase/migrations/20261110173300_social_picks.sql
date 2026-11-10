-- ترشيحات تيك توك وإنستجرام من غير سعر (طلب المالك ١٠/١١: «يرشحهم عادي بدون رقم طالما حديث ومحقق مشاهدات»).
--
-- zad_deals بيشترط سعر أكبر من صفر، فالفيديو أو البوست اللي فيه «خصم ٣٠٪» أو مطعم أو وصفة كان بيتقري وبيترمي:
-- ١٠/١١ ١٢ تشغيلة تيك توك وإنستجرام طلّعت `put: 0`. هنا بيتخزن الترشيح نفسه برابطه: نوعه، عنوانه، ملخصه، ونسبة الخصم
-- لو مكتوبة. الكاتب zad-brain (deals_tiktok_run / deals_instagram_run)، والقارئ البوت والشات (find_deals). مقفول للعميل:
-- السيرفر بس، زي zad_social_recipes. الرابط مفتاح، فنفس البوست مايتكررش. بيخلص بعد أسبوعين.

create table if not exists public.zad_social_picks (
  source_url text primary key check (source_url ~ '^https://' and char_length(source_url) <= 300),
  platform text not null check (platform in ('tiktok', 'instagram', 'youtube')),
  kind text not null check (kind in ('offer', 'recipe', 'idea', 'restaurant', 'supermarket', 'delivery')),
  country text not null check (country ~ '^[A-Z]{2}$'),
  store text check (char_length(store) between 1 and 60),
  store_key text check (char_length(store_key) <= 80),
  title text not null check (char_length(title) between 3 and 60),
  summary text not null default '' check (char_length(summary) <= 200),
  discount_percent int check (discount_percent between 1 and 90),
  likes int check (likes >= 0),
  posted_at timestamptz,
  found_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '14 days'
);

create index if not exists zad_social_picks_country_idx on public.zad_social_picks (country, expires_at desc);
create index if not exists zad_social_picks_store_idx on public.zad_social_picks (country, store_key);

alter table public.zad_social_picks enable row level security;
revoke all on public.zad_social_picks from anon, authenticated;
grant all on public.zad_social_picks to service_role;
