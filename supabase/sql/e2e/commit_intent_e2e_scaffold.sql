-- م٢.٥ e2e: بعد commit_intent_scaffold والمايجريشنات، الجداول والدوال اللي أدوات المخزن في العقل بتلمسها
-- (المطابقة، قايمة التسوق، سجل الأفعال، التعلّم). شكل مختصر، Postgres محلي بس — مش الحي أبداً.
\set ON_ERROR_STOP on
alter table public.zad_inventory add column if not exists low_stock_threshold numeric,
  add column if not exists restock_mode text, add column if not exists restock_cycle_days int,
  add column if not exists opened_life_days int;
-- zad_shopping_list: commit_intent_shopping_scaffold.sql (قبل مايجريشن القايمة).
create table public.agent_actions (id uuid primary key default gen_random_uuid(), user_id uuid, run_id uuid, source text,
  tool_name text, input jsonb, target_table text, target_id uuid, previous_state jsonb, new_state jsonb, status text,
  result_summary text, created_at timestamptz default now());
create table public.zad_inventory_observations (user_id uuid, item_name text, qty numeric, source text, observed_at timestamptz default now());
create or replace function public.zad_record_observation(p_user uuid, p_item text, p_qty numeric, p_source text)
returns jsonb language plpgsql as $$ begin
  insert into public.zad_inventory_observations (user_id, item_name, qty, source) values (p_user, p_item, p_qty, p_source);
  return jsonb_build_object('samples', 1, 'rate_known', false); end $$;
create or replace function public.zad_product_canonical(p_user uuid, p_name text) returns text language sql as $$ select p_name $$;
-- الفلوس: صف البنك التوأم مش موجود، ورصيد الكاش = الكاش اللي داخل ناقص المصروف كاش (نفس معنى zad_cash_balance).
create or replace function public.zad_bank_twin_service(p_user uuid, p_amount numeric) returns uuid language sql as $$ select null::uuid $$;
create or replace function public.zad_cash_balance(p_user uuid) returns numeric language sql as $$
  select coalesce(sum(case when txn_kind = 'transfer' and transfer_to = 'cash' then amount
                           when txn_kind = 'expense' and wallet = 'cash' then -amount else 0 end), 0)::numeric
    from public.zad_transactions where user_id = p_user $$;
do $$ begin create role authenticator noinherit login password 'pg'; exception when duplicate_object then null; end $$;
grant anon, authenticated, service_role to authenticator;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant usage on schema auth to service_role;
grant select on auth.users to service_role;
