-- What 20261115020000_export_my_data.sql reads beyond scratch_scaffold.sql (zad_users, zad_fcm_tokens,
-- zad_pharmacy_items, family_members… are there already).
alter table public.zad_users add column if not exists token text;  -- stands in for any secret column
create table public.zad_transactions (id uuid primary key default gen_random_uuid(), user_id uuid, amount double precision, title text);
create table public.zad_entitlements (user_id uuid primary key, tier text, purchase_token text);
create table public.zad_rate_gate (user_id uuid, hits int);
create table public.zad_chat_turns (id bigserial primary key, user_id uuid, role text, text text);
create table public.zad_notes_text_owner (id uuid primary key default gen_random_uuid(), user_id text, body text);  -- user_id not uuid
create table public.zad_support_access_log (id bigserial primary key, user_id uuid, admin_chat bigint, action text, at timestamptz default now());
