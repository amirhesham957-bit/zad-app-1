-- التراجع يعرف باقي جداول الحذف (ZAD_OR_PLAN م١.٦، ٢١/١١).
--
-- قبل كده zad_agent_undo كان بيعرف ٧ جداول بس، فـ«امسح الاشتراك» و«امسح الدين» و«امسح الموعد» و«انسى ده»
-- كانوا بيتسجلوا في agent_actions بصورة الصف قبل الحذف، والتراجع يرد table_not_undoable. دلوقتي الـ١٢ جدول
-- اللي عليهم سلة zad_trash كلهم بيترجعوا، بنفس الفحوص (أحدث فعل، الملكية، اتراجع قبل كده).
--
-- وعلّة اتصلحت معاها: delete_obligation مش بيمسح الصف، بيخليه active=false، وبيتسجل كحذف (new_state فاضي).
-- التراجع كان بيحاول insert لصف موجود فيقع بـunique_violation. دلوقتي لو الصف لسه موجود بيرجّع أعمدته
-- (زي تراجع التعديل)، ولو اتمسح فعلاً بيتعمل insert، ولو اترجع قبل كده من السلة بيرد row_exists بدل الوقوع.
-- وبعد ما الحذف يتراجع، صف السلة بتاعه بيتقفل (restored_at) عشان مايترجعش مرتين.
--
-- الجسم هو النسخة الحية (pg_get_functiondef ٢١/١١، بعد ترقيعات 20261011160000) + التغييرات دي بس.
-- الجداول الجديدة ملكيتها بـuser_id بس (مش العيلة): الأضيق، ومحدش بيترجع له صف مش بتاعه.

create or replace function public.zad_agent_undo(p_action_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_act public.agent_actions%rowtype;
  v_owner_col text;
  v_set text;
  v_rows int;
  v_newer int;
  v_scope text;
  v_exists boolean;
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
    when 'zad_transactions'      then 'user_id'
    when 'zad_inventory'         then 'user_id'
    when 'zad_pharmacy_items'    then 'user_id'
    when 'zad_pharmacy_doses'    then 'user_id'
    when 'zad_shopping_list'     then 'user_id'
    when 'zad_obligations'       then 'user_id'
    when 'zad_subscriptions'     then 'user_id'
    when 'zad_debts'             then 'user_id'
    when 'zad_maintenance_items' then 'user_id'
    when 'zad_documents'         then 'user_id'
    when 'zad_appointments'      then 'user_id'
    when 'zad_memory'            then 'user_id'
    when 'zad_category_budgets'  then 'user_id'
    when 'zad_users'             then 'id'
    else null
  end;
  if v_owner_col is null then
    return jsonb_build_object('ok', false, 'error', 'table_not_undoable', 'table', v_act.target_table);
  end if;

  -- المخزن والقايمة للبيت (20261011160000): الصف بتاع اللي بيتراجع أو بتاع عيلته، زي RLS بتاعهم.
  v_scope := case when v_act.target_table in ('zad_inventory', 'zad_shopping_list')
    then format('(t.%1$I = $2 or t.family_id in (select m.family_id from public.family_members m where m.user_id = $2))', v_owner_col)
    else format('t.%I = $2', v_owner_col)
  end;

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
    execute format('delete from public.%I t where t.id = $1 and ', v_act.target_table) || v_scope
      using v_act.target_id, v_uid;
    get diagnostics v_rows = row_count;

  else
    if v_act.new_state is null
       and (v_act.previous_state ->> v_owner_col)::uuid is distinct from v_uid
       and not (v_act.target_table in ('zad_inventory', 'zad_shopping_list')
                and (v_act.previous_state ->> 'family_id')::uuid in
                    (select m.family_id from public.family_members m where m.user_id = v_uid)) then
      return jsonb_build_object('ok', false, 'error', 'ownership_mismatch');
    end if;

    execute format('select exists (select 1 from public.%I where id = $1)', v_act.target_table)
      into v_exists using v_act.target_id;

    if v_act.new_state is null and not v_exists then
      -- حذف حقيقي: الصف بيرجع بنفس الـid.
      begin
        execute format(
          'insert into public.%I select * from jsonb_populate_record(null::public.%I, $1)',
          v_act.target_table, v_act.target_table
        ) using v_act.previous_state;
        get diagnostics v_rows = row_count;
      exception when unique_violation then
        return jsonb_build_object('ok', false, 'error', 'row_exists', 'table', v_act.target_table);
      end;
      -- صف السلة بتاع الحذف ده اتقفل، عشان «رجّع اللي اتمسح» مايرجعوش تاني.
      update public.zad_trash set restored_at = now()
       where table_name = v_act.target_table and row_id = v_act.target_id and user_id = v_uid and restored_at is null;
    else
      -- تعديل، أو «حذف» ناعم والصف لسه موجود (delete_obligation = active false): الأعمدة اللي اتغيرت بترجع.
      select string_agg(format('%I = r.%I', k, k), ', ')
        into v_set
        from jsonb_object_keys(v_act.previous_state) k
       where k <> 'id' and k <> v_owner_col;

      if v_set is null then
        return jsonb_build_object('ok', false, 'error', 'nothing_to_restore');
      end if;

      execute format(
        'update public.%I t set %s from (select * from jsonb_populate_record(null::public.%I, $3)) r
          where t.id = $1 and ' || v_scope, v_act.target_table, v_set, v_act.target_table
      ) using v_act.target_id, v_uid, v_act.previous_state;
      get diagnostics v_rows = row_count;
    end if;
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

revoke all on function public.zad_agent_undo(uuid) from public, anon;
grant execute on function public.zad_agent_undo(uuid) to authenticated;
