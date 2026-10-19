-- باب شرا واحد: the wallet survives (migration 20261019200000). Run after
-- purchase_door_scaffold.sql and both purchase-door migrations (CI: job sql-tests).

\set ON_ERROR_STOP on

insert into auth.users values ('00000000-0000-0000-0000-00000000000a');

set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', false);

do $$
declare r jsonb;
begin
  r := public.zad_record_purchase(jsonb_build_object(
    'id', '21111111-1111-1111-1111-111111111111', 'amount', 10, 'title', 'محفظة', 'wallet', 'bank'));
  assert r ->> 'status' = 'recorded', r::text;
  r := public.zad_record_purchase(jsonb_build_object(
    'id', '21111111-1111-1111-1111-111111111112', 'amount', 20, 'title', 'كاش', 'wallet', 'cash'));
  assert r ->> 'status' = 'recorded', r::text;
  r := public.zad_record_purchase(jsonb_build_object(
    'id', '21111111-1111-1111-1111-111111111113', 'amount', 30, 'title', 'غريب', 'wallet', 'crypto'));
  assert r ->> 'status' = 'recorded', r::text;
end $$;
reset role;

do $$ begin
  assert (select wallet from public.zad_transactions where id = '21111111-1111-1111-1111-111111111111') = 'bank', 'bank stays bank';
  assert (select wallet from public.zad_transactions where id = '21111111-1111-1111-1111-111111111112') = 'cash', 'cash stays cash';
  assert (select wallet from public.zad_transactions where id = '21111111-1111-1111-1111-111111111113') = 'card', 'anything else is card';
end $$;

select 'purchase_door_wallet_test: ok' as result;
