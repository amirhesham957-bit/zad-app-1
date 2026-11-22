-- zad_kill_switches + مغلفات الطابور (20261123150000). Scratch only:
--   psql < supabase/sql/tests/scratch_scaffold.sql ; psql < ...job_queue.sql ; psql < this
-- pgmq ممكن مايكونش موجود في السكراتش: اختبار الطابور نفسه بيتخطى.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$ begin
  perform public.zad_set_kill_switch('pause_all', false, 'test');
  assert (select enabled from zad_kill_switches where key = 'pause_all') = false, 'switch not stored';
  perform public.zad_set_kill_switch('pause_all', true);
  assert (select enabled from zad_kill_switches where key = 'pause_all') = true and (select reason from zad_kill_switches where key = 'pause_all') is null, 'switch not updated';
  begin perform public.zad_set_kill_switch('', true); raise exception 'bad key kept';
  exception when raise_exception then assert sqlerrm = 'bad_key', sqlerrm; end;
  assert (select relrowsecurity from pg_class where oid = 'public.zad_kill_switches'::regclass), 'rls off';
  assert not has_table_privilege('authenticated', 'public.zad_kill_switches', 'select'), 'customers read switches';
  assert not has_table_privilege('anon', 'public.zad_kill_switches', 'insert');
  assert not has_function_privilege('authenticated', 'public.zad_enqueue_job(text,jsonb,integer)', 'execute'), 'customers enqueue';
  assert not has_function_privilege('anon', 'public.zad_dequeue_jobs(text,integer,integer)', 'execute');
  assert not has_function_privilege('authenticated', 'public.zad_ack_job(text,bigint)', 'execute');
  assert not has_function_privilege('authenticated', 'public.zad_set_kill_switch(text,boolean,text)', 'execute');
  if exists (select 1 from pg_extension where extname = 'pgmq') then
    begin perform public.zad_enqueue_job('other', '{}'::jsonb); raise exception 'bad queue kept';
    exception when raise_exception then assert sqlerrm = 'bad_queue', sqlerrm; end;
    perform public.zad_enqueue_job('zad_jobs', '{"kind":"x"}'::jsonb, 0);
    assert (select count(*) from public.zad_dequeue_jobs('zad_jobs', 30, 5)) = 1, 'dequeue failed';
  else
    raise notice 'pgmq absent: queue round-trip skipped';
  end if;
end $$;
rollback;
\echo job_queue_test: all checks passed
