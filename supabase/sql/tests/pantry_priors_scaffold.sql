-- What 20261114200000_pantry_household_priors.sql reads beyond pantry_learning_scaffold.sql and
-- pantry_bot_bets_scaffold.sql, as live 2026-11-14.
create table public.zad_customer_profile (
  user_id uuid primary key references auth.users(id) on delete cascade,
  household_size integer, kids_count integer);
