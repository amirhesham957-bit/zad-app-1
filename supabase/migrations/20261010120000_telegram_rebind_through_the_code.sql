-- A fresh code moves the Telegram chat to the account that made it (2026-10-10).
--
-- Measured on the owner's chat: a new account (2026-10-06) made a code, /start refused it
-- with «فشل الربط», and the bot went on reading and writing the old account. The bot's
-- `update … set chat_id` hit `idx_telegram_bindings_chat_bound` — the chat was already
-- bound to the old account — and nothing ever freed it: the app can only unlink its own
-- row, and the bot had no /unlink.
--
-- The code is the proof. It is made only by a signed-in client (RLS:
-- `telegram_binding_insert_code`), so a chat that redeems it belongs to whoever is holding
-- that account. Redeeming therefore moves the chat, in one transaction:
--   * the chat's binding to any other account goes;
--   * that account's still-pending Telegram questions are cancelled, so a button pressed
--     later cannot write into the account the chat just left;
--   * the redeeming account's binding to some other chat goes too (one chat per account,
--     as `idx_telegram_bindings_user_bound` already says);
--   * the code row becomes the binding.
-- The same chat redeeming a second code of its own account just spends the code.
--
-- `zad_unlink_telegram_chat` is the bot's /unlink: the same clean-up without a new owner.
-- Both run as the bot (service role) only.

create or replace function public.zad_redeem_telegram_code(p_code text, p_chat_id bigint)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_link record;
  v_prev uuid;
begin
  if p_code is null or p_chat_id is null then
    return jsonb_build_object('ok', false, 'status', 'invalid');
  end if;

  select id, user_id, code_expires_at into v_link
    from public.telegram_bindings
   where binding_code = p_code and bound_at is null
   for update;
  if not found or v_link.code_expires_at < now() then
    return jsonb_build_object('ok', false, 'status', 'invalid');
  end if;

  select user_id into v_prev
    from public.telegram_bindings
   where chat_id = p_chat_id and bound_at is not null
   for update;

  if v_prev = v_link.user_id then
    delete from public.telegram_bindings where id = v_link.id;
    return jsonb_build_object('ok', true, 'status', 'already_bound', 'user_id', v_link.user_id);
  end if;

  if v_prev is not null then
    perform public._zad_release_telegram_chat(p_chat_id, v_prev);
  end if;

  delete from public.telegram_bindings
   where user_id = v_link.user_id and bound_at is not null;

  update public.telegram_bindings
     set chat_id = p_chat_id, bound_at = now()
   where id = v_link.id;

  return jsonb_build_object(
    'ok', true,
    'status', case when v_prev is null then 'bound' else 'moved' end,
    'user_id', v_link.user_id
  );
end;
$function$;

create or replace function public.zad_unlink_telegram_chat(p_chat_id bigint)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_prev uuid;
begin
  select user_id into v_prev
    from public.telegram_bindings
   where chat_id = p_chat_id and bound_at is not null
   for update;
  if v_prev is null then
    return jsonb_build_object('ok', true, 'status', 'not_bound');
  end if;
  perform public._zad_release_telegram_chat(p_chat_id, v_prev);
  return jsonb_build_object('ok', true, 'status', 'unlinked', 'user_id', v_prev);
end;
$function$;

-- The chat leaves `p_user`: its binding goes and nothing it was asked can still be answered.
create or replace function public._zad_release_telegram_chat(p_chat_id bigint, p_user uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  delete from public.telegram_bindings
   where chat_id = p_chat_id and user_id = p_user and bound_at is not null;
  update public.telegram_pending_writes set status = 'cancelled'
   where chat_id = p_chat_id and user_id = p_user and status = 'pending';
  update public.telegram_pending_pharmacy set status = 'cancelled'
   where chat_id = p_chat_id and user_id = p_user and status = 'pending';
  update public.telegram_pending_tools set status = 'cancelled'
   where chat_id = p_chat_id and user_id = p_user and status = 'pending';
  -- Check-in prompts carry no chat; an account with no chat left has nowhere to answer them.
  update public.telegram_checkin_prompts set status = 'expired'
   where user_id = p_user and status = 'pending';
end;
$function$;

revoke all on function public.zad_redeem_telegram_code(text, bigint) from public, anon, authenticated;
revoke all on function public.zad_unlink_telegram_chat(bigint) from public, anon, authenticated;
revoke all on function public._zad_release_telegram_chat(bigint, uuid) from public, anon, authenticated;
grant execute on function public.zad_redeem_telegram_code(text, bigint) to service_role;
grant execute on function public.zad_unlink_telegram_chat(bigint) to service_role;
