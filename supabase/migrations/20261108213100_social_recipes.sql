-- ZAD_PLAN ٧.٤ (طلب المالك ٨/١١): الوصفات والعروض من تيك توك عن طريق محرك البحث، من غير طلب لتيك توك.
--   • zad_social_recipes: اسم الأكلة ومكوناتها والمحلات المذكورة ورابط الفيديو. الكاتب social_recipes_run في zad-brain، والقارئ
--     meal_suggestions. مقفول للعميل: السيرفر بس. رابط الفيديو مفتاح، فالفيديو مايتقريش مرتين.
--   • المحلات اللي المالك سماها وكانت ناقصة (بمبر مكتوبة زي ما المالك كتبها، و«بيم» موجودة لوحدها).
--   • كرون مرتين في الأسبوع على ٣ نوبات: كل نوبة تلت المصادر، عشان حد الـ١٥٠ ثانية وكوتة البحث.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

create table if not exists public.zad_social_recipes (
  source_url text primary key check (source_url ~ '^https://' and char_length(source_url) <= 300),
  handle text not null check (char_length(handle) between 1 and 40),
  country text check (country ~ '^[A-Z]{2}$'),
  name text check (char_length(name) between 2 and 80),
  ingredients text[] not null default '{}',
  stores text[] not null default '{}',
  found_at timestamptz not null default now()
);

create index if not exists zad_social_recipes_found_idx on public.zad_social_recipes (found_at desc);

alter table public.zad_social_recipes enable row level security;
revoke all on public.zad_social_recipes from anon, authenticated;
grant all on public.zad_social_recipes to service_role;

insert into public.zad_deal_seed_stores (country, store, currency, kind) values
  ('EG', 'فتح الله', 'EGP', 'grocery'),
  ('EG', 'بمبر', 'EGP', 'grocery'),
  ('EG', 'ميتو', 'EGP', 'delivery'),
  ('EG', 'كلوفر', 'EGP', 'delivery')
on conflict (country, store) do nothing;

select cron.unschedule('social-recipes-twice-weekly') where exists (select 1 from cron.job where jobname = 'social-recipes-twice-weekly');
select cron.schedule('social-recipes-twice-weekly', '7,27,47 11 * * 0,3', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := jsonb_build_object('action', 'social_recipes_run', 'slot', (extract(minute from now())::int / 20)),
        timeout_milliseconds := 150000
      ) as request_id;
    $cron$);
