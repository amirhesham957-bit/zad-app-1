-- م٥.٢: اللي 20261122160000 محتاجاه فوق scratch_scaffold.sql: zad_is_family_admin (زي 20260921130000)، وعيلتين.
\set ON_ERROR_STOP on

create or replace function public.zad_is_family_admin(p_family uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.family_members where family_id = p_family and user_id = auth.uid() and role = 'admin');
$$;

-- F: أب (admin) وبنت (member). G: عيلة تانية.
insert into public.family_groups (id) values ('f0000000-0000-0000-0000-00000000000f'), ('f0000000-0000-0000-0000-0000000000a0');
insert into public.family_members (id, family_id, user_id, role, alias) values
  ('a0000000-0000-0000-0000-0000000000a1', 'f0000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000000a1', 'admin', 'بابا'),
  ('b0000000-0000-0000-0000-0000000000b1', 'f0000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000000b1', 'member', 'سارة'),
  ('d0000000-0000-0000-0000-0000000000d1', 'f0000000-0000-0000-0000-0000000000a0', '00000000-0000-0000-0000-0000000000d1', 'admin', 'غريب');
insert into public.family_chores (id, family_id, assigned_to, title, is_completed) values
  ('c0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-00000000000f', 'a0000000-0000-0000-0000-0000000000a1', 'غسيل المواعين', false),
  ('c0000000-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-00000000000f', 'a0000000-0000-0000-0000-0000000000a1', 'كنس الصالة', false),
  ('c0000000-0000-0000-0000-000000000003', 'f0000000-0000-0000-0000-00000000000f', 'a0000000-0000-0000-0000-0000000000a1', 'رمي الزبالة', true),
  ('c0000000-0000-0000-0000-0000000000d1', 'f0000000-0000-0000-0000-0000000000a0', 'd0000000-0000-0000-0000-0000000000d1', 'شغل بيت تاني', false);
