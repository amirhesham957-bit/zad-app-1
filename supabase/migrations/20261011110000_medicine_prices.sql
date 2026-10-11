-- أسعار الأدوية: بحث حي موجّه + حفظ النتيجة (الموجة ٤ من «خطة سد فجوات زاد»، قرار المالك ٢٠٢٦-١٠-١٠).
--
-- مفيش سحب من مواقع الأدوية لحد ما شروطها تتراجع. zad-brain بيدوّر بـestimate_price (بحث ويب + استخراج أرقام
-- من المقاطع بس ومعاها روابطها) وبيحفظ هنا السعر اللي **ليه مصدر** — بالبلد واسم الدوا المتطبّع، ٣٠ يوم.
-- سعر عام مش بيانات عميل: مفيش user_id. للسيرفر بس (RLS من غير policies، ومن غير صلاحيات للعملاء).

create table if not exists public.zad_medicine_prices (
  country text not null check (country ~ '^[A-Z]{2}$'),
  name_key text not null check (char_length(name_key) between 2 and 80),
  name text not null check (char_length(name) between 1 and 80),
  price_low numeric not null check (price_low > 0),
  price_high numeric not null,
  currency text not null default '' check (char_length(currency) <= 8),
  sources jsonb not null check (jsonb_typeof(sources) = 'array' and jsonb_array_length(sources) between 1 and 3),
  found_at timestamptz not null default now(),
  primary key (country, name_key),
  constraint zad_medicine_prices_range check (price_high >= price_low)
);

alter table public.zad_medicine_prices enable row level security;
revoke all on table public.zad_medicine_prices from anon, authenticated;

comment on table public.zad_medicine_prices is
  'أسعار أدوية من بحث ويب موجّه (estimate_price) بمصادرها، بالبلد واسم الدوا المتطبّع، ٣٠ يوم. مفيش سحب مواقع. للسيرفر بس.';
