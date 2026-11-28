-- Scratch shape for money_buttons_test.sql: live's zad_transactions has `currency` (the normalize trigger rewrites it);
-- the money scaffold does not. Never against live.
\set ON_ERROR_STOP on
alter table public.zad_transactions add column if not exists currency text;

-- settings door columns (zad_intent_settings reads/writes these on zad_users)
alter table public.zad_users
  add column if not exists country text,
  add column if not exists cycle_start_day int,
  add column if not exists emergency_fund_balance numeric,
  add column if not exists food_pattern_enabled boolean,
  add column if not exists pet_calls_enabled boolean,
  add column if not exists sleep_bed time,
  add column if not exists sleep_wake time,
  add column if not exists sleep_nights int,
  add column if not exists sleep_source text,
  add column if not exists sleep_updated_at timestamptz;
