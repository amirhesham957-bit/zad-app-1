-- What 20261025213500_bank_formats_learned reads, on top of scratch_scaffold.sql. Only the columns it touches.
alter table public.zad_users add column if not exists country text;
create table public.zad_notification_ingest_events (id uuid primary key default gen_random_uuid(), user_id uuid, package_name text, title text, body text);
create table public.zad_transaction_proposals (id uuid primary key default gen_random_uuid(), user_id uuid, source_event_id uuid,
  source_type text, status text, txn_kind text, bank_name text, merchant_name text, updated_at timestamptz default now());
