-- Run after scratch_scaffold.sql, 20261104190000_device_send_keys.sql and
-- 20261128180000_device_key_rate.sql.
\set ON_ERROR_STOP on
begin;
do $$
declare
  u uuid := gen_random_uuid();
  h text := repeat('a', 64);
  h2 text := repeat('b', 64);
  ok boolean;
begin
  insert into auth.users (id) values (u);
  insert into public.zad_device_send_keys (key_hash, user_id) values (h, u), (h2, u);

  assert (select relrowsecurity from pg_class where oid = 'public.zad_device_key_rate'::regclass), 'rls off';
  assert not has_table_privilege('authenticated', 'public.zad_device_key_rate', 'select'), 'customers read rate';
  assert not has_function_privilege('authenticated', 'public.zad_device_key_hit(text,integer)', 'execute'), 'customers call hit';
  assert has_function_privilege('service_role', 'public.zad_device_key_hit(text,integer)', 'execute'), 'service cannot call hit';

  for i in 1..3 loop
    assert public.zad_device_key_hit(h, 3), 'call ' || i || ' within limit refused';
  end loop;
  assert not public.zad_device_key_hit(h, 3), 'fourth call allowed';
  assert not public.zad_device_key_hit(h, 3), 'fifth call allowed';
  assert public.zad_device_key_hit(h2, 3), 'another key is limited by the first';

  -- an old window is dropped on the next hit
  insert into public.zad_device_key_rate (key_hash, hour_start, calls) values (h2, now() - interval '5 hours', 99);
  perform public.zad_device_key_hit(h2, 3);
  assert not exists (select 1 from public.zad_device_key_rate where key_hash = h2 and calls = 99), 'old window kept';

  -- rows go with the key
  delete from public.zad_device_send_keys where key_hash = h;
  assert not exists (select 1 from public.zad_device_key_rate where key_hash = h), 'rate rows outlive key';
end $$;
rollback;
\echo device_key_rate_test: all checks passed
