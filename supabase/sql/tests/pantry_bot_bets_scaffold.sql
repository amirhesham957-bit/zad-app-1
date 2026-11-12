-- What 20261113000000_pantry_bets_from_the_bot.sql reads beyond pantry_learning_scaffold.sql, as live 2026-11-12.
create table public.telegram_checkin_prompts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_name text not null,
  quantity_at_prompt numeric not null,
  status text not null default 'pending' check (status in ('pending','answered_yes','answered_no','expired')),
  sent_at timestamptz not null default now(),
  answered_at timestamptz,
  expires_at timestamptz not null default (now() + interval '3 days'));
alter table public.telegram_checkin_prompts enable row level security;
grant all on table public.telegram_checkin_prompts to anon, authenticated, service_role;
create policy user_own_checkin_prompts on public.telegram_checkin_prompts for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
