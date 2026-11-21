-- Scratch shape for commit_intent_home_test.sql (after the door scaffold): zad_maintenance_items, zad_documents and
-- zad_appointments with the columns and CHECKs read from live on 2026-11-21. Never against live.
\set ON_ERROR_STOP on
create table public.zad_maintenance_items (
  id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete cascade,
  name text not null, category text not null default 'عام', purchase_date text, warranty_expiry_date text,
  last_service_date text, service_interval_days integer, estimated_cost double precision not null default 0.0,
  notes text, created_at timestamptz default now());
create table public.zad_documents (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null, holder text not null default '', label text not null default '', expires_on date not null,
  created_at timestamptz not null default now(),
  constraint zad_documents_expires_on_check check (expires_on >= '2000-01-01' and expires_on <= '2100-12-31'),
  constraint zad_documents_holder_check check (holder = btrim(holder) and char_length(holder) <= 40),
  constraint zad_documents_kind_check check (kind in ('passport', 'national_id', 'residence', 'driving_license', 'vehicle_license', 'other')),
  constraint zad_documents_label_check check (label = btrim(label) and char_length(label) <= 40),
  constraint zad_documents_one_per_holder unique (user_id, kind, holder, label),
  constraint zad_documents_other_named check (kind <> 'other' or label <> ''));
create table public.zad_appointments (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  title text not null, kind text not null default 'personal', starts_at timestamptz not null, place_label text,
  remind_minutes_before integer not null default 30, recurrence text not null default 'once',
  status text not null default 'upcoming', source text not null default 'app', notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  for_person text, expected_cost numeric,
  constraint zad_appointments_expected_cost_range check (expected_cost is null or (expected_cost > 0 and expected_cost <= 1000000)),
  constraint zad_appointments_for_person_len check (for_person is null or (char_length(btrim(for_person)) between 1 and 40)),
  constraint zad_appointments_kind_check check (kind in ('work', 'errand', 'medical', 'family', 'personal', 'other')),
  constraint zad_appointments_notes_check check (notes is null or char_length(notes) <= 500),
  constraint zad_appointments_place_label_check check (place_label is null or char_length(place_label) <= 120),
  constraint zad_appointments_recurrence_check check (recurrence in ('once', 'hourly', 'daily', 'weekly', 'monthly')),
  constraint zad_appointments_remind_minutes_before_check check (remind_minutes_before >= 0 and remind_minutes_before <= 10080),
  constraint zad_appointments_source_check check (source in ('app', 'voice', 'chat', 'telegram', 'notification')),
  constraint zad_appointments_status_check check (status in ('upcoming', 'done', 'cancelled')),
  constraint zad_appointments_title_check check (char_length(btrim(title)) between 2 and 160));
