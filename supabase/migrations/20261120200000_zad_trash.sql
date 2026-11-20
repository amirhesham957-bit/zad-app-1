-- سلة المحذوفات (ZAD_OR_PLAN م١.١ وم١.٢، قرار المالك ٢٠٢٦-١١-٢٠ «وقف النزيف»).
--
-- القياس على الحي يوم ٢٠/١١: من آخر يونيو اتمسح ١٢٣ صف من zad_transactions و١٣٤ من zad_inventory و١٥٠ من
-- zad_memory و١٠٤ من zad_pharmacy_items. أدوات الحذف بتاعة الموديل اتنادت مرة واحدة بس، يعني الباقي جه من
-- مصادر تانية (الموبايل، والكرونات، وكتابة الذاكرة بمسح ثم كتابة)، ومحدش كان بيسجل مين. وفوق ده، التراجع عن
-- حذف معاملة ماكانش بيرجّعها: الموديل كان بيحفظ ٤ أعمدة بس من الصف (من غير user_id)، فـzad_agent_undo
-- بيرد ownership_mismatch.
--
-- الحل هنا: أي صف بيتمسح من الجداول دي، من أي مصدر، بيتنسخ كامل في zad_trash قبل ما يختفي، ومعاه مين مسحه.
-- يفضل ٣٠ يوم، وصاحبه يقدر يرجّعه بـzad_trash_restore. ده الحذف الناعم: الجداول نفسها وكل اللي بيقراها
-- (التطبيق، والعقل، والدوال) زي ما هي، من غير عمود deleted_at لازم كل قارئ يفتكره.
--
-- مش بيتنسخ:
--   • حساب الاختبار (ACCEPTANCE_USER_ID): بيمسح مئات الصفوف في التنضيف، ومالوش قيمة.
--   • مسح الحساب (zad_purge_due_accounts بيحط zad.delete_context = 'account_purge') ومسح auth.users
--     (الصف بتاعه بيختفي قبل الجداول التابعة): العميل طلب إن داته تتمسح، فمفيش نسخة تفضل.
-- عطل في النسخ عمره ما يوقف الحذف الأصلي: warning بس.

create table if not exists public.zad_trash (
  id           bigint generated always as identity primary key,
  table_name   text not null,
  row_id       uuid,
  user_id      uuid not null,
  row_data     jsonb not null,
  deleted_at   timestamptz not null default now(),
  db_role      text,
  jwt_sub      text,
  request_path text,
  context      text,
  restored_at  timestamptz
);
comment on table public.zad_trash is
  'ZAD_OR_PLAN M1 — every row deleted from the household tables, whole, for 30 days. Restore with zad_trash_restore(id).';

create index if not exists zad_trash_user_at on public.zad_trash (user_id, deleted_at desc);
create index if not exists zad_trash_row on public.zad_trash (table_name, row_id);

-- user_id من غير مفتاح أجنبي عن قصد: مسح الحساب بيمسح السلة بإيده (تحت)، ومفتاح أجنبي كان هيوقع
-- مسح الحساب لو صف اتنسخ في نص المسح.
alter table public.zad_trash enable row level security;
drop policy if exists zad_trash_read_own on public.zad_trash;
create policy zad_trash_read_own on public.zad_trash for select using ((select auth.uid()) = user_id);
revoke all on public.zad_trash from public, anon, authenticated;
grant select on public.zad_trash to authenticated;
grant all on public.zad_trash to service_role;

create or replace function public.zad_trash_capture()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_old jsonb;
  v_user uuid;
begin
  begin
    if coalesce(current_setting('zad.delete_context', true), '') = 'account_purge' then
      return old;
    end if;
    v_old := to_jsonb(old);
    v_user := nullif(v_old->>'user_id', '')::uuid;
    if v_user is null or v_user = 'a11ce000-0000-4000-8000-00000000a11a'::uuid then
      return old;
    end if;
    -- مسح auth.users: الصف الأب اختفى قبل التابعين.
    if not exists (select 1 from auth.users u where u.id = v_user) then
      return old;
    end if;
    insert into public.zad_trash (table_name, row_id, user_id, row_data, db_role, jwt_sub, request_path, context)
    values (
      tg_table_name,
      nullif(v_old->>'id', '')::uuid,
      v_user,
      v_old,
      coalesce(nullif(current_setting('role', true), 'none'), session_user),
      auth.uid()::text,
      nullif(current_setting('request.path', true), ''),
      nullif(current_setting('zad.delete_context', true), '')
    );
  exception when others then
    raise warning '[zad_trash_capture] %: %', tg_table_name, sqlerrm;
  end;
  return old;
end;
$fn$;
revoke all on function public.zad_trash_capture() from public, anon, authenticated;

do $triggers$
declare
  t text;
begin
  foreach t in array array[
    'zad_transactions', 'zad_inventory', 'zad_pharmacy_items', 'zad_shopping_list', 'zad_subscriptions',
    'zad_debts', 'zad_obligations', 'zad_maintenance_items', 'zad_documents', 'zad_appointments',
    'zad_memory', 'zad_category_budgets'
  ] loop
    execute format('drop trigger if exists %I on public.%I', t || '_trash', t);
    execute format(
      'create trigger %I after delete on public.%I for each row execute function public.zad_trash_capture()',
      t || '_trash', t
    );
  end loop;
end;
$triggers$;

-- رجّع صف من السلة لجدوله بنفس الـid. صاحب الصف (من التطبيق) أو السيرفر بس. الجدول من القايمة بس قبل ما
-- يدخل format('%I'). لو صف بنفس الـid موجود (اترجع قبل كده أو اتكتب تاني): مرفوض، مش بيدهس.
create or replace function public.zad_trash_restore(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_row public.zad_trash%rowtype;
  v_exists boolean;
begin
  select * into v_row from public.zad_trash where id = p_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_uid is not null and v_uid is distinct from v_row.user_id then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_row.restored_at is not null then
    return jsonb_build_object('ok', false, 'error', 'already_restored');
  end if;
  if v_row.table_name not in (
    'zad_transactions', 'zad_inventory', 'zad_pharmacy_items', 'zad_shopping_list', 'zad_subscriptions',
    'zad_debts', 'zad_obligations', 'zad_maintenance_items', 'zad_documents', 'zad_appointments',
    'zad_memory', 'zad_category_budgets'
  ) then
    return jsonb_build_object('ok', false, 'error', 'table_not_restorable');
  end if;

  execute format('select exists (select 1 from public.%I where id = $1)', v_row.table_name)
    into v_exists using v_row.row_id;
  if v_exists then
    return jsonb_build_object('ok', false, 'error', 'row_exists');
  end if;

  begin
    execute format(
      'insert into public.%I select * from jsonb_populate_record(null::public.%I, $1)',
      v_row.table_name, v_row.table_name
    ) using v_row.row_data;
  exception when others then
    return jsonb_build_object('ok', false, 'error', 'insert_failed', 'detail', left(sqlerrm, 200));
  end;

  update public.zad_trash set restored_at = now() where id = p_id;
  return jsonb_build_object('ok', true, 'table', v_row.table_name, 'row_id', v_row.row_id);
end;
$fn$;
revoke all on function public.zad_trash_restore(bigint) from public, anon;
grant execute on function public.zad_trash_restore(bigint) to authenticated, service_role;

-- ٣٠ يوم، وأي صف صاحبه مابقاش موجود.
create or replace function public.zad_trash_purge()
returns integer
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_count integer;
begin
  delete from public.zad_trash t
   where t.deleted_at < now() - interval '30 days'
      or not exists (select 1 from auth.users u where u.id = t.user_id);
  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;
revoke all on function public.zad_trash_purge() from public, anon, authenticated;
grant execute on function public.zad_trash_purge() to service_role;

do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('trash-purge-daily') where exists (select 1 from cron.job where jobname = 'trash-purge-daily');
    perform cron.schedule('trash-purge-daily', '47 3 * * *', 'select public.zad_trash_purge()');
  end if;
end;
$cron$;

-- كتابة ذاكرة «نسخة واحدة» (persona، salary، …) في transaction واحدة. قبل كده: مسح كل صفوف السكوب ثم إدراج،
-- ولو الإدراج وقع الذاكرة كانت بتضيع، وكل كتابة كانت بتعدّ حذف. دلوقتي: أحدث صف بيتعدّل مكانه (نفس الـid،
-- فالروابط بتفضل)، والباقي بيتمسح (ويروح للسلة)، ولو مفيش صف بيتعمل واحد. الـembedding بيتشال لو النص اتغير،
-- والعقل بيحسبه تاني بعدها.
create or replace function public.zad_memory_replace_single(
  p_user uuid, p_scope text, p_note text, p_confidence real
) returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('zad_memory_single:' || p_user::text || ':' || p_scope));
  select id into v_id from public.zad_memory
   where user_id = p_user and scope = p_scope
   order by created_at desc, id desc
   limit 1;
  if v_id is null then
    insert into public.zad_memory (user_id, scope, note, confidence, evidence_count)
    values (p_user, p_scope, p_note, p_confidence, 1)
    returning id into v_id;
  else
    update public.zad_memory
       set embedding = case when note = p_note then embedding else null end,
           note = p_note,
           confidence = p_confidence,
           evidence_count = 1,
           last_seen = now()
     where id = v_id;
    delete from public.zad_memory where user_id = p_user and scope = p_scope and id <> v_id;
  end if;
  return v_id;
end;
$fn$;
revoke all on function public.zad_memory_replace_single(uuid, text, text, real) from public, anon, authenticated;
grant execute on function public.zad_memory_replace_single(uuid, text, text, real) to service_role;
