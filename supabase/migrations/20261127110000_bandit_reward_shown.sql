-- م٨.٢/م٨.٥: تغذية مكافأة الـbandit. zad_bandit_shown = أي قالب اتعرض في أي إشعار (للنسب)،
-- والمكافأة الوحيدة: الإشعار اتفتح (app_notifications.is_read = true). مفيش فتح = مفيش تحديث (مش فشل).
-- الكتابة من دالتين security definer بس، service_role بس. مفيش FK: الحالة ممكن تتمسح لوحدها.
create table if not exists public.zad_bandit_shown (
  notification_id uuid primary key,
  user_id uuid not null,
  member_id uuid not null,
  kind text not null check (length(kind) between 1 and 80),
  arm text not null check (length(arm) between 1 and 80),
  shown_at timestamptz not null default now(),
  settled_at timestamptz
);
create index if not exists zad_bandit_shown_open on public.zad_bandit_shown (shown_at) where settled_at is null;
alter table public.zad_bandit_shown enable row level security;
revoke all on public.zad_bandit_shown from public, anon, authenticated, service_role;
grant select on public.zad_bandit_shown to service_role;

create or replace function public.zad_bandit_note_shown(
  p_user uuid, p_member uuid, p_notification uuid, p_kind text, p_arm text
) returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if p_user is null or p_member is null or p_notification is null then return false; end if;
  -- الإشعار لازم يكون بتاع نفس الحساب
  if not exists (select 1 from public.app_notifications where id = p_notification and user_id = p_user) then
    return false;
  end if;
  insert into public.zad_bandit_shown (notification_id, user_id, member_id, kind, arm)
  values (p_notification, p_user, p_member, p_kind, p_arm)
  on conflict (notification_id) do nothing;
  return true;
end $$;

-- مكافأة واحدة لكل إشعار، وبس لو الإشعار اتقرا فعلاً (بتتأكد هنا مش بس في الكود).
create or replace function public.zad_bandit_settle_read(p_user uuid, p_notification uuid)
returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
declare s public.zad_bandit_shown;
begin
  select * into s from public.zad_bandit_shown
   where notification_id = p_notification and user_id = p_user and settled_at is null for update;
  if not found then return false; end if;
  if not exists (
    select 1 from public.app_notifications where id = p_notification and user_id = p_user and is_read is true
  ) then return false; end if;
  insert into public.zad_bandit_state (user_id, member_id, kind, arm, successes, failures)
  values (s.user_id, s.member_id, s.kind, s.arm, 1, 0)
  on conflict (user_id, member_id, kind, arm)
  do update set successes = public.zad_bandit_state.successes + 1, updated_at = now();
  update public.zad_bandit_shown set settled_at = now() where notification_id = p_notification;
  return true;
end $$;

revoke all on function public.zad_bandit_note_shown(uuid, uuid, uuid, text, text) from public, anon, authenticated;
revoke all on function public.zad_bandit_settle_read(uuid, uuid) from public, anon, authenticated;
grant execute on function public.zad_bandit_note_shown(uuid, uuid, uuid, text, text) to service_role;
grant execute on function public.zad_bandit_settle_read(uuid, uuid) to service_role;
