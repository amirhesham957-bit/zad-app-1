-- وضع الطوارئ «مفلس باقي الشهر» (٢٠٢٦-٠٩-١٤).
--
-- طلب المستخدم: أول ما العميل يقول «أنا مفلس»، زاد تعيد جدولة ميزانية الأيام الباقية، توقف
-- اقتراحات الشراء، وتقترح وصفات من اللي في البيت بس (١٠٠٪ من المخزون).
--
-- جدول لوحده مش عمود في zad_users: zad_users متخزن كمان في Room على الموبايل (ZadUser)، وأي
-- عمود جديد هناك محتاج ميجريشن محلية. صف واحد لكل عميل؛ التفعيل upsert والخروج ended_at.
-- «شغال» = ended_at is null و ends_at > now() — بيقفل لوحده آخر الدورة.
--
-- daily_cap = اللي معاه ÷ الأيام الباقية وقت التفعيل (أو اللي قاله بنفسه: «معايا ٢٠٠ لآخر الشهر»).
-- null = مانعرفش معاه كام، والوضع شغال برضه (الشراء والوصفات) لحد ما يقول.

create table if not exists public.zad_broke_mode (
  user_id uuid primary key references auth.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  ended_at timestamptz,
  cash_left numeric(14, 2) check (cash_left is null or cash_left >= 0),
  daily_cap numeric(14, 2) check (daily_cap is null or daily_cap >= 0),
  currency text check (currency is null or char_length(currency) <= 10),
  source text not null default 'app' check (source in ('app', 'voice', 'chat', 'telegram')),
  updated_at timestamptz not null default now(),
  check (ends_at > started_at)
);

alter table public.zad_broke_mode enable row level security;

drop policy if exists "broke mode: owner reads" on public.zad_broke_mode;
create policy "broke mode: owner reads" on public.zad_broke_mode
  for select using (auth.uid() = user_id);
drop policy if exists "broke mode: owner inserts" on public.zad_broke_mode;
create policy "broke mode: owner inserts" on public.zad_broke_mode
  for insert with check (auth.uid() = user_id);
drop policy if exists "broke mode: owner updates" on public.zad_broke_mode;
create policy "broke mode: owner updates" on public.zad_broke_mode
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "broke mode: owner deletes" on public.zad_broke_mode;
create policy "broke mode: owner deletes" on public.zad_broke_mode
  for delete using (auth.uid() = user_id);
