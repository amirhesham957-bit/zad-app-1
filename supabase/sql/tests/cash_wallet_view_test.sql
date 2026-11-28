-- P3.12: cash_on_hand في zad_view_money (20261128210100). بعد سلسلة view_rpcs + visibility_matrix + 20260726060000 + السقالة.
\set ON_ERROR_STOP on
do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;
\set QUIET 1
create or replace function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if; raise notice 'ok: %', label; end $$;
create or replace function pg_temp.who(p uuid) returns void language plpgsql as $$
begin reset role; perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, false); set role authenticated; end $$;
grant execute on function pg_temp.who(uuid) to authenticated;
grant execute on function pg_temp.check(boolean, text) to authenticated;
\set a '''00000000-0000-0000-0000-0000000000a1'''
\set k '''00000000-0000-0000-0000-0000000000d1'''
\set fam '''00000000-0000-0000-0000-0000000000f1'''
\set ma '''00000000-0000-0000-0000-00000000aa01'''
\set mk '''00000000-0000-0000-0000-00000000dd01'''
\set fmk '''00000000-0000-0000-0000-00000000ee01'''
insert into auth.users values (:a), (:k);
insert into public.family_groups (id) values (:fam);
insert into public.family_members (id, family_id, user_id, role) values (gen_random_uuid(), :fam, :a, 'admin'), (:fmk, :fam, :k, 'child');
insert into public.zad_household_members (id, user_id, display_name, kind) values (:ma, :a, 'أنا', 'self'), (:mk, :k, 'سلمى', 'self');
insert into public.zad_users (id, monthly_limit) values (:a, 5000), (:k, 50);
-- أ: دخل، سحب ١٠٠٠، صرف كاش ٣٥٠، صرف كارت ٤٠٠ (مايلمسش الكاش). سلمى (قاصر): سحب ٢٠٠ في دفترها.
insert into public.zad_transactions (user_id, amount, title, txn_kind, is_expense, wallet, transfer_to) values
  (:a, 9000, 'راتب', 'income', false, 'card', null),
  (:a, 1000, 'سحب كاش', 'transfer', true, 'card', 'cash'),
  (:a, 350, 'بقالة', 'expense', true, 'cash', null),
  (:a, 400, 'مطعم', 'expense', true, 'card', null),
  (:k, 200, 'سحب كاش', 'transfer', true, 'card', 'cash');
\set QUIET 0

select pg_temp.who(:a);
select pg_temp.check((public.zad_view_money() -> 'numbers' -> 'cash_on_hand' ->> 'value')::numeric = 650, 'cash_on_hand = withdrawal - cash spend; card spend untouched');
select pg_temp.check(public.zad_view_money() -> 'numbers' -> 'cash_on_hand' ->> 'source' = 'zad_cash_balance', 'cash_on_hand carries its source');
select pg_temp.check((public.zad_view_money() -> 'numbers' -> 'available' ->> 'value') is not null, 'the other numbers are still there');

select pg_temp.who(:k);
select pg_temp.check(public.zad_view_money() ->> 'reason' = 'minor_no_budget', 'child: no money view, so no cash number');
select pg_temp.check(public.zad_cash_balance(:k) = 0, 'child: cash ledger is invisible through RLS');
reset role;
select 'cash_wallet_view: all checks passed' as result;
