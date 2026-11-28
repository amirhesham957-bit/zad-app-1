-- On top of the view scaffolds: the zad_transactions columns zad_cash_balance reads (title/wallet/transfer_to), as live.
-- Scratch only.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
alter table public.zad_transactions add column if not exists title text, add column if not exists wallet text not null default 'card',
  add column if not exists transfer_to text;
