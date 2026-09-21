-- A push token follows the device to whoever signed in on it last (migration
-- 20260921170000), as real accounts on a scratch database — see
-- scratch_scaffold.sql for how to run it. Each block rolls back.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

insert into auth.users values ('00000000-0000-0000-0000-0000000000f1'), ('00000000-0000-0000-0000-0000000000f2')
  on conflict do nothing;

begin;
do $$
declare
  a uuid := '00000000-0000-0000-0000-0000000000f1';
  b uuid := '00000000-0000-0000-0000-0000000000f2';
  t text := 'fcm-token-' || repeat('x', 140);
  r jsonb;
begin
  -- A signs in on the phone.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r := zad_register_fcm_token(t, 'android');
  assert (r->>'ok')::bool, r::text;
  assert (select user_id from zad_fcm_tokens where token = t) = a;

  -- Registering again refreshes, never duplicates.
  r := zad_register_fcm_token(t);
  assert (select count(*) from zad_fcm_tokens where token = t) = 1;

  -- The old way: B's direct upsert of A's token is refused by RLS.
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  begin
    insert into zad_fcm_tokens (user_id, token) values (b, t)
      on conflict (token) do update set user_id = excluded.user_id;
    raise exception 'direct takeover was allowed';
  exception when insufficient_privilege then null; end;

  -- The function moves it: B owns the phone's token now, A no longer does.
  r := zad_register_fcm_token(t);
  assert (r->>'ok')::bool, r::text;
  reset role;
  assert (select user_id from zad_fcm_tokens where token = t) = b, 'token did not follow the device';
  assert (select count(*) from zad_fcm_tokens where user_id = a) = 0, 'A still gets pushes on this phone';

  -- A cannot pull it back by writing directly, and cannot see B's row.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  assert (select count(*) from zad_fcm_tokens) = 0, 'A reads B''s token';
  update zad_fcm_tokens set user_id = a where token = t;
  reset role;
  assert (select user_id from zad_fcm_tokens where token = t) = b;

  -- Nonsense is refused as an answer, not written.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  assert zad_register_fcm_token('short')->>'reason' = 'invalid_token';
  assert zad_register_fcm_token(null)->>'reason' = 'invalid_token';

  -- Signed out: refused outright.
  perform set_config('request.jwt.claims', '{}', true);
  begin
    perform zad_register_fcm_token(t);
    raise exception 'anonymous registration was allowed';
  exception when insufficient_privilege then null; end;

  raise notice 'FCM TOKENS: all checks passed';
end $$;
rollback;
