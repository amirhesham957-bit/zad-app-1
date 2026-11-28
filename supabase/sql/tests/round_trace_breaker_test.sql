-- Run after scratch_scaffold.sql and 20261128200000_round_trace_engine_breaker.sql.
\set ON_ERROR_STOP on
begin;
do $$
declare
  st text;
  gate jsonb;
  n integer;
begin
  -- RLS on, customers cannot read or write, only service_role can call the functions
  assert (select relrowsecurity from pg_class where oid = 'public.zad_round_trace'::regclass), 'trace rls off';
  assert (select relrowsecurity from pg_class where oid = 'public.zad_engine_breaker'::regclass), 'breaker rls off';
  assert not has_table_privilege('authenticated', 'public.zad_round_trace', 'select'), 'customers read trace';
  assert not has_table_privilege('authenticated', 'public.zad_round_trace', 'insert'), 'customers write trace';
  assert not has_table_privilege('anon', 'public.zad_engine_breaker', 'select'), 'anon reads breaker';
  assert not has_table_privilege('authenticated', 'public.zad_engine_breaker', 'update'), 'customers write breaker';
  assert not exists (select 1 from pg_policies where schemaname = 'public' and tablename in ('zad_round_trace', 'zad_engine_breaker')), 'a policy exists';
  assert not has_function_privilege('authenticated', 'public.zad_engine_record_result(text,text,timestamptz,integer,boolean,text,integer)', 'execute'), 'customers record';
  assert not has_function_privilege('anon', 'public.zad_engine_is_open(text[],integer)', 'execute'), 'anon gate';
  assert not has_function_privilege('authenticated', 'public.zad_round_mark(text,text)', 'execute'), 'customers mark';
  assert has_function_privilege('service_role', 'public.zad_engine_record_result(text,text,timestamptz,integer,boolean,text,integer)', 'execute'), 'service cannot record';
  assert has_function_privilege('service_role', 'public.zad_engine_is_open(text[],integer)', 'execute'), 'service cannot gate';
  assert has_function_privilege('service_role', 'public.zad_round_mark(text,text)', 'execute'), 'service cannot mark';

  -- closed: no row, then two failures stay under the threshold of 3
  assert public.zad_engine_is_open(array['gemini:m1'], 300) = '{}'::jsonb, 'unknown engine not closed';
  st := public.zad_engine_record_result('gemini:m1', 'trace0001', now(), 120, false, '503');
  assert st = 'closed', 'one failure opened it';
  st := public.zad_engine_record_result('gemini:m1', 'trace0001', now(), 120, false, '503');
  assert st = 'closed', 'two failures opened it';
  assert public.zad_engine_is_open(array['gemini:m1'], 300) = '{}'::jsonb, 'open below threshold';

  -- a success resets the run of failures
  perform public.zad_engine_record_result('gemini:m1', 'trace0002', now(), 80, true);
  perform public.zad_engine_record_result('gemini:m1', 'trace0003', now(), 80, false);
  st := public.zad_engine_record_result('gemini:m1', 'trace0003', now(), 80, false);
  assert st = 'closed', 'success did not reset the count';

  -- third failure in a row opens it
  st := public.zad_engine_record_result('gemini:m1', 'trace0003', now(), 80, false);
  assert st = 'open', 'threshold did not open';
  gate := public.zad_engine_is_open(array['gemini:m1', 'groq:g1'], 300);
  assert gate = '{"gemini:m1": "open"}'::jsonb, 'open engine not reported: ' || gate::text;

  -- engines are independent
  assert public.zad_engine_record_result('groq:g1', null, now(), 5, true) = 'closed', 'groq not closed';

  -- cooldown over: first caller probes (half_open), the next still sees open
  update public.zad_engine_breaker set opened_at = now() - interval '10 minutes' where engine = 'gemini:m1';
  gate := public.zad_engine_is_open(array['gemini:m1'], 300);
  assert gate = '{"gemini:m1": "half_open"}'::jsonb, 'no half_open probe: ' || gate::text;
  gate := public.zad_engine_is_open(array['gemini:m1'], 300);
  assert gate = '{"gemini:m1": "open"}'::jsonb, 'second caller also probes: ' || gate::text;

  -- a failed probe keeps it open; a good probe closes it
  st := public.zad_engine_record_result('gemini:m1', null, now(), 80, false);
  assert st = 'open', 'failed probe closed it';
  perform public.zad_engine_record_result('gemini:m1', null, now(), 80, true);
  assert public.zad_engine_is_open(array['gemini:m1'], 300) = '{}'::jsonb, 'good probe did not close';

  -- trace rows: outcome from the call, then edited/reverted by the user
  assert (select count(*) from public.zad_round_trace where trace_id = 'trace0002' and outcome = 'accepted') = 1, 'ok not accepted';
  assert (select count(*) from public.zad_round_trace where trace_id = 'trace0003' and outcome = 'error') = 3, 'failures not error';
  n := public.zad_round_mark('trace0002', 'reverted');
  assert n = 1, 'mark changed ' || n;
  assert (select outcome from public.zad_round_trace where trace_id = 'trace0002') = 'reverted', 'not reverted';
  assert public.zad_round_mark('trace0002', 'accepted') = 0, 'accepted is not a mark';
  assert public.zad_round_mark(null, 'edited') = 0, 'null trace marked';
  assert public.zad_round_mark('trace0003', 'edited') = 0, 'error row re-marked';

  -- the outcome is constrained
  begin
    insert into public.zad_round_trace (engine, outcome) values ('x', 'weird');
    assert false, 'bad outcome accepted';
  exception when check_violation then null;
  end;
end $$;
rollback;
\echo round_trace_breaker_test: all checks passed
