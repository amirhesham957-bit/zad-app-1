-- On top of household_shopping_scaffold.sql + 20261011140000: zad_agent_undo and
-- agent_actions as the live project has them (pg_get_functiondef 2026-10-11, md5
-- 48c6047a… before 20261011160000).
--
--   psql < supabase/sql/tests/scratch_scaffold.sql
--   psql < supabase/sql/tests/household_shopping_scaffold.sql
--   psql < supabase/migrations/20261011140000_one_household_shopping_list.sql
--   psql < supabase/sql/tests/undo_household_scaffold.sql
--   psql < supabase/migrations/20261011160000_undo_knows_the_household.sql
--   psql < supabase/sql/tests/undo_household_test.sql

\set ON_ERROR_STOP on

do $$ begin
  if exists (select 1 from pg_namespace where nspname in ('storage', 'supabase_functions', 'realtime')) then
    raise exception 'scratch database only — this is a real Supabase database';
  end if;
end $$;

create table if not exists public.agent_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  run_id uuid,
  source text not null default 'app_chat',
  tool_name text not null,
  input jsonb not null default '{}'::jsonb,
  target_table text,
  target_id uuid,
  previous_state jsonb,
  new_state jsonb,
  status text not null default 'applied',
  result_summary text,
  created_at timestamptz not null default now(),
  undone_at timestamptz,
  seq bigint generated always as identity);
-- The tables undo may write; the ones this test does not touch only need to exist.
create table if not exists public.zad_transactions (id uuid primary key, user_id uuid, amount numeric);
create table if not exists public.zad_pharmacy_doses (id uuid primary key, user_id uuid);
create table if not exists public.zad_obligations (id uuid primary key, user_id uuid);

CREATE OR REPLACE FUNCTION public.zad_agent_undo(p_action_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_act public.agent_actions%rowtype;
  v_owner_col text;
  v_set text;
  v_rows int;
  v_newer int;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;

  if p_action_id is null then
    select * into v_act from public.agent_actions
     where user_id = v_uid and status = 'applied' and target_table is not null and target_id is not null
     order by seq desc limit 1;
  else
    select * into v_act from public.agent_actions
     where id = p_action_id and user_id = v_uid;
  end if;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'no_action_to_undo');
  end if;
  if v_act.status = 'undone' then
    return jsonb_build_object('ok', false, 'error', 'already_undone');
  end if;
  if v_act.status = 'rejected' then
    return jsonb_build_object('ok', false, 'error', 'action_never_applied');
  end if;
  if v_act.target_table is null or v_act.target_id is null then
    return jsonb_build_object('ok', false, 'error', 'action_not_undoable');
  end if;

  v_owner_col := case v_act.target_table
    when 'zad_transactions'    then 'user_id'
    when 'zad_inventory'       then 'user_id'
    when 'zad_pharmacy_items'  then 'user_id'
    when 'zad_pharmacy_doses'  then 'user_id'
    when 'zad_shopping_list'   then 'user_id'
    when 'zad_obligations'     then 'user_id'
    when 'zad_users'           then 'id'
    else null
  end;
  if v_owner_col is null then
    return jsonb_build_object('ok', false, 'error', 'table_not_undoable', 'table', v_act.target_table);
  end if;

  select count(*) into v_newer from public.agent_actions
   where user_id = v_uid
     and target_table = v_act.target_table
     and target_id = v_act.target_id
     and status = 'applied'
     and seq > v_act.seq;
  if v_newer > 0 then
    return jsonb_build_object('ok', false, 'error', 'newer_action_exists', 'newer_count', v_newer);
  end if;

  if v_act.previous_state is null then
    if v_act.target_table = 'zad_users' then
      return jsonb_build_object('ok', false, 'error', 'profile_delete_refused');
    end if;
    execute format('delete from public.%I where id = $1 and %I = $2', v_act.target_table, v_owner_col)
      using v_act.target_id, v_uid;
    get diagnostics v_rows = row_count;

  elsif v_act.new_state is null then
    if (v_act.previous_state ->> v_owner_col)::uuid is distinct from v_uid then
      return jsonb_build_object('ok', false, 'error', 'ownership_mismatch');
    end if;
    execute format(
      'insert into public.%I select * from jsonb_populate_record(null::public.%I, $1)',
      v_act.target_table, v_act.target_table
    ) using v_act.previous_state;
    get diagnostics v_rows = row_count;

  else
    select string_agg(format('%I = r.%I', k, k), ', ')
      into v_set
      from jsonb_object_keys(v_act.previous_state) k
     where k <> 'id' and k <> v_owner_col;

    if v_set is null then
      return jsonb_build_object('ok', false, 'error', 'nothing_to_restore');
    end if;

    execute format(
      'update public.%I t set %s from (select * from jsonb_populate_record(null::public.%I, $3)) r
        where t.id = $1 and t.%I = $2',
      v_act.target_table, v_set, v_act.target_table, v_owner_col
    ) using v_act.target_id, v_uid, v_act.previous_state;
    get diagnostics v_rows = row_count;
  end if;

  if v_rows = 0 then
    return jsonb_build_object('ok', false, 'error', 'target_row_missing', 'table', v_act.target_table);
  end if;

  update public.agent_actions
     set status = 'undone', undone_at = now()
   where id = v_act.id;

  return jsonb_build_object(
    'ok', true,
    'action_id', v_act.id,
    'tool_name', v_act.tool_name,
    'table', v_act.target_table,
    'rows', v_rows
  );
end;
$function$;
grant execute on function public.zad_agent_undo(uuid) to authenticated;
