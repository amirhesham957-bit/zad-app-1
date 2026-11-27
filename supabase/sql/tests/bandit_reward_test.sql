-- م٨.٢/م٨.٥ تغذية المكافأة (20261127110000). Scratch only:
--   psql < scratch_scaffold.sql ; psql < ...bandit_state.sql ; psql < ...bandit_reward_shown.sql ; psql < this
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$
declare u uuid := gen_random_uuid(); other uuid := gen_random_uuid(); m uuid := gen_random_uuid();
  n1 uuid := gen_random_uuid(); n2 uuid := gen_random_uuid(); n3 uuid := gen_random_uuid(); r boolean;
begin
  assert to_regclass('public.zad_bandit_shown') is not null, 'table missing';
  assert (select relrowsecurity from pg_class where oid = 'public.zad_bandit_shown'::regclass), 'rls off';
  assert not has_table_privilege('authenticated', 'public.zad_bandit_shown', 'select'), 'customers read shown';
  assert not has_table_privilege('authenticated', 'public.zad_bandit_shown', 'insert'), 'customers write shown';
  assert not has_table_privilege('service_role', 'public.zad_bandit_shown', 'insert'), 'service writes table directly';
  assert not has_function_privilege('authenticated', 'public.zad_bandit_settle_read(uuid,uuid)', 'execute'), 'customers settle';
  assert not has_function_privilege('anon', 'public.zad_bandit_note_shown(uuid,uuid,uuid,text,text)', 'execute'), 'anon notes';
  assert has_function_privilege('service_role', 'public.zad_bandit_settle_read(uuid,uuid)', 'execute'), 'service cannot settle';

  insert into public.app_notifications (id, user_id, title, message, is_read) values
    (n1, u, 't', 'm', false), (n2, u, 't', 'm', false), (n3, other, 't', 'm', true);

  assert public.zad_bandit_note_shown(u, m, n1, 'habit_budget', 'warm'), 'note failed';
  assert public.zad_bandit_note_shown(u, m, n1, 'habit_budget', 'base'), 'second note should be a quiet no-op';
  assert (select arm from public.zad_bandit_shown where notification_id = n1) = 'warm', 'first arm overwritten';
  -- إشعار حساب تاني ما يتسجلش
  assert not public.zad_bandit_note_shown(u, m, n3, 'habit_budget', 'warm'), 'foreign notification noted';

  -- لسه مااتقراش: مفيش تحديث
  assert not public.zad_bandit_settle_read(u, n1), 'unread settled';
  assert (select count(*) from public.zad_bandit_state) = 0, 'state moved without a read';

  update public.app_notifications set is_read = true where id = n1;
  assert not public.zad_bandit_settle_read(other, n1), 'wrong user settled';
  assert public.zad_bandit_settle_read(u, n1), 'read not settled';
  assert (select successes from public.zad_bandit_state where user_id = u and member_id = m and kind = 'habit_budget' and arm = 'warm') = 1, 'success not counted';
  assert (select failures from public.zad_bandit_state where user_id = u) = 0, 'failure counted';
  -- مكافأة واحدة بس لكل إشعار
  assert not public.zad_bandit_settle_read(u, n1), 'settled twice';
  assert (select successes from public.zad_bandit_state where user_id = u and arm = 'warm') = 1, 'double reward';

  -- إشعار تاني لنفس القالب يزوّد العداد
  assert public.zad_bandit_note_shown(u, m, n2, 'habit_budget', 'warm');
  update public.app_notifications set is_read = true where id = n2;
  assert public.zad_bandit_settle_read(u, n2);
  assert (select successes from public.zad_bandit_state where user_id = u and arm = 'warm') = 2, 'increment lost';
end $$;
rollback;
\echo bandit_reward_test: all checks passed
