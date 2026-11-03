-- التسبيحة من غير عيلة (migration 20261103220000), on a scratch database:
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/tasbiha_without_family_scaffold.sql
--   psql < supabase/migrations/20261103220000_tasbiha_without_family.sql
--   psql < supabase/sql/tests/tasbiha_without_family_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

insert into auth.users values ('00000000-0000-0000-0000-0000000000f1'), ('00000000-0000-0000-0000-0000000000f2')
  on conflict do nothing;

begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);
set local role authenticated;
do $$
declare t public.family_tasbiha; n int;
begin
  -- 1. No family: my own tree can be planted, read and counted.
  insert into public.family_tasbiha (family_id, user_id) values (null, '00000000-0000-0000-0000-0000000000f1') returning * into t;
  select count(*) into n from public.family_tasbiha;
  assert n = 1, 'my tree is visible';
  t := public.increment_tasbiha_clicks_t(t.id, 3);
  assert t.score = 3 and t.total_clicks = 3, 'my taps count';
  raise notice 'ok: a customer with no family plants, reads and counts a tree';

  -- 2. A personal tree for someone else is refused.
  begin
    insert into public.family_tasbiha (family_id, user_id) values (null, '00000000-0000-0000-0000-0000000000f2');
    raise exception 'FAIL: planted a tree for someone else';
  exception when insufficient_privilege then raise notice 'ok: no tree for someone else';
  end;
end $$;
commit;

begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare n int; tid uuid;
begin
  -- 3. Another customer sees and counts nothing of it.
  select count(*) into n from public.family_tasbiha;
  assert n = 0, 'someone else''s personal tree is hidden';
  select id into tid from public.family_tasbiha limit 1;
  begin
    perform public.increment_tasbiha_clicks_t('00000000-0000-0000-0000-000000000000', 1);
    raise exception 'FAIL: counted an invisible tree';
  exception when raise_exception then
    if sqlerrm like 'FAIL%' then raise; end if;
    raise notice 'ok: another customer cannot see or count it';
  end;
end $$;
commit;

-- 4. Moving a personal tree into someone else's family is refused (the update check).
begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  begin
    update public.family_tasbiha set family_id = gen_random_uuid() where user_id = '00000000-0000-0000-0000-0000000000f1';
    raise exception 'FAIL: moved into a stranger family';
  exception when insufficient_privilege then raise notice 'ok: a tree cannot move into a stranger family';
  end;
end $$;
commit;
