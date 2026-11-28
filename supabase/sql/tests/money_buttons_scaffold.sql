-- Scratch shape for money_buttons_test.sql: live's zad_transactions has `currency` (the normalize trigger rewrites it);
-- the money scaffold does not. Never against live.
\set ON_ERROR_STOP on
alter table public.zad_transactions add column if not exists currency text;
