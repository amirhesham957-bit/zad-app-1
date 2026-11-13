-- What 20261113120000_old_grocery_orphans.sql reads beyond scratch_scaffold.sql, as live 2026-11-13, with rows.
create table public.shared_grocery_list (
  id uuid primary key default gen_random_uuid(), family_id uuid, added_by text, item_name text,
  category text, is_purchased boolean default false, created_at timestamptz default now());
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1') on conflict do nothing;
insert into public.family_groups (id) values ('00000000-0000-0000-0000-00000000f001'), ('00000000-0000-0000-0000-00000000f002');
insert into public.family_members (family_id, user_id) values ('00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-0000000000a1');
insert into public.shared_grocery_list (family_id, added_by, item_name) values
  ('00000000-0000-0000-0000-00000000f002', '00000000-0000-0000-0000-0000000000ff', 'يتيم'),
  ('00000000-0000-0000-0000-00000000f001', '00000000-0000-0000-0000-0000000000ff', 'عيلة فيها حد'),
  ('00000000-0000-0000-0000-00000000f002', '00000000-0000-0000-0000-0000000000a1', 'صاحبه موجود');
