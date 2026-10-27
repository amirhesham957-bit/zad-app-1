-- الحساس مايتحفظش غير بعد «صح؟» (ZAD_PLAN ٥.٣، الشريحة التانية).
--
-- remember في الشات كان بيكتب أي حقيقة في zad_memory على طول، من غير ما يسأل (قاعدة 5b). لحاجة زي «مراته حامل»
-- أو «أخوه مسجون» ده غلط: الملاحظة دي لو اتفهمت غلط بتجرح، ولو اتشاركت مع العيلة بتفضح.
--
--   • zad_memory_pending: الملاحظة الحساسة (zad-brain/sensitiveMemory.ts، أو sensitive=true من الموديل) بتتركن
--     هنا بكل اللي كانت هتتكتب بيه، والعقل بيسأل «أفتكر إن …؟ صح؟». لقطة الشات بتشيل اللي لسه مستني (٣ أيام).
--   • التأكيد بيكتبها في zad_memory، والرفض بيقفلها؛ الاتنين من لفة **بعد** اللي اتركنت فيها (الحارس في الكود).
--   • مفيش مسح: «لأ» برضه بيتسجل، وده اللي بيقول هل الكشف بيسأل في الحاجات الصح.
-- الكتابة كلها من السيرفر (service_role)، والعميل بيقرا صفوفه بس.

create table if not exists public.zad_memory_pending (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  scope text not null default 'general',
  note text not null check (char_length(note) between 10 and 200),
  confidence real not null default 0.5,
  family_id uuid,
  valid_until timestamptz,
  about jsonb not null default '[]'::jsonb,
  topic text not null,
  created_at timestamptz not null default now(),
  resolution text check (resolution is null or resolution in ('saved', 'declined')),
  resolved_at timestamptz,
  constraint zad_memory_pending_resolved check ((resolution is null) = (resolved_at is null))
);
create index if not exists zad_memory_pending_open on public.zad_memory_pending (user_id, created_at desc)
  where resolution is null;

alter table public.zad_memory_pending enable row level security;
revoke all on table public.zad_memory_pending from anon, authenticated;
grant select on table public.zad_memory_pending to authenticated;
grant all on table public.zad_memory_pending to service_role;
drop policy if exists zad_memory_pending_own on public.zad_memory_pending;
create policy zad_memory_pending_own on public.zad_memory_pending for select to authenticated
  using (user_id = (select auth.uid()));

comment on table public.zad_memory_pending is
  'ZAD_PLAN 5.3 — sensitive memory notes held until the customer answers «صح؟» in a later turn. Written by the server only.';
