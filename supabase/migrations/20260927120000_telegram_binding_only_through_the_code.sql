-- The one-time code is the only way a Telegram chat gets bound to an account.
--
-- 20260730150000 gave clients one policy `for all using/with check (auth.uid() =
-- user_id)`. That let any signed-in client INSERT or UPDATE its own row with any
-- `chat_id` and `bound_at = now()` and skip the code entirely — binding its account to
-- someone else's (unbound) chat. From then on that person's messages to the bot were
-- written into the attacker's ledger and the attacker's pushes went to them.
--
-- What the clients actually do (Flutter `telegram_link.dart`, Kotlin
-- `SupabaseRepo.generateTelegramBindingCode` / `telegramLinkStatus` /
-- `unlinkTelegram`): insert a code row with no chat, read `bound_at`, delete to
-- unlink. They never update. Only the bot (service role, bypasses RLS) sets
-- `chat_id`/`bound_at`, and only after the code is redeemed with /start.
--
-- Checked on production before this ran: 3 rows, all bound after creation and before
-- their code expired — nothing forged.

drop policy if exists "user_own_telegram_binding" on public.telegram_bindings;

create policy "telegram_binding_read_own" on public.telegram_bindings
  for select to authenticated
  using ((select auth.uid()) = user_id);

-- A code row only: no chat, not bound.
create policy "telegram_binding_insert_code" on public.telegram_bindings
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and chat_id is null
    and bound_at is null
  );

create policy "telegram_binding_unlink_own" on public.telegram_bindings
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- No update policy, so RLS already refuses; the grant goes too, so a later
-- permissive policy cannot quietly reopen it.
revoke update on public.telegram_bindings from anon, authenticated;
