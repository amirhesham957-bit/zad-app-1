-- The live shapes of zad_subscriptions and zad_obligations (information_schema + pg_constraint, read-only, 2026-10-05), grown
-- onto the minimal tables audit_gaps_scaffold.sql makes, and the bills that are already there when 20261005235107 runs.
--
--   docker run -d --name zadpg -e POSTGRES_PASSWORD=pg postgres:17-alpine
--   psql() { docker exec -i zadpg psql -U postgres -v ON_ERROR_STOP=1 -q; }
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/audit_gaps_scaffold.sql
--   psql < supabase/migrations/20261005233809_audit_gaps.sql
--   psql < supabase/sql/tests/bills_one_home_scaffold.sql
--   psql < supabase/migrations/20261005235107_bills_one_home.sql
--   psql < supabase/sql/tests/bills_one_home_test.sql

\set ON_ERROR_STOP on

alter table public.zad_subscriptions
  alter column user_id set not null, alter column title set not null, alter column amount set not null,
  alter column is_active set not null,
  add column if not exists category text,
  add column if not exists created_at timestamptz default now(),
  add column if not exists auto_deduct boolean not null default false,
  add column if not exists type text not null default 'subscription',
  add column if not exists provider text,
  add column if not exists source text not null default 'user';

alter table public.zad_obligations
  alter column user_id set not null, alter column title set not null,
  alter column active set not null, alter column active set default true,
  add column if not exists id uuid primary key default gen_random_uuid(),
  add column if not exists amount numeric not null check (amount > 0),
  add column if not exists kind text not null check (kind in ('rent', 'installment', 'debt', 'tuition', 'utility', 'other')),
  add column if not exists due_date date,
  add column if not exists recurrence text not null default 'monthly' check (recurrence in ('monthly', 'quarterly', 'yearly', 'once')),
  add column if not exists auto_detected boolean not null default false,
  add column if not exists confirmed boolean not null default false,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists provider text,
  add column if not exists total_installments int,
  add column if not exists remaining_installments int,
  add constraint zad_obligations_due_day_check check (due_day between 1 and 31);

-- What is there before the migration. U = 00…a1 (audit_gaps_scaffold made it).
delete from public.zad_subscriptions;
insert into public.zad_subscriptions (user_id, title, amount, renewal_date, due_day, billing_cycle, is_active, type, category, provider) values
  ('00000000-0000-0000-0000-0000000000a1', 'كهربا', 450, '2026-10-12', null, 'MONTHLY', true, 'utility', 'فواتير', 'جنوب القاهرة'),
  ('00000000-0000-0000-0000-0000000000a1', 'مية', 120, '2026-10-20', null, 'MONTHLY', true, 'subscription', 'فواتير', null),
  ('00000000-0000-0000-0000-0000000000a1', 'نتفليكس', 200, '2026-10-03', null, 'MONTHLY', true, 'subscription', 'الترفيه', null),
  ('00000000-0000-0000-0000-0000000000a1', 'غاز', 80, '2026-10-06', null, 'WEEKLY', true, 'utility', 'الفواتير', null),
  ('00000000-0000-0000-0000-0000000000a1', 'نت قديم', 0, '2026-10-01', null, 'MONTHLY', true, 'bill', null, null),
  ('00000000-0000-0000-0000-0000000000a1', 'تليفون أرضي', 60, '2026-09-01', null, 'MONTHLY', false, 'utility', null, null),
  ('00000000-0000-0000-0000-0000000000a1', 'عداد غريب', 90, 'بكرة', 40, 'MONTHLY', true, 'bill', null, null),
  ('00000000-0000-0000-0000-0000000000a1', 'رخصة العداد', 300, '2027-01-15', null, 'YEARLY', true, 'subscription', 'فاتورة', null);
-- مية is already an obligation (the brain wrote it) — the case that used to count twice.
insert into public.zad_obligations (user_id, title, amount, kind, recurrence, due_day, confirmed, active) values
  ('00000000-0000-0000-0000-0000000000a1', ' مية ', 120, 'utility', 'monthly', 20, true, true);
