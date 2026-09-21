-- The app can put off its own dose, and the server hears it.
--
-- `zad_dose_snoozes` (20260919000000) was written only by the Telegram bot, on the
-- service-role key; authenticated clients had a select policy and nothing else. So a
-- customer who tapped «أجّل» in the app quietened the app and nothing more: the cron's
-- `zad_enqueue_missed_doses` never saw the snooze, and the nudge and the "you missed
-- it" message for the same dose still went out through the bot — conflicting reminders
-- for a medicine the customer had just deferred. Owner decision 2026-09-21: an app
-- snooze must bind the server and the bot too.
--
-- Nothing else needs to change for that. The cron already drops a dose from every
-- reminder window while a snooze row for it is in force, and sends exactly one
-- `dose_due` when the snooze ends; it does not care who wrote the row.
--
-- Two policies, not one:
--
--   insert — the first snooze of a slot.
--   update — the second. The key is (user_id, item_id, scheduled_at), and a client
--            snoozes with `upsert … on conflict`, as the bot does. Under RLS a conflict
--            takes the UPDATE path, so with an insert policy alone the second snooze of
--            the same dose would be refused.
--
-- Both check that the medicine is the caller's own, not only the row's user_id. The
-- cron matches a snooze to an item with the same user_id, so a row naming someone
-- else's item would do nothing — but a client-supplied id is never trusted on its own
-- (CLAUDE.md, secure-coding checklist).
--
-- No delete policy: a snooze is never undone early. Taking the dose is what ends it,
-- and the cron already skips a dose that has been taken.
--
-- Idempotent (drop if exists / create), because it was also run by hand against the
-- live project on 2026-09-21 on the owner's instruction, ahead of reaching the ship
-- repo's CI; when CI pushes this file it runs again and changes nothing.

drop policy if exists "dose snoozes: owner inserts" on public.zad_dose_snoozes;
create policy "dose snoozes: owner inserts" on public.zad_dose_snoozes
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.zad_pharmacy_items p
      where p.id = item_id and p.user_id = (select auth.uid())
    )
  );

drop policy if exists "dose snoozes: owner updates" on public.zad_dose_snoozes;
create policy "dose snoozes: owner updates" on public.zad_dose_snoozes
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.zad_pharmacy_items p
      where p.id = item_id and p.user_id = (select auth.uid())
    )
  );
