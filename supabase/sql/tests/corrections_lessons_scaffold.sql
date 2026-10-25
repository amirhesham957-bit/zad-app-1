-- Tables the correction triggers (20261025061500) sit on, on top of scratch_scaffold.sql. Only the columns they read.
create table public.zad_transactions (id uuid primary key default gen_random_uuid(), user_id uuid, category text, title text, merchant_name text);
create table public.zad_insights (id uuid primary key default gen_random_uuid(), user_id uuid, status text, dismiss_reason text, title text, dedupe_key text);
create table public.zad_product_pairs (id uuid primary key default gen_random_uuid(), user_id uuid, a_key text, b_key text, verdict text);
grant all on public.zad_transactions, public.zad_insights, public.zad_product_pairs to authenticated;
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000b1');
