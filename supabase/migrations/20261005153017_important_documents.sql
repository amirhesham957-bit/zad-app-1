-- حارس المستندات (ZAD_LIVING_BRAIN.md §١٠ والشريحة ٣٢، قرار المالك ٢٠٢٦-١٠-٠٥).
--
-- الجواز والبطاقة والإقامة والرخص: زاد بيفكّر قبل ما تنتهي — ملاحظة في صندوق العقل من جولة الموظفين
-- (zad-brain/documents.ts) وإشعار محلي على الموبايل في يوم كل مرحلة. صفر توكنز.
--
-- المخزّن **النوع وصاحبه وتاريخ الانتهاء بس**. مفيش رقم مستند ولا صورة ولا تاريخ ميلاد: التذكير مش محتاجهم،
-- ورقم جواز في داتابيز تطبيق بيت خطر تسريب من غير أي فايدة — فمالوش عمود أصلاً.
--
-- holder: لمين («سلمى»، «ماما»)، فاضي = العميل نفسه. label: اسم للنوع «other» (كارنيه النادي…).
-- صف واحد لكل (نوع، صاحب، اسم) — تجديد الجواز تعديل للتاريخ، مش صف جديد، والعقل والتطبيق بيكتبوا بـupsert
-- على المفتاح ده.

create table if not exists public.zad_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null
    check (kind in ('passport', 'national_id', 'residence', 'driving_license', 'vehicle_license', 'other')),
  holder text not null default '' check (holder = btrim(holder) and char_length(holder) <= 40),
  label text not null default '' check (label = btrim(label) and char_length(label) <= 40),
  expires_on date not null check (expires_on between date '2000-01-01' and date '2100-12-31'),
  created_at timestamptz not null default now(),
  constraint zad_documents_other_named check (kind <> 'other' or label <> ''),
  constraint zad_documents_one_per_holder unique (user_id, kind, holder, label)
);

alter table public.zad_documents enable row level security;
-- الصلاحيات الافتراضية في المشروع بتدّي anon وauthenticated كل حاجة على أي جدول جديد.
revoke all on table public.zad_documents from anon, authenticated;
grant select, insert, update, delete on table public.zad_documents to authenticated;

drop policy if exists "documents: owner reads" on public.zad_documents;
create policy "documents: owner reads" on public.zad_documents
  for select using (auth.uid() = user_id);
drop policy if exists "documents: owner adds" on public.zad_documents;
create policy "documents: owner adds" on public.zad_documents
  for insert with check (auth.uid() = user_id);
drop policy if exists "documents: owner edits" on public.zad_documents;
create policy "documents: owner edits" on public.zad_documents
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "documents: owner deletes" on public.zad_documents;
create policy "documents: owner deletes" on public.zad_documents
  for delete using (auth.uid() = user_id);

comment on table public.zad_documents is
  'حارس المستندات: نوع المستند وصاحبه وتاريخ انتهائه بس — من غير رقم ولا صورة. التنبيه بالمراحل في zad-brain/documents.ts والموبايل.';
