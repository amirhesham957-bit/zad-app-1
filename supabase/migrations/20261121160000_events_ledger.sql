-- نواة البيانات، الخطوة الأولى (ZAD_OR_PLAN م٢.١، ٢١/١١).
--
-- zad_events: دفتر بيتكتب ومايتعدلش. كل حاجة حصلت في البيت (اتصرف، اتشرى، اتاخد دوا، اتقاس) حدث واحد بصاحبه
-- (member_id)، ووقته عند العميل (occurred_at)، ووقت تسجيله (recorded_at)، ومصدره، ونسبة الثقة. الجداول الحالية
-- (zad_transactions، zad_inventory…) فاضلة زي ما هي؛ zad_commit_intent (م٢.٢) هتكتب الحدث وتحدّث الجدول مع بعض.
--
-- member_id إلزامي (قرار المالك ٢٠/١١: «ذوق البنت ما يختلطش بأكل الجيم بتاع أخوها»). المقاس ٢١/١١: مفيش جدول
-- لأفراد البيت خالص — الفرد نص حر (for_person) في المواعيد والصيدلية وجدول الحصص، و for_person على الحركات
-- ماتستخدمش ولا مرة (٢٤ حركة، ٣٠ حساب). فـzad_household_members بيتعمل هنا، وكل حساب بياخد صف «أنا» (self)
-- تلقائياً، وباقي البيت (طفل، كبير، مُسن) بيتضاف بعدين.
--
-- الكتابة: مفيش كتابة من الموبايل على الجدولين دول. الباب الوحيد هيبقى zad_commit_intent (م٢.٢، security definer)،
-- والموبايل بيقرا بتاعه بس (RLS). الحدث مابيتعدلش ومابيتمسحش، إلا لما الحساب نفسه يتمسح (cascade).

-- ── أفراد البيت ──────────────────────────────────────────────────────────────────────────────────────────
create table if not exists public.zad_household_members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) between 1 and 60),
  kind text not null check (kind in ('self', 'adult', 'child', 'elder')),
  birth_year int check (birth_year between 1900 and 2100),
  -- لو الفرد ليه حساب زاد (فرد في العيلة). مش شرط.
  linked_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  archived_at timestamptz,
  -- عشان zad_events يربط (member_id, user_id) مع بعض: الحدث مايشاورش على فرد من بيت تاني.
  unique (id, user_id)
);
create unique index if not exists zad_household_members_one_self on public.zad_household_members (user_id) where kind = 'self';

alter table public.zad_household_members enable row level security;
drop policy if exists household_members_read_own on public.zad_household_members;
create policy household_members_read_own on public.zad_household_members
  for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete, truncate on public.zad_household_members from anon, authenticated;

-- ── دفتر الأحداث ─────────────────────────────────────────────────────────────────────────────────────────
create table if not exists public.zad_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  member_id uuid not null,
  -- مفتاح التكرار من الموبايل (م٢.٤): نفس الحدث مرتين = نفس الصف.
  client_event_id text not null check (length(client_event_id) between 1 and 100),
  kind text not null check (kind ~ '^[a-z][a-z0-9_.]{1,60}$'),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  -- وقت الحدث عند العميل (بتوقيت حسابه، accountTimeZoneProvider) — مش وقت السيرفر.
  occurred_at timestamptz not null,
  recorded_at timestamptz not null default now(),
  source text not null check (source in ('manual', 'receipt', 'bank', 'model', 'cron')),
  confidence numeric(4, 3) check (confidence between 0 and 1),
  unique (user_id, client_event_id),
  -- NO ACTION (مش RESTRICT): لما الحساب يتمسح، الأفراد والأحداث بيتمسحوا في نفس الأمر والفحص في آخره.
  foreign key (member_id, user_id) references public.zad_household_members (id, user_id)
);
create index if not exists zad_events_user_kind_time on public.zad_events (user_id, kind, occurred_at desc);
create index if not exists zad_events_member_time on public.zad_events (member_id, occurred_at desc);

alter table public.zad_events enable row level security;
drop policy if exists events_read_own on public.zad_events;
create policy events_read_own on public.zad_events
  for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete, truncate on public.zad_events from anon, authenticated;

-- مابيتعدلش، ومابيتمسحش غير مع حسابه. الغلط بيتصلح بحدث جديد (تصحيح)، مش بتعديل القديم.
create or replace function public.zad_events_append_only()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op = 'UPDATE' then
    raise exception 'zad_events is append-only: write a correcting event instead' using errcode = '42501';
  end if;
  -- DELETE: مسموح بس لما الحساب نفسه اتمسح (cascade من auth.users).
  if exists (select 1 from auth.users where id = old.user_id) then
    raise exception 'zad_events is append-only: events leave only with their account' using errcode = '42501';
  end if;
  return old;
end;
$fn$;
revoke all on function public.zad_events_append_only() from public, anon, authenticated;

drop trigger if exists zad_events_append_only on public.zad_events;
create trigger zad_events_append_only
  before update or delete on public.zad_events
  for each row execute function public.zad_events_append_only();

-- ── «أنا» لكل حساب ────────────────────────────────────────────────────────────────────────────────────────
-- للسيرفر بس (العقل والـzad_commit_intent): بيرجّع صف «أنا» وبيعمله لو مش موجود.
create or replace function public.zad_self_member(p_user uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id uuid;
begin
  select id into v_id from public.zad_household_members where user_id = p_user and kind = 'self';
  if v_id is not null then
    return v_id;
  end if;
  insert into public.zad_household_members (user_id, display_name, kind)
  values (p_user, coalesce(nullif(btrim((select name from public.zad_users where id = p_user)), ''), 'أنا'), 'self')
  on conflict (user_id) where kind = 'self' do nothing;
  select id into v_id from public.zad_household_members where user_id = p_user and kind = 'self';
  return v_id;
end;
$fn$;
revoke all on function public.zad_self_member(uuid) from public, anon, authenticated;
grant execute on function public.zad_self_member(uuid) to service_role;

-- حساب جديد في zad_users ⇒ صفه «أنا» على طول.
create or replace function public.zad_users_self_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if exists (select 1 from auth.users where id = new.id) then
    perform public.zad_self_member(new.id);
  end if;
  return new;
end;
$fn$;
revoke all on function public.zad_users_self_member() from public, anon, authenticated;

drop trigger if exists zad_users_self_member on public.zad_users;
create trigger zad_users_self_member
  after insert on public.zad_users
  for each row execute function public.zad_users_self_member();

-- الحسابات الموجودة (٣٠ يوم ٢١/١١).
select public.zad_self_member(u.id) from public.zad_users u where exists (select 1 from auth.users a where a.id = u.id);
