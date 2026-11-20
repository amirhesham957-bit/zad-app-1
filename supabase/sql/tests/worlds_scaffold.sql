-- On top of scratch_scaffold.sql: the live shapes the 20261116* migrations (worlds server) read or write.
--   psql < scratch_scaffold.sql ; [companion_scaffold.sql ; 20261012030000_companion.sql ;] psql < this file
-- Scratch databases only (the guard in scratch_scaffold.sql already refused real ones).

alter table public.zad_users add column if not exists country text;
alter table public.zad_users add column if not exists travel_country text;

-- 20260907040000 as live.
create table public.zad_ad_ssv_receipts (
  transaction_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  ad_unit text, reward_amount int, created_at timestamptz not null default now());
alter table public.zad_ad_ssv_receipts enable row level security;
create policy "own ssv receipts select" on public.zad_ad_ssv_receipts for select using ((select auth.uid()) = user_id);

-- 20260831140000 as live, including the "server write" policy that let any account insert.
create table public.user_achievements (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null, points_earned int not null default 0, unlocked_at timestamptz not null default now());
create unique index idx_user_achievements_unique on public.user_achievements (user_id, achievement_id);
alter table public.user_achievements enable row level security;
create policy "user_achievements_own" on public.user_achievements for select using (auth.uid() = user_id);
create policy "user_achievements_server_write" on public.user_achievements for insert with check (true);

create table public.family_tasbiha (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.family_groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  total_clicks integer default 0);
create table public.agent_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null, current_value numeric not null default 0, unique (user_id, title));

-- Server-only content tables, as live: RLS on, no client privileges, no policies.
create table public.zad_social_recipes (
  source_url text primary key, handle text not null, country text, name text,
  ingredients text[] not null default '{}', stores text[] not null default '{}', found_at timestamptz not null default now());
create table public.zad_social_picks (
  source_url text primary key, platform text not null, kind text not null, country text not null, title text not null,
  found_at timestamptz not null default now(), expires_at timestamptz not null default now() + interval '14 days');
create table public.zad_medicine_prices (
  country text not null, name_key text not null, name text not null, price_low numeric not null, price_high numeric not null,
  found_at timestamptz not null default now(), primary key (country, name_key));
create table public.zad_user_city (
  user_id uuid primary key references public.zad_users(id) on delete cascade,
  country text not null, city text not null default '', found_at timestamptz not null default now());
alter table public.zad_social_recipes enable row level security;
alter table public.zad_social_picks enable row level security;
alter table public.zad_medicine_prices enable row level security;
alter table public.zad_user_city enable row level security;
revoke all on public.zad_social_recipes, public.zad_social_picks, public.zad_medicine_prices, public.zad_user_city from anon, authenticated;

-- 20260725000000 as live.
create table public.zad_pharmacy_doses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null references public.zad_pharmacy_items(id) on delete cascade,
  scheduled_at timestamptz, taken_at timestamptz, status text not null check (status in ('taken','skipped','missed')),
  units numeric not null default 1, created_at timestamptz not null default now());
create unique index zad_doses_unique on public.zad_pharmacy_doses (user_id, item_id, scheduled_at) where scheduled_at is not null;
alter table public.zad_pharmacy_doses enable row level security;
create policy user_own_pharmacy_doses on public.zad_pharmacy_doses for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
