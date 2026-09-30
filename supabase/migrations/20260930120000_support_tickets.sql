-- Complaints and support requests from the app, so a person can answer them.
--
-- The support screen had only an AI helper and a crash-log share button: a
-- complaint went nowhere a human would see it (owner, 2026-09-30). Every
-- request now lands here, and `zad-support` emails it to the support inbox.
create table if not exists public.zad_support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  contact_email text,
  subject text not null check (char_length(subject) between 1 and 200),
  message text not null check (char_length(message) between 1 and 8000),
  -- The support chat so far and the on-phone crash log, when the customer
  -- chose to attach them.
  conversation jsonb,
  crash_log text check (crash_log is null or char_length(crash_log) <= 60000),
  app_version text,
  device text,
  status text not null default 'open' check (status in ('open', 'answered', 'closed')),
  emailed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists zad_support_tickets_user_created
  on public.zad_support_tickets (user_id, created_at desc);

alter table public.zad_support_tickets enable row level security;

drop policy if exists "support tickets: own insert" on public.zad_support_tickets;
create policy "support tickets: own insert" on public.zad_support_tickets
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "support tickets: own read" on public.zad_support_tickets;
create policy "support tickets: own read" on public.zad_support_tickets
  for select to authenticated using (user_id = auth.uid());
