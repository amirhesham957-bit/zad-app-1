-- م٥.٢: مدة المهمة، وتفضيلات الأفراد تحت RLS، والتطبيق الذري للتوزيع. بعد chore_plan_scaffold.sql والمايجريشن.
\set ON_ERROR_STOP on

-- مدة خارج الحدود مرفوضة.
do $$ begin
  begin
    update public.family_chores set minutes = 0 where id = 'c0000000-0000-0000-0000-000000000001';
    raise exception 'minutes=0 accepted';
  exception when check_violation then null; end;
  update public.family_chores set minutes = 20 where id = 'c0000000-0000-0000-0000-000000000001';
end $$;

set role authenticated;

-- البنت بتكتب تفضيلاتها، ومش بتكتب تفضيلات أبوها.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', false);
insert into public.family_chore_preferences (member_id, family_id, minutes_per_week, dislikes, likes)
values ('b0000000-0000-0000-0000-0000000000b1', 'f0000000-0000-0000-0000-00000000000f', 90, '{غسيل المواعين}', '{كنس الصالة}');
do $$ begin
  begin
    insert into public.family_chore_preferences (member_id, family_id) values ('a0000000-0000-0000-0000-0000000000a1', 'f0000000-0000-0000-0000-00000000000f');
    raise exception 'member wrote the admin''s preferences';
  exception when insufficient_privilege then null; end;
  -- مش أدمن ⇒ مايطبّقش توزيع.
  if (public.zad_apply_chore_plan('f0000000-0000-0000-0000-00000000000f',
      '[{"chore_id":"c0000000-0000-0000-0000-000000000001","member_id":"b0000000-0000-0000-0000-0000000000b1"}]') ->> 'reason') <> 'admins_only' then
    raise exception 'member applied a plan';
  end if;
end $$;

-- الأب (أدمن) بيكتب لأي فرد، ومش بيكتب لفرد من عيلة تانية حتى لو حط عيلته في الصف.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', false);
update public.family_chore_preferences set minutes_per_week = 60 where member_id = 'b0000000-0000-0000-0000-0000000000b1';
insert into public.family_chore_preferences (member_id, family_id, minutes_per_week) values ('a0000000-0000-0000-0000-0000000000a1', 'f0000000-0000-0000-0000-00000000000f', 200);
do $$
declare r jsonb;
begin
  if (select minutes_per_week from public.family_chore_preferences where member_id = 'b0000000-0000-0000-0000-0000000000b1') <> 60 then
    raise exception 'admin could not set a member''s minutes';
  end if;
  begin
    insert into public.family_chore_preferences (member_id, family_id) values ('d0000000-0000-0000-0000-0000000000d1', 'f0000000-0000-0000-0000-00000000000f');
    raise exception 'foreign member accepted';
  exception when insufficient_privilege then null; end;
  if (select count(*) from public.family_chore_preferences) <> 2 then raise exception 'prefs visible count wrong'; end if;

  -- التطبيق كله أو ولا حاجة: سطر فيه مهمة خلصت ⇒ ولا سطر اتطبّق.
  r := public.zad_apply_chore_plan('f0000000-0000-0000-0000-00000000000f', '[
    {"chore_id":"c0000000-0000-0000-0000-000000000001","member_id":"b0000000-0000-0000-0000-0000000000b1"},
    {"chore_id":"c0000000-0000-0000-0000-000000000003","member_id":"b0000000-0000-0000-0000-0000000000b1"}]');
  if r ->> 'reason' <> 'chore_not_open' then raise exception 'closed chore: %', r; end if;
  if (select assigned_to from public.family_chores where id = 'c0000000-0000-0000-0000-000000000001') <> 'a0000000-0000-0000-0000-0000000000a1' then
    raise exception 'partial plan applied';
  end if;
  -- فرد من عيلة تانية، أو مهمة عيلة تانية: مرفوض.
  r := public.zad_apply_chore_plan('f0000000-0000-0000-0000-00000000000f',
    '[{"chore_id":"c0000000-0000-0000-0000-000000000001","member_id":"d0000000-0000-0000-0000-0000000000d1"}]');
  if r ->> 'reason' <> 'assignee_not_in_family' then raise exception 'foreign assignee: %', r; end if;
  r := public.zad_apply_chore_plan('f0000000-0000-0000-0000-0000000000a0',
    '[{"chore_id":"c0000000-0000-0000-0000-0000000000d1","member_id":"a0000000-0000-0000-0000-0000000000a1"}]');
  if r ->> 'reason' <> 'not_in_family' then raise exception 'foreign family: %', r; end if;
  r := public.zad_apply_chore_plan('f0000000-0000-0000-0000-00000000000f', '[]');
  if r ->> 'reason' <> 'bad_plan' then raise exception 'empty plan: %', r; end if;

  -- التوزيع الصح.
  r := public.zad_apply_chore_plan('f0000000-0000-0000-0000-00000000000f', '[
    {"chore_id":"c0000000-0000-0000-0000-000000000001","member_id":"a0000000-0000-0000-0000-0000000000a1"},
    {"chore_id":"c0000000-0000-0000-0000-000000000002","member_id":"b0000000-0000-0000-0000-0000000000b1"}]');
  if (r ->> 'assigned')::int <> 2 then raise exception 'apply: %', r; end if;
  if (select assigned_to from public.family_chores where id = 'c0000000-0000-0000-0000-000000000002') <> 'b0000000-0000-0000-0000-0000000000b1' then
    raise exception 'plan not applied';
  end if;
end $$;

reset role;
do $$ begin
  if has_function_privilege('anon', 'public.zad_apply_chore_plan(uuid, jsonb)', 'execute') then raise exception 'anon can apply'; end if;
end $$;

select 'chore_plan: all checks passed';
