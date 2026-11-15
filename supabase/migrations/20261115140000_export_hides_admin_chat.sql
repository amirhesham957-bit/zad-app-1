-- «تصدير بياناتي» كان بيدّي العميل admin_chat من zad_support_access_log: رقم شات تيليجرام بتاع
-- الأدمن اللي فتح حسابه (مراجعة الأمان ١٥/١١). العميل يفضل يشوف إن حد فتح حسابه وإمتى وليه —
-- بس مش هوية الأدمن. admin_chat بقى في قائمة الأعمدة السرية؛ باقي الدالة زي ما هي.

create or replace function public.zad_export_my_data()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
set statement_timeout to '20s'
as $function$
declare
  v_user uuid := auth.uid();
  v_out jsonb := '{}'::jsonb;
  v_rows jsonb;
  v_count int;
  v_cap constant int := 2000;
  v_skip_tables constant text[] := array[
    'dashboard_admins', 'zad_rate_gate', 'zad_turn_gate', 'zad_brain_queue', 'zad_health_daily',
    'zad_device_send_keys', 'zad_fcm_tokens', 'family_typing_status'
  ];
  v_secret_cols constant text[] := array[
    'token', 'purchase_token', 'key_hash', 'fcm_tokens', 'idempotency_key', 'dedupe_hash', 'fuzzy_tokens', 'admin_chat'
  ];
  t record;
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  select to_jsonb(u) - v_secret_cols into v_rows from public.zad_users u where u.id = v_user;
  v_out := v_out || jsonb_build_object('zad_users', case when v_rows is null then '[]'::jsonb else jsonb_build_array(v_rows) end);

  for t in
    select c.table_name
      from information_schema.columns c
      join information_schema.tables tb
        on tb.table_schema = c.table_schema and tb.table_name = c.table_name and tb.table_type = 'BASE TABLE'
     where c.table_schema = 'public' and c.column_name = 'user_id' and c.data_type = 'uuid'
       and c.table_name <> all (v_skip_tables)
     order by c.table_name
  loop
    execute format(
      'select coalesce(jsonb_agg(to_jsonb(x) - $2), ''[]''::jsonb), count(*)::int
         from (select * from public.%I where user_id = $1 limit %s) x',
      t.table_name, v_cap + 1)
      into v_rows, v_count
      using v_user, v_secret_cols;
    if v_count > 0 then
      if v_count > v_cap then
        v_rows := v_rows - v_cap;  -- الصف الزيادة كان بس عشان نعرف إنه اتقص
        v_out := v_out || jsonb_build_object('_truncated', coalesce(v_out -> '_truncated', '[]'::jsonb) || to_jsonb(t.table_name));
      end if;
      v_out := v_out || jsonb_build_object(t.table_name, v_rows);
    end if;
  end loop;

  return jsonb_build_object(
    'exported_at', now(),
    'user_id', v_user,
    'row_cap_per_table', v_cap,
    'data', v_out
  );
end;
$function$;

revoke all on function public.zad_export_my_data() from public, anon;
grant execute on function public.zad_export_my_data() to authenticated;
