-- Scratch shape for cash_wallet_test.sql (after the money-door chain): zad_purchases (only the link column) and
-- private.zad_bank_twin copied verbatim from 20261102060000 (P2.10 matching: the purchase-door chain it lives in is far
-- too big for this chain). Never against live.
\set ON_ERROR_STOP on
create schema if not exists private;
create table public.zad_purchases (id uuid primary key default gen_random_uuid(), transaction_id uuid);
create or replace function private.zad_bank_twin(p_user uuid, p_amount numeric, p_at timestamptz)
returns uuid language sql stable security definer set search_path = public, pg_temp as $$
  select t.id
    from public.zad_transactions t
   where t.user_id = p_user
     and t.txn_kind = 'expense'
     and t.source_type = 'notification_listener'
     and abs(t.amount - p_amount) < 0.005
     and (t.category is null or btrim(t.category) in ('', 'أخرى', 'غير مصنف'))
     and t.created_at between p_at - interval '6 hours' and p_at + interval '10 minutes'
     and not exists (select 1 from public.zad_purchases p where p.transaction_id = t.id)
   order by abs(extract(epoch from t.created_at - p_at))
   limit 1;
$$;
