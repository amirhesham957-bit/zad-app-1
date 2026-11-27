-- م٧.٨ عروض مدّ الهدف (20261127120000). Scratch only:
--   events_ledger_scaffold ; events_ledger ; goal_offers_scaffold ; goal_offers ; this
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
begin;
do $$
declare u uuid := '11111111-1111-1111-1111-111111111111'; v uuid := '22222222-2222-2222-2222-222222222222';
  ga uuid := gen_random_uuid(); gb uuid := gen_random_uuid(); gk uuid := gen_random_uuid();
  kid uuid := gen_random_uuid(); r jsonb; off uuid;
begin
  assert (select relrowsecurity from pg_class where oid = 'public.zad_goal_offers'::regclass), 'rls off';
  assert not has_table_privilege('authenticated', 'public.zad_goal_offers', 'select'), 'customers read offers';
  assert not has_table_privilege('service_role', 'public.zad_goal_offers', 'insert'), 'service writes table directly';
  assert not has_function_privilege('authenticated', 'public.zad_goal_offer_consume(uuid,uuid)', 'execute'), 'customers consume';
  assert not has_function_privilege('anon', 'public.zad_goal_offer_record(uuid,uuid,date)', 'execute'), 'anon records';
  assert has_function_privilege('service_role', 'public.zad_goal_offer_consume(uuid,uuid)', 'execute'), 'service cannot consume';

  insert into public.zad_household_members (id, user_id, display_name, kind) values (kid, u, 'طفل', 'child');
  insert into public.agent_goals (id, user_id, title) values (ga, u, 'A'), (gb, u, 'B');
  insert into public.agent_goals (id, user_id, title, member_id) values (gk, u, 'K', kid);

  -- no offer: nothing to consume
  assert public.zad_goal_offer_consume(u, ga) ->> 'status' = 'none', 'consumed without offer';
  -- record: new, then same deadline is not new
  r := public.zad_goal_offer_record(u, ga, '2027-03-01');
  assert (r ->> 'ok')::boolean and (r ->> 'is_new')::boolean, 'first record not new';
  r := public.zad_goal_offer_record(u, ga, '2027-03-01');
  assert not (r ->> 'is_new')::boolean, 'same offer recorded as new';
  -- other user's goal, missing goal, child goal refused
  assert public.zad_goal_offer_record(v, ga, '2027-03-01') ->> 'reason' = 'goal_not_found', 'foreign goal';
  assert public.zad_goal_offer_record(u, gen_random_uuid(), '2027-03-01') ->> 'reason' = 'goal_not_found', 'missing goal';
  assert public.zad_goal_offer_record(u, gk, '2027-03-01') ->> 'reason' = 'child_member', 'child offered';
  -- offer for A cannot be consumed as B
  assert public.zad_goal_offer_consume(u, gb) ->> 'status' = 'none', 'B consumed on A offer';
  assert public.zad_goal_offer_consume(v, ga) ->> 'status' = 'none', 'other user consumed';
  -- consume once
  r := public.zad_goal_offer_consume(u, ga);
  assert r ->> 'status' = 'ok' and (r ->> 'deadline') = '2027-03-01', 'consume failed';
  off := (r ->> 'offer_id')::uuid;
  assert public.zad_goal_offer_consume(u, ga) ->> 'status' = 'consumed', 'consumed twice';
  -- release reopens
  assert public.zad_goal_offer_release(u, off), 'release failed';
  assert public.zad_goal_offer_consume(u, ga) ->> 'status' = 'ok', 'released offer not usable';
  -- expiry
  r := public.zad_goal_offer_record(u, gb, '2027-04-01');
  update public.zad_goal_offers set expires_at = now() - interval '1 minute' where goal_id = gb;
  assert public.zad_goal_offer_consume(u, gb) ->> 'status' = 'expired', 'expired consumed';
  -- a new record after expiry replaces the stale one and is new
  r := public.zad_goal_offer_record(u, gb, '2027-04-01');
  assert (r ->> 'is_new')::boolean, 'expired not replaced';
  -- changed deadline = new offer
  r := public.zad_goal_offer_record(u, gb, '2027-05-01');
  assert (r ->> 'is_new')::boolean, 'changed deadline not new';
  assert public.zad_goal_offer_consume(u, gb) ->> 'deadline' = '2027-05-01', 'old deadline kept';
  -- child goal consume refused even if a row was planted
  insert into public.zad_goal_offers (user_id, goal_id, deadline) values (u, gk, '2027-03-01');
  assert public.zad_goal_offer_consume(u, gk) ->> 'status' = 'child_member', 'child consumed';
end $$;
rollback;
\echo goal_offers_test: all checks passed
