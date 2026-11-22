-- م٦.٤: أحداث الإشعارات بمفاتيح منفصلة (appointment / trip / document_due)، مقفولة افتراضياً.
-- zad_notification_switches: مفتاح لكل نوع لكل مستخدم، المستخدم بيقرا ويكتب صفوفه بس (مفيش مسح).
-- zad_notification_reads: الاستخراج المنظّم بس (date/time/place/title). مفيش عمود نص خام. الكتابة service role بس.

create table if not exists public.zad_notification_switches (
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('appointment', 'trip', 'document_due')),
  enabled boolean not null default false,
  enabled_at timestamptz,
  primary key (user_id, kind)
);
alter table public.zad_notification_switches enable row level security;
revoke all on public.zad_notification_switches from public, anon, authenticated;
grant select, insert, update on public.zad_notification_switches to authenticated;

drop policy if exists zad_notification_switches_select on public.zad_notification_switches;
create policy zad_notification_switches_select on public.zad_notification_switches
  for select to authenticated using (user_id = auth.uid());
drop policy if exists zad_notification_switches_insert on public.zad_notification_switches;
create policy zad_notification_switches_insert on public.zad_notification_switches
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists zad_notification_switches_update on public.zad_notification_switches;
create policy zad_notification_switches_update on public.zad_notification_switches
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.zad_notification_reads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('appointment', 'trip', 'document_due')),
  extracted jsonb not null,
  read_at timestamptz not null default now()
);
create index if not exists zad_notification_reads_user_day on public.zad_notification_reads (user_id, read_at desc);
alter table public.zad_notification_reads enable row level security;
revoke all on public.zad_notification_reads from public, anon, authenticated;
grant select on public.zad_notification_reads to authenticated;

drop policy if exists zad_notification_reads_select on public.zad_notification_reads;
create policy zad_notification_reads_select on public.zad_notification_reads
  for select to authenticated using (user_id = auth.uid());
