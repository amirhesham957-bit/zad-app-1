-- Migration 20261012090000: the three cost holes. Run after cost_holes_scaffold.sql and the
-- migrations it lists. Each block raises on the first wrong value.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

-- ١. The same token, again and again, refills nothing; a new period from Google does.
do $$
declare
  a uuid := '00000000-0000-0000-0000-00000000000a';
  e1 timestamptz := now() + interval '30 days';
  r jsonb;
  e public.zad_entitlements;
begin
  r := public.zad_set_tier(a, 'starter', e1);
  select * into e from public.zad_entitlements where user_id = a;
  assert e.tier = 'starter' and e.chat_left = 300 and (r->>'refilled')::boolean, 'first purchase fills the month: ' || r::text;

  update public.zad_entitlements set chat_left = 10 where user_id = a;
  for i in 1..5 loop
    r := public.zad_set_tier(a, 'starter', e1);
  end loop;
  select * into e from public.zad_entitlements where user_id = a;
  assert e.chat_left = 10, 'the same token five times must not refill, got ' || e.chat_left;
  assert not (r->>'refilled')::boolean and (r->>'applied')::boolean, 'same token: applied, not refilled: ' || r::text;

  -- Google renewed: the expiry moves a month on.
  r := public.zad_set_tier(a, 'starter', e1 + interval '30 days');
  select * into e from public.zad_entitlements where user_id = a;
  assert e.chat_left = 300 and e.tier_expires_at = e1 + interval '30 days', 'a renewal refills: ' || r::text;

  -- An earlier expiry (a shortened period) is recorded but refills nothing.
  update public.zad_entitlements set chat_left = 7 where user_id = a;
  r := public.zad_set_tier(a, 'starter', e1);
  select * into e from public.zad_entitlements where user_id = a;
  assert e.chat_left = 7 and e.tier_expires_at = e1, 'a shorter expiry: recorded, no refill: ' || r::text;
end $$;

-- ١ب. An upgrade refills; a lower plan bought beside an active higher one does not replace it.
do $$
declare
  a uuid := '00000000-0000-0000-0000-00000000000a';
  r jsonb;
  e public.zad_entitlements;
begin
  r := public.zad_set_tier(a, 'plus', now() + interval '30 days');
  select * into e from public.zad_entitlements where user_id = a;
  assert e.tier = 'plus' and e.chat_left = 1000, 'an upgrade refills at the new plan: ' || r::text;

  update public.zad_entitlements set chat_left = 400 where user_id = a;
  r := public.zad_set_tier(a, 'starter', now() + interval '60 days');
  select * into e from public.zad_entitlements where user_id = a;
  assert e.tier = 'plus' and e.chat_left = 400, 'a lower plan beside an active higher one changes nothing';
  assert not (r->>'applied')::boolean and r->>'tier' = 'plus', 'and says so, so verify-purchase keeps the token: ' || r::text;

  -- Alternating the two tokens refills nothing either.
  for i in 1..3 loop
    perform public.zad_set_tier(a, 'starter', now() + interval '60 days');
    perform public.zad_set_tier(a, 'plus', e.tier_expires_at);
  end loop;
  select * into e from public.zad_entitlements where user_id = a;
  assert e.chat_left = 400, 'alternating plus/starter must not refill, got ' || e.chat_left;
end $$;

-- ١ج. Down to free: the free allowance on the five-hour cycle (it used to be a month), once.
do $$
declare
  a uuid := '00000000-0000-0000-0000-00000000000a';
  r jsonb;
  e public.zad_entitlements;
begin
  r := public.zad_set_tier(a, 'free', null);
  select * into e from public.zad_entitlements where user_id = a;
  assert e.tier = 'free' and e.chat_left = 5 and e.tier_expires_at is null, 'revoked to free: ' || r::text;
  assert e.cycle_reset_at <= now() + interval '5 hours' and e.cycle_reset_at > now() + interval '4 hours',
    'free refills in five hours, not a month: ' || e.cycle_reset_at;

  update public.zad_entitlements set chat_left = 2 where user_id = a;
  r := public.zad_set_tier(a, 'free', null);
  select * into e from public.zad_entitlements where user_id = a;
  assert e.chat_left = 2 and not (r->>'applied')::boolean, 'free again changes nothing: ' || r::text;
end $$;

-- ١د. A lapsed plan bought again: refresh drops it to free first, so it is a fresh purchase.
do $$
declare
  a uuid := '00000000-0000-0000-0000-00000000000a';
  e public.zad_entitlements;
begin
  perform public.zad_set_tier(a, 'starter', now() + interval '30 days');
  update public.zad_entitlements set chat_left = 0, tier_expires_at = now() - interval '1 minute' where user_id = a;
  perform public.zad_set_tier(a, 'starter', now() + interval '30 days');
  select * into e from public.zad_entitlements where user_id = a;
  assert e.tier = 'starter' and e.chat_left = 300, 'a lapsed plan bought again refills';
end $$;

-- ٢. A refund gives back exactly what consume took.
do $$
declare
  b uuid := '00000000-0000-0000-0000-00000000000b';
  c jsonb;
  e public.zad_entitlements;
begin
  perform public.zad_entitlement_refresh(b);
  update public.zad_entitlements set chat_left = 3, cycle_reset_at = now() + interval '1 hour' where user_id = b;
  c := public.zad_entitlement_consume(b, 'scan', 'UTC');
  assert (c->>'allowed')::boolean and c->>'reason' = 'quota' and (c->>'left')::int = 1, 'a scan costs two: ' || c;
  c := public.zad_entitlement_consume(b, 'scan', 'UTC');
  assert not (c->>'allowed')::boolean, 'one attempt is not a scan: ' || c;
  perform public.zad_entitlement_refund(b, 'scan');
  select * into e from public.zad_entitlements where user_id = b;
  assert e.chat_left = 3, 'the empty scan is refunded, got ' || e.chat_left;

  perform public.zad_entitlement_refund(b, 'voice');
  select * into e from public.zad_entitlements where user_id = b;
  assert e.voice_left = 1 and e.chat_left = 3, 'voice refunds its own counter';
  perform public.zad_entitlement_refund(b, 'nonsense');
  select * into e from public.zad_entitlements where user_id = b;
  assert e.chat_left = 3 and e.voice_left = 1, 'an unknown kind refunds nothing';
end $$;

-- ٢ب. The rate gate: per minute, per day, a new minute and a new day open it again.
do $$
declare
  b uuid := '00000000-0000-0000-0000-00000000000b';
  r jsonb;
begin
  assert (public.zad_rate_take(b, 'vision', 2, 5)->>'ok')::boolean, '1st';
  assert (public.zad_rate_take(b, 'vision', 2, 5)->>'ok')::boolean, '2nd';
  r := public.zad_rate_take(b, 'vision', 2, 5);
  assert not (r->>'ok')::boolean and r->>'reason' = 'minute', '3rd in a minute: ' || r::text;
  assert (public.zad_rate_take(b, 'voice', 2, 5)->>'ok')::boolean, 'another bucket is its own count';

  update public.zad_rate_gate set minute_start = now() - interval '61 seconds' where user_id = b and bucket = 'vision';
  assert (public.zad_rate_take(b, 'vision', 2, 5)->>'ok')::boolean, 'a new minute opens it';
  assert (select day_count from public.zad_rate_gate where user_id = b and bucket = 'vision') = 3,
    'refused calls are not counted';

  update public.zad_rate_gate set day_count = 5, minute_start = now() - interval '2 minutes' where user_id = b and bucket = 'vision';
  r := public.zad_rate_take(b, 'vision', 2, 5);
  assert not (r->>'ok')::boolean and r->>'reason' = 'day', 'the day cap: ' || r::text;

  update public.zad_rate_gate set day = day - 1 where user_id = b and bucket = 'vision';
  assert (public.zad_rate_take(b, 'vision', 2, 5)->>'ok')::boolean, 'a new day opens it';
end $$;

-- ٣. Who may call what.
do $$
declare
  f text;
begin
  foreach f in array array['zad_ad_reward_grant(uuid)', 'zad_media_pass_grant(uuid)', 'zad_set_tier(uuid,text,timestamptz)',
                           'zad_entitlement_refund(uuid,text)', 'zad_rate_take(uuid,text,int,int)'] loop
    assert not has_function_privilege('authenticated', f, 'EXECUTE'), f || ' must not be callable by a signed-in customer';
    assert not has_function_privilege('anon', f, 'EXECUTE'), f || ' must not be callable by anon';
    assert has_function_privilege('service_role', f, 'EXECUTE'), f || ' must stay callable by the server';
  end loop;
  assert not has_table_privilege('authenticated', 'public.zad_rate_gate', 'SELECT'), 'zad_rate_gate is server-only';
end $$;

-- ٣ب. The refusal as PostgREST would meet it: a customer's token calling the ad grant.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', false);
do $$ begin
  perform public.zad_ad_reward_grant(null);
  raise exception 'a customer called zad_ad_reward_grant';
exception when insufficient_privilege then null;
end $$;
reset role;

select 'cost_holes_test: all passed' as result;
