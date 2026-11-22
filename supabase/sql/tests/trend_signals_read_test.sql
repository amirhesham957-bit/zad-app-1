-- zad_trend_signals (20261123090000): aggregates only, 5-household floor, server only. Scratch only:
--   psql < supabase/sql/tests/events_ledger_scaffold.sql
--   psql < supabase/migrations/20261121160000_events_ledger.sql
--   psql < supabase/migrations/20261123090000_trend_signals_read.sql
--   psql < supabase/sql/tests/trend_signals_read_test.sql
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$ declare r record; n int; i int; u uuid; d date := (now() at time zone 'utc')::date; begin
  -- 6 households add "لبن" today (household 1 adds it 10 times -> capped at 3); 4 add "رز" today.
  for i in 1..6 loop
    u := ('a0000000-0000-0000-0000-00000000000' || i)::uuid;
    insert into auth.users values (u);
    insert into zad_users values (u, 'h' || i);
    insert into zad_events (user_id, member_id, client_event_id, kind, payload, occurred_at, source)
      select u, zad_self_member(u), 'n' || i || '-' || g, 'shopping.added',
             jsonb_build_object('item_name', case when g = 1 then ' لبن ' else 'لبن' end), now(), 'manual'
        from generate_series(1, case when i = 1 then 10 else 1 end) g;
    if i <= 4 then
      insert into zad_events (user_id, member_id, client_event_id, kind, payload, occurred_at, source)
        values (u, zad_self_member(u), 'r' || i, 'shopping.added', '{"item_name":"رز"}', now(), 'manual');
    end if;
  end loop;
  -- baseline: 14 earlier days with one لبن add each; and an unrelated kind that must be ignored.
  insert into zad_events (user_id, member_id, client_event_id, kind, payload, occurred_at, source)
    select 'a0000000-0000-0000-0000-000000000001', zad_self_member('a0000000-0000-0000-0000-000000000001'),
           'b' || g, 'shopping.added', '{"item_name":"لبن"}', now() - (g || ' days')::interval, 'manual'
      from generate_series(1, 14) g;
  insert into zad_events (user_id, member_id, client_event_id, kind, payload, occurred_at, source)
    values ('a0000000-0000-0000-0000-000000000002', zad_self_member('a0000000-0000-0000-0000-000000000002'),
            'x1', 'expense.logged', '{"item_name":"لبن"}', now(), 'manual');

  select count(*) into n from zad_trend_signals();
  assert n = 1, 'only the item with >=5 households today is returned, got ' || n;
  select * into r from zad_trend_signals() where item_key = 'لبن';
  assert r.houses = 6, 'distinct households: ' || r.houses;
  assert r.today_count = 3 + 5, 'per-household cap of 3: ' || r.today_count;
  assert r.baseline = round(14 / 28.0, 3), 'baseline daily mean: ' || r.baseline;
  assert not exists (select 1 from zad_trend_signals() where item_key = 'رز'), 'below floor hidden';
  select count(*) into n from zad_trend_signals(d - 5);
  assert n = 0, 'a day with no signals returns nothing';
  assert not exists (
    select 1 from pg_proc p, unnest(p.proargnames) a
     where p.proname = 'zad_trend_signals' and a in ('id', 'user_id', 'family_id', 'member_id', 'occurred_at')
  ), 'output leaks a person';
  assert not has_function_privilege('authenticated', 'public.zad_trend_signals(date,integer)', 'execute'), 'customers can call';
  assert not has_function_privilege('anon', 'public.zad_trend_signals(date,integer)', 'execute');
  assert has_function_privilege('service_role', 'public.zad_trend_signals(date,integer)', 'execute');
end $$;
rollback;
\echo trend_signals_read_test: all checks passed
