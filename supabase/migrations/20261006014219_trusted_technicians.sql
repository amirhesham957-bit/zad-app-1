-- حارس الطوارئ المنزلية: الفنيين اللي بتثق فيهم (ZAD_LIVING_BRAIN.md الشريحة ٤١، طلب المالك ٢٠٢٦-١٠-٠٥).
--
-- مية بتنزل من السقف، ماس كهربا، ريحة غاز: وقتها العميل مش هيدوّر في جهات الاتصال. القايمة دي بتتفتح بنقرة من الشات
-- لما الكلام فيه كلمات طوارئ البيت (التطبيق والعقل بنفس الكلمات)، ومن «الصيانة» في أي وقت.
--
-- الاسم والصنعة والرقم وملاحظة قصيرة بس. الرقم بيتخزن عشان العميل نفسه يتصل بيه — مايتبعتش لحد ومايتقريش لحد غيره
-- (صفوف صاحبها بس، زي `zad_documents`). مفيش مشاركة مع العيلة لسه: قرار منتج (مين يشوف أرقام مين).

create table if not exists public.zad_trusted_technicians (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (name = btrim(name) and char_length(name) between 2 and 60),
  trade text not null
    check (trade in ('plumber', 'electrician', 'gas', 'ac', 'carpenter', 'locksmith', 'appliances', 'other')),
  phone text not null check (phone ~ '^\+?[0-9][0-9 -]{5,19}$'),
  notes text not null default '' check (notes = btrim(notes) and char_length(notes) <= 120),
  created_at timestamptz not null default now(),
  constraint zad_trusted_technicians_one_number unique (user_id, phone)
);

create index if not exists zad_trusted_technicians_user_trade on public.zad_trusted_technicians (user_id, trade);

alter table public.zad_trusted_technicians enable row level security;
-- الصلاحيات الافتراضية في المشروع بتدّي anon وauthenticated كل حاجة على أي جدول جديد.
revoke all on table public.zad_trusted_technicians from anon, authenticated;
grant select, insert, update, delete on table public.zad_trusted_technicians to authenticated;

drop policy if exists "technicians: owner reads" on public.zad_trusted_technicians;
create policy "technicians: owner reads" on public.zad_trusted_technicians
  for select using (auth.uid() = user_id);
drop policy if exists "technicians: owner adds" on public.zad_trusted_technicians;
create policy "technicians: owner adds" on public.zad_trusted_technicians
  for insert with check (auth.uid() = user_id);
drop policy if exists "technicians: owner edits" on public.zad_trusted_technicians;
create policy "technicians: owner edits" on public.zad_trusted_technicians
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "technicians: owner deletes" on public.zad_trusted_technicians;
create policy "technicians: owner deletes" on public.zad_trusted_technicians
  for delete using (auth.uid() = user_id);

comment on table public.zad_trusted_technicians is
  'حارس الطوارئ المنزلية: الفنيين اللي العميل بيثق فيهم (اسم، صنعة، رقم). بتتفتح بنقرة لما الشات فيه طوارئ بيت. صفوف صاحبها بس.';
