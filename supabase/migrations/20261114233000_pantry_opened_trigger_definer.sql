-- The opened-items trigger (20261114220000) ran as the caller. It calls
-- private.zad_pantry_opened_life, and the app's users have no USAGE on schema
-- private, so every insert or quantity update on zad_inventory from the app or
-- the chat failed with 42501 "permission denied for schema private" — measured
-- live 2026-11-14 on a fresh account, both through PostgREST and zad-brain's
-- add_inventory_item. Same fix as private.zad_product_canonical_name_trg next to
-- it: the trigger function runs as its owner, with an empty search_path.
create or replace function private.zad_inventory_opened()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.quantity, 0) <= 0 then
    new.opened_at := null;
  end if;
  new.opened_life_days := case when new.opened_at is null then null
                               else private.zad_pantry_opened_life(new.item_name) end;
  return new;
end;
$$;

revoke all on function private.zad_inventory_opened() from public, anon, authenticated;
