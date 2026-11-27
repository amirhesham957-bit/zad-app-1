-- م٨ قاعدة الفشل (20261127120000). Scratch only:
--   psql < scratch_scaffold.sql ; ...bandit_state.sql ; ...bandit_reward_shown.sql ; ...bandit_failure.sql ; psql < this
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$
declare u uuid := gen_random_uuid(); other uuid := gen_random_uuid(); m uuid := gen_random_uuid();
  n_old uuid := gen_random_uuid(); n_new uuid := gen_random_uuid(); n_read uuid := gen_random_uuid();
  n_gone uuid := gen_random_uuid(); n_rew uuid := gen_random_uuid();
begin
  assert not has_function_privilege('authenticated', 'public.zad_bandit_settle_failure(uuid,uuid)', 'execute'), 'customers fail';
  assert not has_function_privilege('anon', 'public.zad_bandit_settle_failure(uuid,uuid)', 'execute'), 'anon fails';
  assert has_function_privilege('service_role', 'public.zad_bandit_settle_failure(uuid,uuid)', 'execute'), 'service cannot fail';

  insert into public.app_notifications (id, user_id, title, message, is_read) values
    (n_old, u, 't', 'm', false), (n_new, u, 't', 'm', false), (n_read, u, 't', 'm', true), (n_rew, u, 't', 'm', false);
  perform public.zad_bandit_note_shown(u, m, n_old, 'habit_budget', 'warm');
  perform public.zad_bandit_note_shown(u, m, n_new, 'habit_budget', 'warm');
  perform public.zad_bandit_note_shown(u, m, n_read, 'habit_budget', 'warm');
  perform public.zad_bandit_note_shown(u, m, n_rew, 'habit_budget', 'warm');
  perform public.zad_bandit_note_shown(u, m, n_gone, 'habit_budget', 'warm') ; -- إشعار مش موجود: مايتسجلش
  update public.zad_bandit_shown set shown_at = now() - interval '25 hours' where notification_id in (n_old, n_read, n_rew);
  update public.zad_bandit_shown set shown_at = now() - interval '23 hours' where notification_id = n_new;

  -- أقل من ٢٤ ساعة: مفيش فشل
  assert not public.zad_bandit_settle_failure(u, n_new), 'failed before 24h';
  assert (select settled_at is null from public.zad_bandit_shown where notification_id = n_new), 'young row closed';
  -- حساب تاني مايقفلش
  assert not public.zad_bandit_settle_failure(other, n_old), 'wrong user failed';
  -- اتقرا في الوقت: مفيش فشل
  assert not public.zad_bandit_settle_failure(u, n_read), 'read notification failed';
  assert (select count(*) from public.zad_bandit_state) = 0, 'state moved without a failure';

  -- أكتر من ٢٤ ساعة ومقروء-لا: فشل مرة واحدة
  assert public.zad_bandit_settle_failure(u, n_old), 'old unread not failed';
  assert (select failures from public.zad_bandit_state where user_id = u and member_id = m and kind = 'habit_budget' and arm = 'warm') = 1, 'failure not counted';
  assert (select successes from public.zad_bandit_state where user_id = u) = 0, 'success counted on failure';
  assert (select outcome from public.zad_bandit_shown where notification_id = n_old) = 'failure', 'outcome missing';
  assert (select settled_at is not null from public.zad_bandit_shown where notification_id = n_old), 'not closed';
  assert not public.zad_bandit_settle_failure(u, n_old), 'failed twice';

  -- قراية متأخرة بعد الفشل: مفيش مكافأة
  update public.app_notifications set is_read = true where id = n_old;
  assert not public.zad_bandit_settle_read(u, n_old), 'late read rewarded after failure';
  assert (select successes from public.zad_bandit_state where user_id = u and arm = 'warm') = 0, 'late read moved posterior';
  assert (select failures from public.zad_bandit_state where user_id = u and arm = 'warm') = 1, 'failure lost';

  -- المكافأة بتعلّم outcome، وبعدها مفيش فشل
  update public.app_notifications set is_read = true where id = n_rew;
  assert public.zad_bandit_settle_read(u, n_rew), 'read not rewarded';
  assert (select outcome from public.zad_bandit_shown where notification_id = n_rew) = 'reward', 'reward outcome missing';
  update public.app_notifications set is_read = false where id = n_rew;
  assert not public.zad_bandit_settle_failure(u, n_rew), 'rewarded row failed after';
  assert (select failures from public.zad_bandit_state where user_id = u and arm = 'warm') = 1, 'extra failure';
  assert (select successes from public.zad_bandit_state where user_id = u and arm = 'warm') = 1, 'reward lost';

  -- إشعار اتمسح: مفيش فشل
  insert into public.zad_bandit_shown (notification_id, user_id, member_id, kind, arm, shown_at)
  values (n_gone, u, m, 'habit_budget', 'warm', now() - interval '30 hours') on conflict do nothing;
  assert not public.zad_bandit_settle_failure(u, n_gone), 'deleted notification failed';
end $$;
rollback;
\echo bandit_failure_test: all checks passed
