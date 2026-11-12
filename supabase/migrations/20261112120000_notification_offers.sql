-- عروض الإشعارات (ZAD_PLAN ١٠.١٤، المالك ١٢/١١): إشعار خصم أو كود من تطبيق تسوق أو توصيل، مقروء بالعقل
-- (zad-brain/notificationOffers.ts). **لصاحبه بس**: ممكن يكون فيه اسمه أو كود متربط بحسابه، فالقراية
-- user_id = auth.uid() ومفيش سياسة تانية. الكتابة من zad-brain (service_role) بس. عقل الجمهور (١٠.١٥) بياخد
-- منها إشارات مجمّعة بحد ٥ بيوت، مش الصفوف.

create table if not exists public.zad_notification_offers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  ingest_event_id uuid,
  package_name text not null check (char_length(package_name) between 1 and 120),
  store text not null check (char_length(store) between 1 and 60),
  item text check (item is null or char_length(item) <= 80),
  discount_percent numeric check (discount_percent is null or (discount_percent > 0 and discount_percent <= 95)),
  discount_amount numeric check (discount_amount is null or discount_amount > 0),
  currency text check (currency is null or currency ~ '^[A-Z]{3,5}$'),
  code text check (code is null or code ~ '^[A-Z0-9-]{3,30}$'),
  link text check (link is null or link ~ '^https://'),
  expires_at timestamptz not null,
  opened_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, ingest_event_id)
);

create index if not exists zad_notification_offers_user_live_idx
  on public.zad_notification_offers (user_id, expires_at desc);

alter table public.zad_notification_offers enable row level security;

drop policy if exists zad_notification_offers_own on public.zad_notification_offers;
create policy zad_notification_offers_own on public.zad_notification_offers
  for select to authenticated using (user_id = auth.uid());

revoke all on public.zad_notification_offers from anon;
revoke insert, update, delete on public.zad_notification_offers from authenticated;
grant select on public.zad_notification_offers to authenticated;
grant all on public.zad_notification_offers to service_role;
