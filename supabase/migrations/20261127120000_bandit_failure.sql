-- م٨: قاعدة الفشل. إشعار اتعرض من أكتر من ٢٤ ساعة، ولسه is_read=false، ومااتحسبش = فشل للقالب
-- (failures + 1 للفرد). الصف بيتقفل (settled_at + outcome) فمايتحسبش تاني، وقراية متأخرة بعد الفشل
-- مابتكافئش (settle_read بيدوّر على settled_at is null بس). العمر وis_read بيتأكدوا هنا مش بس في الكود.
alter table public.zad_bandit_shown add column if not exists outcome text check (outcome in ('reward', 'failure'));
-- الصفوف القديمة المقفولة كلها كانت مكافآت
update public.zad_bandit_shown set outcome = 'reward' where settled_at is not null and outcome is null;

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
  update public.zad_bandit_shown set settled_at = now(), outcome = 'reward' where notification_id = p_notification;
  return true;
end $$;

create or replace function public.zad_bandit_settle_failure(p_user uuid, p_notification uuid)
returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
declare s public.zad_bandit_shown;
begin
  select * into s from public.zad_bandit_shown
   where notification_id = p_notification and user_id = p_user and settled_at is null for update;
  if not found then return false; end if;
  if s.shown_at > now() - interval '24 hours' then return false; end if;
  -- لازم الإشعار موجود وغير مقروء (إشعار اتمسح = مفيش إشارة)
  if not exists (
    select 1 from public.app_notifications where id = p_notification and user_id = p_user and is_read is false
  ) then return false; end if;
  insert into public.zad_bandit_state (user_id, member_id, kind, arm, successes, failures)
  values (s.user_id, s.member_id, s.kind, s.arm, 0, 1)
  on conflict (user_id, member_id, kind, arm)
  do update set failures = public.zad_bandit_state.failures + 1, updated_at = now();
  update public.zad_bandit_shown set settled_at = now(), outcome = 'failure' where notification_id = p_notification;
  return true;
end $$;

revoke all on function public.zad_bandit_settle_failure(uuid, uuid) from public, anon, authenticated;
grant execute on function public.zad_bandit_settle_failure(uuid, uuid) to service_role;
