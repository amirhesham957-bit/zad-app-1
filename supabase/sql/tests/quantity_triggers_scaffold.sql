-- The two live triggers on «update of quantity» (20261011120000_restock_link, 20261012030000_companion),
-- with stub bodies: without them the scratch database let 20261020110000 change the column's type,
-- and production refused it (#207's deploy, 2026-10-19).

\set ON_ERROR_STOP on

create or replace function public._zad_restock_link_on_run_out() returns trigger language plpgsql as $$
begin return null; end $$;
create or replace function public.zad_companion_on_home() returns trigger language plpgsql as $$
begin return null; end $$;
create trigger trigger_restock_link_on_run_out
  after update of quantity on public.zad_inventory
  for each row execute function public._zad_restock_link_on_run_out();
create trigger zad_companion_xp after insert or update of quantity on public.zad_inventory
  for each row execute function public.zad_companion_on_home();
