-- أكواد الخصم من السوشيال، ومحلات أكتر (ZAD_PLAN ٤.٢٢، طلب المالك ٤/١١).
--
-- zad_deals لازم فيه صنف وسعر، فبوست «خصم ٣٠٪ بالكود X» من كيتا أو نينجا كان بيترمي كله — يعني تطبيقات التوصيل
-- مالهاش عروض خالص من إنستجرام ويوتيوب. zad_deal_codes بيشيل الكود لوحده: المحل، الكود حرف بحرف زي ما اتكتب في
-- البوست أو الفيديو، الخصم (نسبة أو مبلغ)، أقل طلب، والمصدر برابطه. بيتكتب من zad-brain بس (service role)،
-- ومفيش قراية من التطبيق: الكود بيوصل للعميل في رسالة الصبح لو المحل من محلاته (zad-brain بيقرر).
--
-- محلات جديدة في القايمة: هايبرات سعودية ومصرية معروفة بالعروض، وتطبيقات أكل. الأكونت الرسمي بيتلاقي لوحده بنفس
-- قاعدة ٤.١٢ (Business و٢٠ ألف متابع أو أكتر)، فاسم غلط هنا بيطلع «مالوش» مش عروض مقلّدة.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

create table if not exists public.zad_deal_codes (
  id uuid primary key default gen_random_uuid(),
  country text not null check (country ~ '^[A-Z]{2}$'),
  store text not null check (char_length(store) between 2 and 60),
  store_key text not null check (char_length(store_key) between 1 and 60),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{2,23}$'),
  discount_percent numeric check (discount_percent > 0 and discount_percent <= 90),
  discount_amount numeric check (discount_amount > 0),
  currency text check (currency ~ '^[A-Z]{3}$'),
  min_order numeric check (min_order > 0),
  valid_until timestamptz,
  source_kind text not null check (source_kind in ('instagram', 'youtube', 'tiktok', 'facebook')),
  source_url text not null check (source_url ~ '^https://' and char_length(source_url) <= 500),
  found_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (discount_percent is not null or discount_amount is not null),
  unique (country, store_key, code)
);

create index if not exists zad_deal_codes_live_idx on public.zad_deal_codes (country, expires_at);

alter table public.zad_deal_codes enable row level security;
revoke all on public.zad_deal_codes from anon, authenticated;
grant all on public.zad_deal_codes to service_role;

insert into public.zad_deal_seed_stores (country, store, currency, kind) values
  ('SA', 'نستو', 'SAR', 'grocery'),
  ('SA', 'أسواق المزرعة', 'SAR', 'grocery'),
  ('SA', 'أسواق رامز', 'SAR', 'grocery'),
  ('SA', 'أسواق الراية', 'SAR', 'grocery'),
  ('SA', 'ذا شفز', 'SAR', 'delivery'),
  ('EG', 'زهران ماركت', 'EGP', 'grocery'),
  ('EG', 'سعودي ماركت', 'EGP', 'grocery'),
  ('EG', 'إلمنيوز', 'EGP', 'delivery')
on conflict (country, store) do nothing;
