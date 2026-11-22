-- م٦.٤ (20261123060000): مفاتيح أحداث الإشعارات والقراءات. Scratch only:
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261123060000_notification_events.sql
--   psql < supabase/sql/tests/notification_events_test.sql
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000a1'), ('00000000-0000-4000-8000-0000000000a2');

-- السيرفر (service role) يكتب قراءة لكل واحد.
set local role service_role;
insert into zad_notification_reads (user_id, kind, extracted) values
  ('00000000-0000-4000-8000-0000000000a1', 'appointment', '{"date":"2026-12-01","time":"10:30","place":"عيادة النور","title":"موعد دكتور"}'),
  ('00000000-0000-4000-8000-0000000000a2', 'trip', '{"date":null,"time":null,"place":null,"title":"رحلة طيران"}');
reset role;

do $$ declare u1 uuid := '00000000-0000-4000-8000-0000000000a1'; u2 uuid := '00000000-0000-4000-8000-0000000000a2'; n int; begin
  -- مفيش عمود نص خام ولا أي عمود غير المنظّم.
  assert (select array_agg(column_name::text order by column_name) from information_schema.columns
          where table_schema = 'public' and table_name = 'zad_notification_reads')
         = array['extracted', 'id', 'kind', 'read_at', 'user_id'], 'reads has an unexpected column';
  -- RLS مفعّلة.
  assert (select relrowsecurity from pg_class where oid = 'public.zad_notification_switches'::regclass), 'switches without RLS';
  assert (select relrowsecurity from pg_class where oid = 'public.zad_notification_reads'::regclass), 'reads without RLS';
  assert not has_table_privilege('anon', 'public.zad_notification_switches', 'select'), 'anon reads switches';
  assert not has_table_privilege('anon', 'public.zad_notification_reads', 'select'), 'anon reads reads';

  -- المستخدم الأول: يفتح ويقفل مفتاحه، الافتراضي مقفول.
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
  set local role authenticated;
  insert into zad_notification_switches (user_id, kind) values (u1, 'trip');
  assert (select enabled from zad_notification_switches where user_id = u1 and kind = 'trip') = false, 'default is not off';
  update zad_notification_switches set enabled = true, enabled_at = now() where user_id = u1 and kind = 'trip';
  assert (select enabled from zad_notification_switches where user_id = u1 and kind = 'trip'), 'own switch did not turn on';
  begin
    insert into zad_notification_switches (user_id, kind) values (u1, 'bank');
    raise exception 'unknown kind accepted';
  exception when check_violation then null; end;
  begin
    insert into zad_notification_switches (user_id, kind) values (u2, 'appointment');
    raise exception 'wrote a switch for someone else';
  exception when insufficient_privilege then null; end;
  -- قراءاته بس.
  select count(*) into n from zad_notification_reads;
  assert n = 1, 'reads leaked across users: ' || n;
  assert (select kind from zad_notification_reads) = 'appointment';
  -- مفيش كتابة ولا مسح للقراءات ولا مسح للمفاتيح من العميل.
  begin
    insert into zad_notification_reads (user_id, kind, extracted) values (u1, 'trip', '{}');
    raise exception 'a customer inserted a read';
  exception when insufficient_privilege then null; end;
  begin
    delete from zad_notification_switches where user_id = u1;
    raise exception 'a customer deleted a switch';
  exception when insufficient_privilege then null; end;
  reset role;

  -- المستخدم التاني: مايشوفش ولا يعدّل مفتاح الأول.
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', true);
  set local role authenticated;
  assert (select count(*) from zad_notification_switches) = 0, 'switch visible to another user';
  update zad_notification_switches set enabled = false where user_id = u1;
  get diagnostics n = row_count;
  assert n = 0, 'updated another user''s switch';
  assert (select kind from zad_notification_reads) = 'trip', 'second user reads wrong rows';
  reset role;
end $$;
rollback;
\echo notification_events_test: all checks passed
