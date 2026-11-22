-- م٦.٢: ملاحظات توافر الصنف في المحل (موجود / خلصان) — مدخل احتمال الريستوك (_shared/or/restockAvailability.ts).
-- المصادر: فواتير الجمهور، النشرات، الشركاء. خصوصية: مفيش user_id ولا family_id ولا أي حاجة تدل على مين اشترى أو أبلغ.
-- السيرفر بس (service role): RLS شغالة من غير سياسات.

create table if not exists public.zad_restock_observations (
  id bigint generated always as identity primary key,
  country text not null check (country ~ '^[A-Z]{2}$'),
  store_key text not null check (length(store_key) between 2 and 60),
  item_key text not null check (length(item_key) between 2 and 60),
  in_stock boolean not null,
  source_kind text not null check (source_kind in ('receipt', 'flyer', 'partner')),
  observed_at timestamptz not null default now(),
  -- موقع تقريبي للمحل (٢ رقم عشري ≈ ١ كم)، مش موقع الشخص.
  area_lat numeric(5, 2),
  area_lng numeric(5, 2)
);
create index if not exists zad_restock_obs_lookup on public.zad_restock_observations (country, item_key, observed_at desc);
alter table public.zad_restock_observations enable row level security;
revoke all on public.zad_restock_observations from public, anon, authenticated;

-- الملاحظات بعد ٩٠ يوم مالهاش وزن (نص العمر ٧ أيام) فبتتمسح مع أول كتابة جديدة بالكرون الأسبوعي.
create or replace function public.zad_restock_obs_prune() returns integer
language sql security definer set search_path = public as $$
  with d as (delete from public.zad_restock_observations where observed_at < now() - interval '90 days' returning 1)
  select count(*)::int from d;
$$;
revoke all on function public.zad_restock_obs_prune() from public, anon, authenticated;
