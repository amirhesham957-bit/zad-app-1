-- A pharmacy receipt restocks the pharmacy, through the server.
--
-- remaining_quantity is moved by zad_log_pharmacy_dose_atomic: a dose takes its units
-- off inside the transaction that records it. A client that wrote the column itself —
-- Kotlin's injectPharmacyReceipt reads the count, adds, and writes it back — races that
-- function, and a dose taken between the read and the write comes back. So stock comes
-- in the way it goes out: one function, one transaction, remaining_quantity + n.
--
-- It also has to be safe to send twice. The Flutter app queues writes and retries after
-- an ambiguous failure, and an increment replayed is tablets that are not there. A count
-- that is too high is the silent kind of wrong: the "running out" nudge and the
-- shopping-list line both come from this number. Each restock carries an id the client
-- made, recorded in zad_pharmacy_restocks; the same id a second time changes nothing.
--
-- A medicine the customer does not have yet is created here, with its first stock,
-- rather than through the plain upsert. The app never sends remaining_quantity on an
-- upsert (the dose function owns it), and the column defaults to 1, so a new medicine
-- would land as one tablet. If the name is already taken — zad_pharmacy_items is unique
-- on (user, lower(trim(name)), member) and the phone's copy can be stale — the stock
-- goes to the medicine that has it, and the answer says which row that was.
--
-- Security invoker, like the dose function: RLS applies, and p_user must be the caller
-- unless the caller is the service role.
--
-- Also run by hand on the live project on 2026-09-21 on the owner's instruction, through
-- execute_sql so no version was stamped, and verified there in rolled-back blocks as real
-- accounts; every statement is idempotent, so CI re-running this file changes nothing.

create table if not exists public.zad_pharmacy_restocks (
  id         uuid primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  item_id    uuid not null references public.zad_pharmacy_items(id) on delete cascade,
  quantity   integer not null check (quantity between 1 and 10000),
  created_at timestamptz not null default now()
);
create index if not exists zad_pharmacy_restocks_user on public.zad_pharmacy_restocks (user_id);
create index if not exists zad_pharmacy_restocks_item on public.zad_pharmacy_restocks (item_id);

alter table public.zad_pharmacy_restocks enable row level security;

drop policy if exists zad_pharmacy_restocks_select_own on public.zad_pharmacy_restocks;
create policy zad_pharmacy_restocks_select_own on public.zad_pharmacy_restocks
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists zad_pharmacy_restocks_insert_own on public.zad_pharmacy_restocks;
create policy zad_pharmacy_restocks_insert_own on public.zad_pharmacy_restocks
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.zad_pharmacy_items i
                where i.id = item_id and i.user_id = (select auth.uid()))
  );

revoke all on public.zad_pharmacy_restocks from anon;

create or replace function public.zad_pharmacy_restock(
  p_user uuid,
  p_restock uuid,
  p_item uuid,
  p_quantity integer,
  p_name text default null,
  p_unit text default null,
  p_category text default null
)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_item public.zad_pharmacy_items%rowtype;
  v_prior uuid;
  v_logged uuid;
  v_created boolean := false;
begin
  if p_user is null or p_restock is null or p_item is null
     or p_quantity is null or p_quantity < 1 or p_quantity > 10000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;

  if auth.uid() is distinct from p_user and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- A replay: answer with the medicine as it stands, and add nothing.
  select item_id into v_prior
  from public.zad_pharmacy_restocks
  where id = p_restock and user_id = p_user;
  if found then
    select * into v_item from public.zad_pharmacy_items
    where id = v_prior and user_id = p_user;
    return jsonb_build_object(
      'ok', true, 'duplicate', true, 'created', false,
      'item', case when v_item.id is null then null else to_jsonb(v_item) end);
  end if;

  select * into v_item
  from public.zad_pharmacy_items
  where id = p_item and user_id = p_user
  for update;

  if not found then
    if nullif(btrim(p_name), '') is null then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;

    -- No conflict target on purpose: the primary key and the per-owner name index
    -- both mean "there is already a row", and either way the stock goes to it.
    insert into public.zad_pharmacy_items (id, user_id, name, unit, category, remaining_quantity)
    values (p_item, p_user, btrim(p_name),
            coalesce(nullif(btrim(p_unit), ''), 'قرص'),
            coalesce(nullif(btrim(p_category), ''), 'عام'),
            0)
    on conflict do nothing;
    v_created := found;

    select * into v_item
    from public.zad_pharmacy_items
    where id = p_item and user_id = p_user
    for update;

    if not found then
      select * into v_item
      from public.zad_pharmacy_items
      where user_id = p_user
        and lower(btrim(name)) = lower(btrim(p_name))
        and family_member_id is null
      for update;
    end if;

    if not found then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;
  end if;

  -- Two identical calls at once both get past the replay check; the row lock above
  -- orders them, and the second one's insert finds the first one's id.
  insert into public.zad_pharmacy_restocks (id, user_id, item_id, quantity)
  values (p_restock, p_user, v_item.id, p_quantity)
  on conflict (id) do nothing
  returning id into v_logged;

  if v_logged is null then
    return jsonb_build_object(
      'ok', true, 'duplicate', true, 'created', false, 'item', to_jsonb(v_item));
  end if;

  update public.zad_pharmacy_items
  set remaining_quantity = remaining_quantity + p_quantity
  where id = v_item.id
  returning * into v_item;

  return jsonb_build_object(
    'ok', true, 'duplicate', false, 'created', v_created,
    'added', p_quantity, 'item', to_jsonb(v_item));
end;
$$;

revoke all on function public.zad_pharmacy_restock(uuid, uuid, uuid, integer, text, text, text)
  from public, anon;
grant execute on function public.zad_pharmacy_restock(uuid, uuid, uuid, integer, text, text, text)
  to authenticated, service_role;
