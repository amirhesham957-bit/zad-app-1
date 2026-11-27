-- م٧.٨ (تشديد الموافقة): عرض مدّ ميعاد هدف واقف بيتسجل **من السيرفر** وقت ما الاقتراح يتعرض (مش من كلام الموديل).
-- apply_goal_adjustment بتنفّذ بس لو فيه عرض لنفس الهدف، لم ينتهِ (٢٤ ساعة)، ومااتستهلكش، واتعرض في لفة قبل لفة الموافقة.
-- الكتابة من ٣ دوال security definer بس (service_role). مفيش FK: العرض ممكن يتمسح لوحده. الطفل برا (هدف فرد kind = child).
create table if not exists public.zad_goal_offers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  goal_id uuid not null,
  deadline date not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  consumed_at timestamptz
);
-- عرض واحد مفتوح لكل (حساب، هدف).
create unique index if not exists zad_goal_offers_one_open on public.zad_goal_offers (user_id, goal_id) where consumed_at is null;
alter table public.zad_goal_offers enable row level security;
revoke all on public.zad_goal_offers from public, anon, authenticated, service_role;
grant select on public.zad_goal_offers to service_role;

-- يسجل العرض. بيرجع {ok, is_new, deadline} أو {ok:false, reason}. نفس الميعاد ولسه مفتوح = من غير تغيير (is_new=false)؛
-- ميعاد مختلف أو منتهي = عرض جديد (is_new=true) فلازم يتعرض في لفة تانية قبل الموافقة.
create or replace function public.zad_goal_offer_record(p_user uuid, p_goal uuid, p_deadline date)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare g record; o public.zad_goal_offers;
begin
  if p_user is null or p_goal is null or p_deadline is null then return jsonb_build_object('ok', false, 'reason', 'bad_args'); end if;
  select a.id, a.status, a.member_id into g from public.agent_goals a where a.id = p_goal and a.user_id = p_user;
  if not found or g.status <> 'active' then return jsonb_build_object('ok', false, 'reason', 'goal_not_found'); end if;
  if exists (select 1 from public.zad_household_members m where m.id = g.member_id and m.user_id = p_user and m.kind = 'child') then
    return jsonb_build_object('ok', false, 'reason', 'child_member');
  end if;
  select * into o from public.zad_goal_offers where user_id = p_user and goal_id = p_goal and consumed_at is null for update;
  if found and o.expires_at > now() and o.deadline = p_deadline then
    return jsonb_build_object('ok', true, 'is_new', false, 'deadline', o.deadline);
  end if;
  if found then delete from public.zad_goal_offers where id = o.id; end if;
  insert into public.zad_goal_offers (user_id, goal_id, deadline) values (p_user, p_goal, p_deadline);
  return jsonb_build_object('ok', true, 'is_new', true, 'deadline', p_deadline);
end $$;

-- يستهلك العرض ذرياً. status: ok (مع deadline) | none | expired | consumed | child_member.
create or replace function public.zad_goal_offer_consume(p_user uuid, p_goal uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare o public.zad_goal_offers; mem uuid;
begin
  select * into o from public.zad_goal_offers where user_id = p_user and goal_id = p_goal order by created_at desc limit 1 for update;
  if not found then return jsonb_build_object('status', 'none'); end if;
  if o.consumed_at is not null then return jsonb_build_object('status', 'consumed'); end if;
  if o.expires_at <= now() then return jsonb_build_object('status', 'expired'); end if;
  select a.member_id into mem from public.agent_goals a where a.id = p_goal and a.user_id = p_user and a.status = 'active';
  if not found then return jsonb_build_object('status', 'none'); end if;
  if exists (select 1 from public.zad_household_members m where m.id = mem and m.user_id = p_user and m.kind = 'child') then
    return jsonb_build_object('status', 'child_member');
  end if;
  update public.zad_goal_offers set consumed_at = now() where id = o.id;
  return jsonb_build_object('status', 'ok', 'deadline', o.deadline, 'offer_id', o.id);
end $$;

-- لو الباب رفض بعد الاستهلاك: رجّع العرض مفتوح.
create or replace function public.zad_goal_offer_release(p_user uuid, p_offer uuid)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.zad_goal_offers set consumed_at = null where id = p_offer and user_id = p_user and consumed_at is not null;
  return found;
exception when unique_violation then return false;
end $$;

revoke all on function public.zad_goal_offer_record(uuid, uuid, date) from public, anon, authenticated;
revoke all on function public.zad_goal_offer_consume(uuid, uuid) from public, anon, authenticated;
revoke all on function public.zad_goal_offer_release(uuid, uuid) from public, anon, authenticated;
grant execute on function public.zad_goal_offer_record(uuid, uuid, date) to service_role;
grant execute on function public.zad_goal_offer_consume(uuid, uuid) to service_role;
grant execute on function public.zad_goal_offer_release(uuid, uuid) to service_role;
