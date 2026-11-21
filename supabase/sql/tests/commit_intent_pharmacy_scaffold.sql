-- Scratch shape for commit_intent_pharmacy_test.sql (after commit_intent_scaffold.sql + commit_intent_shopping_scaffold.sql):
-- zad_pharmacy_items with the columns the door writes (as on live), a consent table behind zad_family_share_granted, and a
-- stand-in zad_log_pharmacy_dose_atomic with its live reply shape (ok/reason, duplicate, remaining_quantity, dose_id,
-- shopping_added). Never against live.
\set ON_ERROR_STOP on
create table public.zad_pharmacy_items (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, name text not null, category text not null default 'عام',
  dosage text, remaining_quantity integer not null default 1, unit text not null default 'قرص',
  daily_dose_count integer not null default 1, is_recurring boolean not null default false, created_at timestamptz default now(),
  dose_times text, for_person text);
create table public.scratch_medicine_grants (viewer uuid, owner uuid);
create or replace function public.zad_family_share_granted(p_viewer uuid, p_owner uuid, p_scope text) returns boolean
language sql security definer set search_path = public as $$
  select p_scope = 'medicines' and exists (select 1 from public.scratch_medicine_grants where viewer = p_viewer and owner = p_owner) $$;
create table public.scratch_doses (id uuid primary key default gen_random_uuid(), item_id uuid, taken_at timestamptz);
create or replace function public.zad_log_pharmacy_dose_atomic(p_user uuid, p_item uuid, p_scheduled_at timestamptz, p_taken_at timestamptz)
returns jsonb language plpgsql set search_path = public as $$
declare v_row public.zad_pharmacy_items%rowtype; v_dose uuid;
begin
  select * into v_row from public.zad_pharmacy_items where id = p_item and user_id = p_user for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  if exists (select 1 from public.scratch_doses where item_id = p_item and taken_at > p_taken_at - interval '30 minutes') then
    return jsonb_build_object('ok', true, 'duplicate', true, 'remaining_quantity', v_row.remaining_quantity);
  end if;
  insert into public.scratch_doses (item_id, taken_at) values (p_item, p_taken_at) returning id into v_dose;
  update public.zad_pharmacy_items set remaining_quantity = greatest(remaining_quantity - 1, 0) where id = p_item;
  return jsonb_build_object('ok', true, 'duplicate', false, 'dose_id', v_dose,
    'remaining_quantity', greatest(v_row.remaining_quantity - 1, 0), 'shopping_added', v_row.remaining_quantity - 1 <= 2);
end $$;
insert into auth.users values ('44444444-4444-4444-4444-444444444444');
insert into public.zad_users values ('44444444-4444-4444-4444-444444444444', 'ماما');
