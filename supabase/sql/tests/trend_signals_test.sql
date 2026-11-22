-- zad_trend_signals (20261123040000): >=5 houses, no person column, service role only. Scratch only:
--   chain: events_ledger_scaffold, events_ledger migration, trend_signals_scaffold, trend_signals migration, this file.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$ declare i int; u uuid; m uuid; r record;
begin
  -- ٦ بيوت بيضيفوا "رز" النهارده (بيت منهم عيلة من حسابين = بيت واحد)، و٤ بيوت بس "عدس".
  for i in 1..7 loop
    u := ('00000000-0000-0000-0000-00000000010' || i)::uuid;
    insert into auth.users values (u);
    insert into zad_users values (u, 'x' || i, 'EG');
    select id into m from zad_household_members where user_id = u and kind = 'self';
    if m is null then
      insert into zad_household_members (user_id, display_name, kind) values (u, 'أنا', 'self') returning id into m;
    end if;
    insert into zad_events (user_id, member_id, client_event_id, kind, payload, occurred_at, source)
      values (u, m, 'c' || i, 'shopping.added', jsonb_build_object('item_name', '  رز '), now(), 'manual');
    if i <= 4 then
      insert into zad_events (user_id, member_id, client_event_id, kind, payload, occurred_at, source)
        values (u, m, 'd' || i, 'shopping.added', jsonb_build_object('item_name', 'عدس'), now(), 'manual');
    end if;
  end loop;
  -- الحسابين 6 و7 نفس العيلة: ٧ حسابات = ٦ بيوت.
  insert into family_members (family_id, user_id) values
    ('aaaaaaaa-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000106'),
    ('aaaaaaaa-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000107');
  select * into r from zad_trend_signals();
  assert (select count(*) from zad_trend_signals()) = 1, 'only the 5+ house item may come out';
  select * into r from zad_trend_signals();
  assert r.item_key = 'رز' and r.country = 'EG' and r.houses = 6 and r.signal_count = 7, 'wrong aggregate: ' || r::text;
  assert not exists (select 1 from zad_trend_signals() t where t.item_key = 'عدس'), 'a 4-house item leaked';
  assert not exists (select 1 from information_schema.routines r2, information_schema.parameters p
     where r2.routine_name = 'zad_trend_signals' and p.specific_name = r2.specific_name and p.parameter_name in ('user_id','family_id','member_id')), 'person param';
  assert (select count(*) from pg_proc p, unnest(array['user_id','family_id','member_id']) c
     where p.proname = 'zad_trend_signals' and p.proargnames @> array[c]) = 0, 'person column in output';
  assert not has_function_privilege('authenticated', 'public.zad_trend_signals(int)', 'execute'), 'customers can call';
  assert not has_function_privilege('anon', 'public.zad_trend_signals(int)', 'execute');
  assert has_function_privilege('service_role', 'public.zad_trend_signals(int)', 'execute');
end $$;
rollback;
\echo trend_signals_test: all checks passed
