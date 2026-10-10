-- الطقس من Open-Meteo (الموجة ٤ من «خطة سد فجوات زاد»، قرار المالك ٢٠٢٦-١٠-١٠: مجاني ومن غير مفتاح).
--
-- كاش التوقعات بمفتاح **المكان** مش العميل: `lat,lon` مقرّبين لـ٢ رقم عشري (~١ كم) لتوقعات ٤ أيام، و`city:<بلد>:<اسم>`
-- لإحداثيات مدينة اتعملها geocoding مرة. مفيش user_id ولا أي بيانات عميل. zad-brain بيقرا ويكتب بمفتاح الخدمة؛
-- التطبيق مالوش دعوة بيه، فـRLS شغال ومفيش ولا policy، والصلاحيات متشالة من anon وauthenticated.

create table if not exists public.zad_weather_cache (
  place_key text primary key check (char_length(place_key) between 3 and 120),
  label text not null check (char_length(label) between 1 and 80),
  lat double precision not null check (lat between -90 and 90),
  lon double precision not null check (lon between -180 and 180),
  days jsonb not null default '[]'::jsonb check (jsonb_typeof(days) = 'array'),
  fetched_at timestamptz not null default now()
);

alter table public.zad_weather_cache enable row level security;
revoke all on table public.zad_weather_cache from anon, authenticated;

comment on table public.zad_weather_cache is
  'كاش Open-Meteo بمفتاح المكان (مش العميل): توقعات ٤ أيام لـlat,lon مقرّبين، وإحداثيات المدن (city:<بلد>:<اسم>). للسيرفر بس.';
