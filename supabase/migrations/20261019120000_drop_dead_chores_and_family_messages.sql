-- ZAD_PLAN ١.٦ — two tables nothing writes, each replaced long ago (2026-10-19).
--
-- chores sits beside family_chores and family_messages beside chat_messages (ZAD_LIVING_BRAIN.md
-- §١١و). The orphans guard (_schema/orphans_test.ts) listed both as "drop is the owner's
-- decision"; the owner handed that decision over on 2026-10-18. Checked on the live database
-- the same day: 0 rows in each, no trigger, no view, no function body names them. The only
-- code that did, delete-account's cleanup list, drops family_messages in this same commit.
--
-- sent_budget_alerts and zad_dose_log looked dead in the 18/10 review and are not:
-- notify_parents_on_child_spend dedupes on the first, and three functions read the second
-- beside zad_pharmacy_doses on purpose. Both stay.

drop table if exists public.chores;
drop table if exists public.family_messages;
