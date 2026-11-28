-- On top of scratch_scaffold.sql + view_rpcs_scaffold.sql + visibility_matrix_scaffold.sql: the other zad_users budget columns
-- (live shape) that the P2.5b mirror reads. Scratch only.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
alter table public.zad_users
  add column if not exists budget double precision default 0,
  add column if not exists emergency_fund_balance numeric not null default 0,
  add column if not exists cycle_anchor text not null default 'day_of_month',
  add column if not exists cycle_start_day int,
  add column if not exists limit_confirmed_at timestamptz,
  add column if not exists balance_anchored_at timestamptz,
  add column if not exists travel_budget numeric;

-- Seed BEFORE the migration so its backfill has rows to copy. a = admin parent, b = adult, k = child account, o = other family.
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-0000000000d1'), ('00000000-0000-0000-0000-0000000000e1');
insert into public.family_groups (id) values ('00000000-0000-0000-0000-0000000000f1'), ('00000000-0000-0000-0000-0000000000f2');
insert into public.family_members (id, family_id, user_id, role) values
  (gen_random_uuid(), '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'admin'),
  (gen_random_uuid(), '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000b1', 'member'),
  (gen_random_uuid(), '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000d1', 'child'),
  (gen_random_uuid(), '00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000e1', 'admin');
insert into public.zad_users (id, monthly_limit) values ('00000000-0000-0000-0000-0000000000a1', 5000), ('00000000-0000-0000-0000-0000000000b1', 3000),
  ('00000000-0000-0000-0000-0000000000d1', 50), ('00000000-0000-0000-0000-0000000000e1', 777);
