-- A push token names a device, not an account: whoever signed in on the phone last
-- owns it.
--
-- zad_fcm_tokens (read off the live project 2026-09-21): token is unique; RLS lets a
-- signed-in user read and write only rows with their own user_id. So when account A
-- leaves a token row behind — a sign-out that could not reach the server, a phone
-- handed to someone else, an app data wipe without a sign-out — and account B signs
-- in on the same phone, B's upsert of that token hits A's row, the UPDATE fails A's
-- RLS check, and B is refused. Two things follow, both silent: B never receives an
-- alert on this phone, and zad-brain keeps pushing A's alerts — balances, doses,
-- bank messages — to a phone A no longer holds.
--
-- zad_register_fcm_token (security definer) moves the token to the caller: any row
-- for that token under another account is deleted, the caller's is inserted or
-- refreshed. It never touches another token, and it can only ever assign a token to
-- the signed-in caller. Unregistering stays a plain owner delete under the existing
-- RLS (the Flutter client does it at sign-out, while the session is still valid).
--
-- Kotlin's ZadFcmGate keeps its direct upsert and keeps working as before; this is
-- additive. Idempotent, so CI re-running it changes nothing.

create or replace function public.zad_register_fcm_token(
  p_token text,
  p_platform text default 'android'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_token text := btrim(coalesce(p_token, ''));
  v_platform text := lower(btrim(coalesce(p_platform, '')));
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  -- FCM registration tokens are long opaque strings (~150+ chars); anything short
  -- or huge is not one.
  if char_length(v_token) < 32 or char_length(v_token) > 4096 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_token');
  end if;
  if v_platform not in ('android', 'ios') then
    v_platform := 'android';
  end if;

  delete from public.zad_fcm_tokens where token = v_token and user_id <> v_uid;

  insert into public.zad_fcm_tokens (user_id, token, platform, updated_at)
  values (v_uid, v_token, v_platform, now())
  on conflict (token) do update
    set platform = excluded.platform, updated_at = now()
    where zad_fcm_tokens.user_id = v_uid;

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.zad_register_fcm_token(text, text) from public, anon;
grant execute on function public.zad_register_fcm_token(text, text) to authenticated;
