-- أسعار من بحث النت بمصدرها — بداية الجمهور قبل ما يبقى فيه جمهور (الموجة ٨، ٢٠٢٦-١٠-١١).
--
-- قرار المالك: «نملي الأسعار قبل الجمهور بفواتير الفريق والعيلة + بحث حي موجّه وموثّق المصدر، من غير سحب
-- عشوائي من المواقع». الفواتير بتوصل price_index (الموجة ٥). البحث: check_price_online بينادي estimate_price في
-- zad-core-intelligence (DuckDuckGo، والموديل بيستخرج الأرقام من المقاطع بس ومعاها روابطها) — كل مرة من الأول،
-- ومن غير ما حاجة تتحفظ.
--
-- zad_web_prices — نفس فكرة zad_medicine_prices (20261011110000): سعر **ليه مصدر** بس، بالبلد والصنف (والمحل
-- لو اتسأل عن محل)، ٧ أيام (البقالة بتتغير أسرع من الدوا). سعر عام مش بيانات عميل: مفيش user_id، للسيرفر بس.
-- ومش من الجمهور: مابيدخلش في أرضية الـ٣ بيوت ولا في «أرخص هنا» — بيتقال بمصدره ومن «بحث النت».

create table if not exists public.zad_web_prices (
  country text not null check (country ~ '^[A-Z]{2}$'),
  name_key text not null check (char_length(name_key) between 2 and 141),
  name text not null check (char_length(name) between 1 and 80),
  store text check (store is null or char_length(store) <= 60),
  price_low numeric not null check (price_low > 0),
  price_high numeric not null,
  currency text not null default '' check (char_length(currency) <= 8),
  sources jsonb not null check (jsonb_typeof(sources) = 'array' and jsonb_array_length(sources) between 1 and 3),
  found_at timestamptz not null default now(),
  primary key (country, name_key),
  constraint zad_web_prices_range check (price_high >= price_low)
);

alter table public.zad_web_prices enable row level security;
revoke all on table public.zad_web_prices from anon, authenticated;
grant all on table public.zad_web_prices to service_role;

comment on table public.zad_web_prices is
  'أسعار من بحث ويب موجّه (estimate_price) بمصادرها، بالبلد والصنف (والمحل)، ٧ أيام. مش من الجمهور. للسيرفر بس.';
