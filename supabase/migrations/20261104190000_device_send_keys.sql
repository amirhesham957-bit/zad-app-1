-- ZAD_PLAN ٢.٧(ب): a send key per device, so a bank notification reaches the
-- server while the app is closed.
--
-- The headless engine the bank listener starts reads the app's session and never
-- refreshes it (١.٣: refreshing from the background spent the rotating refresh
-- token and signed the customer out). So an hour after the last open, a card
-- payment waited on the phone until the app was opened again — measured on the
-- owner's phone 2026-11-04: zero rows in zad_notification_ingest_events for the
-- account since it was created.
--
-- The app registers a random 256-bit key per device while it holds a valid
-- session. Only its SHA-256 is stored here; the raw key never leaves the phone
-- after that call (it does not even cross the wire at registration). zad-brain
-- accepts the key for `notification_ingest` and nothing else, and takes the
-- account from this row, never from the request body.
--
-- No client policy on the table: the app goes through the two functions below,
-- zad-brain through the service role. Rows go with the account (on delete
-- cascade). Idempotent.

create table if not exists public.zad_device_send_keys (
  key_hash text primary key check (key_hash ~ '^[0-9a-f]{64}$'),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);

create index if not exists zad_device_send_keys_user_idx
  on public.zad_device_send_keys (user_id, created_at desc);

alter table public.zad_device_send_keys enable row level security;

-- Registers the caller's device key. Keeps the five newest per account, so a
-- reinstalled or replaced phone does not leave live keys behind for ever.
create or replace function public.zad_register_device_key(p_key_hash text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_hash text := lower(btrim(coalesce(p_key_hash, '')));
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if v_hash !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_hash');
  end if;

  insert into public.zad_device_send_keys (key_hash, user_id)
  values (v_hash, v_uid)
  on conflict (key_hash) do nothing;

  -- A hash already held by another account is never moved: the caller would
  -- have to know that account's raw key, and a random 256-bit key does not
  -- collide by accident.
  if not exists (
    select 1 from public.zad_device_send_keys
    where key_hash = v_hash and user_id = v_uid
  ) then
    return jsonb_build_object('ok', false, 'reason', 'taken');
  end if;

  delete from public.zad_device_send_keys
  where user_id = v_uid
    and key_hash not in (
      select key_hash from public.zad_device_send_keys
      where user_id = v_uid
      order by created_at desc
      limit 5
    );

  return jsonb_build_object('ok', true);
end;
$$;

-- Drops one of the caller's keys (sign-out, while the session is still valid).
create or replace function public.zad_revoke_device_key(p_key_hash text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  delete from public.zad_device_send_keys
  where key_hash = lower(btrim(coalesce(p_key_hash, ''))) and user_id = v_uid;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.zad_register_device_key(text) from public, anon;
grant execute on function public.zad_register_device_key(text) to authenticated;
revoke all on function public.zad_revoke_device_key(text) from public, anon;
grant execute on function public.zad_revoke_device_key(text) to authenticated;
