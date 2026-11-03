-- رسوم التوصيل من فواتير العملاء (ZAD_PLAN ٤.١٠ و٤.٨).
--
-- «المشوار ولا التوصيل» كان مستني رسوم التوصيل، ومكانش ليها مصدر. فاتورة طلب نينجا أو كيتا مكتوب فيها الرسوم:
-- analyze_receipt بيقراها في حقل لوحده (deliveryApp + deliveryFee) وبيكتبها هنا من باب السيرفر.
--   • zad_delivery_fees — قراية لكل فاتورة: التطبيق (مفتاح من قايمة مقفولة، _shared/deliveryApps.ts)، الرسوم، عملة
--     بلد الحساب. مفيش user_id: home_key = sha256 للعميل، عشان نعدّ البيوت ونمنع نفس الفاتورة تتعد مرتين في اليوم.
--   • zad_delivery_fees_typical(country) — الوسيط لكل تطبيق من آخر ٦٠ يوم، من قرايتين أو أكتر (قراية واحدة ممكن
--     تكون غلطة). العقل بيطرحه من توفير عرض في نفس التطبيق، ولو الرسوم بتاكل التوفير العرض مايتقالش.
-- السيرفر بس. رقم الإصدار مش على ساعة مدوّرة عن قصد.

create table if not exists public.zad_delivery_fees (
  id bigint generated always as identity primary key,
  country text not null check (country ~ '^[A-Z]{2}$'),
  app_key text not null check (app_key ~ '^[a-z]{2,20}$'),
  app text not null check (char_length(app) between 2 and 20),
  fee numeric(10, 2) not null check (fee > 0 and fee < 1000),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  home_key text not null check (char_length(home_key) between 16 and 64),
  seen_on date not null default current_date,
  created_at timestamptz not null default now(),
  unique (home_key, app_key, seen_on, fee)
);

create index if not exists zad_delivery_fees_country_seen on public.zad_delivery_fees (country, seen_on desc);

alter table public.zad_delivery_fees enable row level security;
revoke all on public.zad_delivery_fees from anon, authenticated;
grant all on public.zad_delivery_fees to service_role;

create or replace function public.zad_delivery_fees_typical(p_country text)
returns table (app_key text, app text, fee numeric, currency text, readings integer, homes integer)
language sql
stable
security definer
set search_path = public
as $$
  select f.app_key, max(f.app), round(percentile_cont(0.5) within group (order by f.fee)::numeric, 2),
         max(f.currency), count(*)::integer, count(distinct f.home_key)::integer
    from public.zad_delivery_fees f
   where f.country = upper(p_country) and f.seen_on > current_date - 60
   group by f.app_key, f.currency
  having count(*) >= 2;
$$;

revoke all on function public.zad_delivery_fees_typical(text) from public, anon, authenticated;
grant execute on function public.zad_delivery_fees_typical(text) to service_role;
