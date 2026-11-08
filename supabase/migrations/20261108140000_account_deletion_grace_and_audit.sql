-- مهلة ١٤ يوم قبل مسح الحساب، وسجل تدقيق للحذف (قرار المالك ٢٠٢٦-١١-٠٨).
--
-- يوم ٣/١١ زرار «حذف الحساب» مسح حساب بكل حركاته في لحظة، ولا كان فيه سجل يقول اتمسح إمتى ولا بإيد مين؛
-- التحقيق اتعمل من آثار جانبية. دلوقتي:
--   • الطلب بيتسجل بس، وقنوات الحساب بتتقفل عشان مايوصلوش رسايل، والمسح الفعلي بعد ١٤ يوم من كرون.
--   • لو رجع قبلها التطبيق بيسأله يسترجع حسابه، وربط تليجرام بيرجع زي ما كان.
--   • كل صف بيتمسح من zad_transactions وzad_users بيتسجل (من غير مبالغ ولا نصوص).

create table if not exists public.zad_deletion_audit (
  id             bigint generated always as identity primary key,
  at             timestamptz not null default now(),
  event          text not null check (event in ('row_delete', 'truncate', 'account_requested', 'account_cancelled', 'account_purged')),
  table_name     text,
  row_id         text,
  owner_id       uuid,
  row_created_at timestamptz,
  db_role        text,
  jwt_sub        text,
  request_path   text,
  context        text
);
create index if not exists zad_deletion_audit_at on public.zad_deletion_audit (at desc);
create index if not exists zad_deletion_audit_owner on public.zad_deletion_audit (owner_id, at desc);
alter table public.zad_deletion_audit enable row level security;
revoke all on public.zad_deletion_audit from public, anon, authenticated;
grant select on public.zad_deletion_audit to service_role;

-- user_id من غير مفتاح أجنبي عن قصد: الصف بيفضل بعد مسح الحساب كإثبات إنه اتمسح.
create table if not exists public.zad_account_deletions (
  user_id          uuid primary key,
  status           text not null check (status in ('pending', 'cancelled', 'purged')),
  requested_at     timestamptz not null default now(),
  purge_at         timestamptz not null,
  cancelled_at     timestamptz,
  purged_at        timestamptz,
  telegram_chat_id bigint,
  last_error       text
);
create index if not exists zad_account_deletions_due on public.zad_account_deletions (purge_at) where status = 'pending';
alter table public.zad_account_deletions enable row level security;
revoke all on public.zad_account_deletions from public, anon, authenticated;
grant select on public.zad_account_deletions to service_role;

create or replace function public.zad_audit_write(
  p_event text, p_table text, p_row_id text, p_owner uuid, p_row_created_at timestamptz
) returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  insert into zad_deletion_audit (event, table_name, row_id, owner_id, row_created_at, db_role, jwt_sub, request_path, context)
  values (
    p_event, p_table, p_row_id, p_owner, p_row_created_at,
    coalesce(nullif(current_setting('role', true), 'none'), session_user),
    auth.uid()::text,
    nullif(current_setting('request.path', true), ''),
    nullif(current_setting('zad.delete_context', true), '')
  );
end;
$fn$;
revoke all on function public.zad_audit_write(text, text, text, uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.zad_audit_write(text, text, text, uuid, timestamptz) to service_role;

-- عطل في السجل مايوقفش حذف العميل نفسه.
create or replace function public.zad_audit_row_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_old jsonb;
begin
  if tg_op = 'TRUNCATE' then
    perform zad_audit_write('truncate', tg_table_name, null, null, null);
    return null;
  end if;
  v_old := to_jsonb(old);
  perform zad_audit_write(
    'row_delete', tg_table_name, v_old->>'id',
    coalesce(v_old->>'user_id', case when tg_table_name = 'zad_users' then v_old->>'id' end)::uuid,
    (v_old->>'created_at')::timestamptz
  );
  return old;
exception when others then
  raise warning '[zad_audit_row_delete] %', sqlerrm;
  return case when tg_op = 'TRUNCATE' then null else old end;
end;
$fn$;
revoke all on function public.zad_audit_row_delete() from public, anon, authenticated;

drop trigger if exists zad_transactions_audit_delete on public.zad_transactions;
create trigger zad_transactions_audit_delete after delete on public.zad_transactions
  for each row execute function public.zad_audit_row_delete();
drop trigger if exists zad_transactions_audit_truncate on public.zad_transactions;
create trigger zad_transactions_audit_truncate before truncate on public.zad_transactions
  for each statement execute function public.zad_audit_row_delete();
drop trigger if exists zad_users_audit_delete on public.zad_users;
create trigger zad_users_audit_delete after delete on public.zad_users
  for each row execute function public.zad_audit_row_delete();

-- العميل بيطلب لنفسه بس (auth.uid())، وطلب مكرر مايمدّش الميعاد.
create or replace function public.zad_request_account_deletion()
returns timestamptz
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_user uuid := auth.uid();
  v_chat bigint;
  v_purge timestamptz;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;
  select purge_at into v_purge from zad_account_deletions where user_id = v_user and status = 'pending';
  if v_purge is not null then
    return v_purge;
  end if;
  select chat_id into v_chat from telegram_bindings where user_id = v_user and chat_id is not null limit 1;
  v_purge := now() + interval '14 days';
  insert into zad_account_deletions (user_id, status, requested_at, purge_at, telegram_chat_id)
  values (v_user, 'pending', now(), v_purge, v_chat)
  on conflict (user_id) do update
    set status = 'pending', requested_at = now(), purge_at = excluded.purge_at,
        cancelled_at = null, purged_at = null, telegram_chat_id = excluded.telegram_chat_id, last_error = null;
  -- من غير قناة مفيش رسايل لحساب صاحبه طلب يمشي. الموبايل بيسجّل توكنه تاني لما يرجع.
  delete from telegram_bindings where user_id = v_user;
  delete from zad_fcm_tokens where user_id = v_user;
  update agent_tasks set status = 'cancelled', result = 'account_deletion_requested', updated_at = now()
    where user_id = v_user and status = 'pending';
  perform zad_audit_write('account_requested', 'zad_account_deletions', v_user::text, v_user, null);
  return v_purge;
end;
$fn$;
revoke all on function public.zad_request_account_deletion() from public, anon;
grant execute on function public.zad_request_account_deletion() to authenticated, service_role;

create or replace function public.zad_my_account_deletion()
returns timestamptz
language sql
stable
security definer
set search_path = public
as $fn$
  select purge_at from zad_account_deletions where user_id = auth.uid() and status = 'pending';
$fn$;
revoke all on function public.zad_my_account_deletion() from public, anon;
grant execute on function public.zad_my_account_deletion() to authenticated, service_role;

create or replace function public.zad_cancel_account_deletion()
returns boolean
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_user uuid := auth.uid();
  v_chat bigint;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;
  update zad_account_deletions
    set status = 'cancelled', cancelled_at = now(), last_error = null
    where user_id = v_user and status = 'pending'
    returning telegram_chat_id into v_chat;
  if not found then
    return false;
  end if;
  -- المحادثة ممكن تكون اتربطت بحساب تاني في المهلة، وساعتها تفضل عنده.
  if v_chat is not null and not exists (select 1 from telegram_bindings where chat_id = v_chat) then
    insert into telegram_bindings (user_id, chat_id, binding_code, code_expires_at, bound_at)
    values (v_user, v_chat, 'RESTORED-' || gen_random_uuid()::text, now(), now());
  end if;
  update zad_account_deletions set telegram_chat_id = null where user_id = v_user;
  perform zad_audit_write('account_cancelled', 'zad_account_deletions', v_user::text, v_user, null);
  return true;
end;
$fn$;
revoke all on function public.zad_cancel_account_deletion() from public, anon;
grant execute on function public.zad_cancel_account_deletion() to authenticated, service_role;

-- كل حساب في بلوك لوحده: حساب بيقع مايوقفش الباقي، وسبب الوقوع بيتكتب في last_error.
create or replace function public.zad_purge_due_accounts()
returns integer
language plpgsql
security definer
set search_path = public, auth
as $fn$
declare
  r record;
  v_count integer := 0;
begin
  perform set_config('zad.delete_context', 'account_purge', true);
  for r in
    select user_id from zad_account_deletions where status = 'pending' and purge_at <= now() order by purge_at
  loop
    begin
      -- الجداول اللي مالهاش مفتاح أجنبي على auth.users؛ الباقي بيتمسح مع المستخدم.
      delete from zad_inventory where user_id = r.user_id;
      delete from zad_transactions where user_id = r.user_id;
      delete from zad_subscriptions where user_id = r.user_id;
      delete from zad_shopping_list where user_id = r.user_id;
      delete from app_notifications where user_id = r.user_id;
      delete from affiliate_clicks where user_id = r.user_id;
      delete from affiliate_catalog_requests where user_id = r.user_id;
      delete from family_members where user_id = r.user_id;
      delete from zad_deal_reports where user_id = r.user_id;
      delete from zad_family_join_attempts where user_id = r.user_id;
      delete from zad_health_daily where user_id = r.user_id;
      delete from chat_messages where sender_id = r.user_id;
      delete from zad_users where id = r.user_id;
      delete from auth.users where id = r.user_id;
      update zad_account_deletions
        set status = 'purged', purged_at = now(), telegram_chat_id = null, last_error = null
        where user_id = r.user_id;
      perform zad_audit_write('account_purged', 'zad_account_deletions', r.user_id::text, r.user_id, null);
      v_count := v_count + 1;
    exception when others then
      update zad_account_deletions set last_error = left(sqlerrm, 300) where user_id = r.user_id;
      raise warning '[zad_purge_due_accounts] %: %', r.user_id, sqlerrm;
    end;
  end loop;
  delete from zad_deletion_audit where event = 'row_delete' and at < now() - interval '180 days';
  return v_count;
end;
$fn$;
revoke all on function public.zad_purge_due_accounts() from public, anon, authenticated;
grant execute on function public.zad_purge_due_accounts() to service_role;

do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('account-purge-daily') where exists (select 1 from cron.job where jobname = 'account-purge-daily');
    perform cron.schedule('account-purge-daily', '41 3 * * *', 'select public.zad_purge_due_accounts()');
  end if;
end;
$cron$;
