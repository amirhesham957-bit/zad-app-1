-- م٥.٢ (ZAD_OR_PLAN، ٢٢/١١): توزيع شغل البيت بالـHungarian (`_shared/or/choreAssignment.ts`).
--
-- الخوارزمية محتاجة حاجتين مش موجودين: مدة كل مهمة، ووقت وتفضيلات كل فرد. المقاس على الحي ٢٢/١١: family_chores فيها
-- صف واحد في عيلة واحدة، و٤ صفوف في family_members.
--
--   ١. family_chores.minutes: مدة المهمة بالدقايق (null = مش معروفة، والتوزيع بيعتبرها ١٥).
--   ٢. family_chore_preferences: لكل فرد (family_members.id، نفس اللي في assigned_to) دقايقه المتاحة في الأسبوع،
--      والمهام اللي مابيحبهاش واللي بيحبها (بالعنوان). الفرد بيكتب بتاعه، والأدمن (الأب/الأم) بيكتب لأي فرد.
--   ٣. zad_apply_chore_plan: الأدمن بيطبّق التوزيع مرة واحدة (كله أو ولا حاجة). security invoker: سياسات RLS وتريجر
--      zad_family_chores_guard (20260921150000) شغالين على كل سطر زي التعديل من التطبيق بالظبط.
--
-- الحساب نفسه في zad-core-intelligence (action=chore_plan) من غير كتابة؛ التطبيق بيعرضه وبعدين بيطبّقه هنا.

alter table public.family_chores
  add column if not exists minutes integer;
alter table public.family_chores drop constraint if exists family_chores_minutes_range;
alter table public.family_chores
  add constraint family_chores_minutes_range check (minutes is null or minutes between 1 and 600);
comment on column public.family_chores.minutes is 'م٥.٢: مدة المهمة بالدقايق. null = مش معروفة (التوزيع بيعتبرها ١٥).';

create table if not exists public.family_chore_preferences (
  member_id uuid primary key references public.family_members(id) on delete cascade,
  family_id uuid not null references public.family_groups(id) on delete cascade,
  minutes_per_week integer not null default 120 check (minutes_per_week between 0 and 2000),
  dislikes text[] not null default '{}' check (cardinality(dislikes) <= 20),
  likes text[] not null default '{}' check (cardinality(likes) <= 20),
  updated_at timestamptz not null default now()
);
create index if not exists family_chore_preferences_family on public.family_chore_preferences (family_id);

alter table public.family_chore_preferences enable row level security;

-- الكتابة: الفرد لنفسه، أو أدمن العيلة لأي فرد فيها. والفرد لازم يكون من نفس العيلة اللي في الصف.
create or replace function public.zad_can_set_chore_prefs(p_member uuid, p_family uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.family_members m
     where m.id = p_member and m.family_id = p_family
       and (m.user_id = auth.uid() or public.zad_is_family_admin(p_family))
  );
$$;
revoke all on function public.zad_can_set_chore_prefs(uuid, uuid) from public, anon;
grant execute on function public.zad_can_set_chore_prefs(uuid, uuid) to authenticated, service_role;

drop policy if exists family_chore_prefs_select on public.family_chore_preferences;
create policy family_chore_prefs_select on public.family_chore_preferences
  for select to authenticated using (family_id in (select public.get_my_family_ids()));
drop policy if exists family_chore_prefs_insert on public.family_chore_preferences;
create policy family_chore_prefs_insert on public.family_chore_preferences
  for insert to authenticated with check (public.zad_can_set_chore_prefs(member_id, family_id));
drop policy if exists family_chore_prefs_update on public.family_chore_preferences;
create policy family_chore_prefs_update on public.family_chore_preferences
  for update to authenticated
  using (public.zad_can_set_chore_prefs(member_id, family_id))
  with check (public.zad_can_set_chore_prefs(member_id, family_id));
drop policy if exists family_chore_prefs_delete on public.family_chore_preferences;
create policy family_chore_prefs_delete on public.family_chore_preferences
  for delete to authenticated using (public.zad_can_set_chore_prefs(member_id, family_id));

revoke all on public.family_chore_preferences from anon;
grant select, insert, update, delete on public.family_chore_preferences to authenticated;

-- ── التطبيق ─────────────────────────────────────────────────────────────────────────────────────────────
-- p_plan = [{"chore_id": uuid, "member_id": uuid}, ...]. الرفض المتوقع إجابة مش exception (زي zad_join_family).

create or replace function public.zad_apply_chore_plan(p_family uuid, p_plan jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_line jsonb;
  v_chore uuid;
  v_member uuid;
  v_done int := 0;
begin
  if auth.uid() is null or p_family is null or not (p_family in (select public.get_my_family_ids())) then
    return jsonb_build_object('ok', false, 'reason', 'not_in_family');
  end if;
  if not public.zad_is_family_admin(p_family) then
    return jsonb_build_object('ok', false, 'reason', 'admins_only');
  end if;
  if p_plan is null or jsonb_typeof(p_plan) <> 'array' or jsonb_array_length(p_plan) = 0 or jsonb_array_length(p_plan) > 100 then
    return jsonb_build_object('ok', false, 'reason', 'bad_plan');
  end if;

  for v_line in select * from jsonb_array_elements(p_plan) loop
    begin
      v_chore := (v_line ->> 'chore_id')::uuid;
      v_member := (v_line ->> 'member_id')::uuid;
    exception when others then
      raise exception 'bad_plan' using errcode = '22023';
    end;
    if v_chore is null or v_member is null then
      raise exception 'bad_plan' using errcode = '22023';
    end if;
    if not exists (select 1 from public.family_members where id = v_member and family_id = p_family) then
      raise exception 'assignee_not_in_family' using errcode = '42501';
    end if;
    update public.family_chores
       set assigned_to = v_member
     where id = v_chore and family_id = p_family and not is_completed;
    if not found then
      raise exception 'chore_not_open' using errcode = '22023';
    end if;
    v_done := v_done + 1;
  end loop;

  return jsonb_build_object('ok', true, 'assigned', v_done);
exception
  when sqlstate '22023' or sqlstate '42501' then
    return jsonb_build_object('ok', false, 'reason', sqlerrm);
end
$$;

revoke all on function public.zad_apply_chore_plan(uuid, jsonb) from public, anon;
grant execute on function public.zad_apply_chore_plan(uuid, jsonb) to authenticated;
