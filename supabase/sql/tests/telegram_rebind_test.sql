-- A fresh code moves the chat (migration 20261010120000). Scratch database only:
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/migrations/20261010120000_telegram_rebind_through_the_code.sql
--   psql < supabase/sql/tests/telegram_rebind_test.sql
--
-- The tables are created here in their live shape (read 2026-10-10) when the scaffold
-- lacks them (plpgsql resolves tables when it runs, so the migration may come first).
-- Each block rolls back.

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create table if not exists public.telegram_bindings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  chat_id bigint,
  binding_code text not null,
  code_expires_at timestamptz not null,
  bound_at timestamptz,
  created_at timestamptz not null default now(),
  country_asked_at timestamptz
);
create unique index if not exists idx_telegram_bindings_code on public.telegram_bindings(binding_code);
create unique index if not exists idx_telegram_bindings_chat_bound on public.telegram_bindings(chat_id) where bound_at is not null;
create unique index if not exists idx_telegram_bindings_user_bound on public.telegram_bindings(user_id) where bound_at is not null;

create table if not exists public.telegram_pending_writes (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, chat_id bigint not null,
  txn_kind text not null default 'expense', amount double precision not null default 1, title text,
  category text, confidence double precision, status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'cancelled')),
  created_at timestamptz default now(), expires_at timestamptz);
create table if not exists public.telegram_pending_pharmacy (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, chat_id bigint not null,
  name text not null default 'x', dosage text, daily_dose_count int, dose_times text, unit text,
  quantity double precision, category text, status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'cancelled')),
  created_at timestamptz default now(), expires_at timestamptz);
create table if not exists public.telegram_pending_tools (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, chat_id bigint not null,
  tool text not null default 'x', input jsonb, summary text, status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'cancelled')),
  created_at timestamptz default now(), expires_at timestamptz);
create table if not exists public.telegram_checkin_prompts (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, item_name text not null default 'x',
  quantity_at_prompt double precision, status text not null default 'pending'
    check (status in ('pending', 'answered_yes', 'answered_no', 'expired')),
  sent_at timestamptz default now(), answered_at timestamptz, expires_at timestamptz);


insert into auth.users values
  ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2')
  on conflict do nothing;

-- The owner's case: chat 77 bound to the old account, a code from the new one moves it.
begin;
do $$
declare
  old_u uuid := '00000000-0000-0000-0000-0000000000a1';
  new_u uuid := '00000000-0000-0000-0000-0000000000a2';
  r jsonb;
begin
  insert into telegram_bindings (user_id, chat_id, binding_code, code_expires_at, bound_at)
    values (old_u, 77, 'OLDCODE1', now() - interval '1 day', now() - interval '30 days');
  insert into telegram_bindings (user_id, binding_code, code_expires_at)
    values (new_u, 'GMDNPXV6', now() + interval '10 minutes');
  insert into telegram_pending_writes (user_id, chat_id) values (old_u, 77);
  insert into telegram_pending_pharmacy (user_id, chat_id) values (old_u, 77);
  insert into telegram_pending_tools (user_id, chat_id) values (old_u, 77);
  insert into telegram_checkin_prompts (user_id) values (old_u);

  r := zad_redeem_telegram_code('GMDNPXV6', 77);
  assert r->>'status' = 'moved', r::text;
  assert (r->>'user_id')::uuid = new_u, r::text;
  assert (select user_id from telegram_bindings where chat_id = 77 and bound_at is not null) = new_u;
  assert not exists (select 1 from telegram_bindings where user_id = old_u and bound_at is not null);
  assert (select status from telegram_pending_writes where user_id = old_u) = 'cancelled';
  assert (select status from telegram_pending_pharmacy where user_id = old_u) = 'cancelled';
  assert (select status from telegram_pending_tools where user_id = old_u) = 'cancelled';
  assert (select status from telegram_checkin_prompts where user_id = old_u) = 'expired';

  -- Spent: the same code twice is refused.
  r := zad_redeem_telegram_code('GMDNPXV6', 77);
  assert r->>'status' = 'invalid', r::text;
end $$;
rollback;

-- A first link, an expired code, and the same chat re-linking its own account.
begin;
do $$
declare
  u uuid := '00000000-0000-0000-0000-0000000000a1';
  r jsonb;
begin
  insert into telegram_bindings (user_id, binding_code, code_expires_at)
    values (u, 'STALE001', now() - interval '1 minute');
  r := zad_redeem_telegram_code('STALE001', 55);
  assert r->>'status' = 'invalid', r::text;
  assert not exists (select 1 from telegram_bindings where chat_id = 55);

  insert into telegram_bindings (user_id, binding_code, code_expires_at)
    values (u, 'FIRST001', now() + interval '10 minutes');
  r := zad_redeem_telegram_code('FIRST001', 55);
  assert r->>'status' = 'bound', r::text;

  insert into telegram_bindings (user_id, binding_code, code_expires_at)
    values (u, 'AGAIN001', now() + interval '10 minutes');
  r := zad_redeem_telegram_code('AGAIN001', 55);
  assert r->>'status' = 'already_bound', r::text;
  assert (select count(*) from telegram_bindings where user_id = u and bound_at is not null) = 1;
  assert (select chat_id from telegram_bindings where user_id = u and bound_at is not null) = 55;
  assert not exists (select 1 from telegram_bindings where binding_code = 'AGAIN001');

  r := zad_redeem_telegram_code(null, 55);
  assert r->>'status' = 'invalid', r::text;
end $$;
rollback;

-- An account moving to a second chat leaves the first one.
begin;
do $$
declare
  u uuid := '00000000-0000-0000-0000-0000000000a1';
  r jsonb;
begin
  insert into telegram_bindings (user_id, chat_id, binding_code, code_expires_at, bound_at)
    values (u, 10, 'PHONE001', now(), now());
  insert into telegram_bindings (user_id, binding_code, code_expires_at)
    values (u, 'PHONE002', now() + interval '10 minutes');
  r := zad_redeem_telegram_code('PHONE002', 20);
  assert r->>'status' = 'bound', r::text;
  assert (select chat_id from telegram_bindings where user_id = u and bound_at is not null) = 20;
  assert not exists (select 1 from telegram_bindings where chat_id = 10);
end $$;
rollback;

-- /unlink: the chat is free, the account's questions are closed, a second /unlink is harmless.
begin;
do $$
declare
  u uuid := '00000000-0000-0000-0000-0000000000a1';
  other uuid := '00000000-0000-0000-0000-0000000000a2';
  r jsonb;
begin
  insert into telegram_bindings (user_id, chat_id, binding_code, code_expires_at, bound_at)
    values (u, 33, 'UNLINK01', now(), now());
  insert into telegram_pending_writes (user_id, chat_id) values (u, 33), (other, 99);
  r := zad_unlink_telegram_chat(33);
  assert r->>'status' = 'unlinked', r::text;
  assert not exists (select 1 from telegram_bindings where chat_id = 33);
  assert (select status from telegram_pending_writes where user_id = u) = 'cancelled';
  assert (select status from telegram_pending_writes where user_id = other) = 'pending';
  r := zad_unlink_telegram_chat(33);
  assert r->>'status' = 'not_bound', r::text;
end $$;
rollback;

-- Only the bot may call them.
begin;
do $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000000a1', 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    perform zad_redeem_telegram_code('ANY', 1);
    raise exception 'authenticated could redeem directly';
  exception when insufficient_privilege then null;
  end;
  begin
    perform zad_unlink_telegram_chat(1);
    raise exception 'authenticated could unlink directly';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;

select 'telegram_rebind_test: all passed' as result;
