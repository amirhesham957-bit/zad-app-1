-- 20261113160000: with pg_net throwing, the writes that fire these calls still land,
-- and each call was actually attempted (so the guard is not just skipping the call).
\set ON_ERROR_STOP on
set client_min_messages = error;

insert into telegram_bindings values ('00000000-0000-0000-0000-000000000001', now());
insert into zad_inventory values ('00000000-0000-0000-0000-000000000001', 'لبن', 5, 1);

-- Low stock: 5 → 1 crosses the threshold and calls out.
update zad_inventory set quantity = 1 where item_name = 'لبن';
do $$ begin
  assert (select quantity from zad_inventory where item_name = 'لبن') = 1, 'inventory update rolled back';
  assert (select last_value from net.attempts) = 1, 'low-stock trigger never tried to call out';
end $$;

-- A critical insight calls out.
insert into zad_insights values ('00000000-0000-0000-0000-000000000001', 'alert', 'critical', 'pending', 't', 'b');
do $$ begin
  assert (select count(*) from zad_insights) = 1, 'insight insert rolled back';
  assert (select last_value from net.attempts) = 2, 'insight trigger never tried to call out';
end $$;

-- The admin alert returns instead of raising.
select public.zad_notify_admin('t', 'b');
do $$ begin
  assert (select last_value from net.attempts) = 3, 'admin alert never tried to call out';
end $$;

-- A missing secret is caught too (it is read inside the guarded block).
create or replace function public.zad_cron_secret(p_name text) returns text language plpgsql as $$
begin raise exception 'no secret'; end $$;
select public.zad_notify_admin('t', 'b');
update zad_inventory set quantity = 5 where item_name = 'لبن';
update zad_inventory set quantity = 0 where item_name = 'لبن';
do $$ begin
  assert (select quantity from zad_inventory where item_name = 'لبن') = 0, 'update rolled back on a missing secret';
end $$;

\echo net_calls_never_block_writes: 7 checks passed
