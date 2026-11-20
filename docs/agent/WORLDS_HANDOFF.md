# Worlds UI build: handoff (2026-11-20 evening)

Read this first when resuming the "worlds" redesign. It records what is merged, what sits in open PRs, what was left half-done in worktrees, and the exact way of working that kept it moving. The owner follows progress on the live board, not in chat.

- **Live board (owner watches it):** https://claude.ai/artifact/HwDtRcvuZZiQ9Qi44gC73K
  - Its source is `zad_flutter/build/board/board.html` (gitignored), with screenshots in `build/board/shots/`.
  - Edit the `TASKS`, `SHOTS` and `WORLDS_DONE` block, then publish with `url` = the board and `files` = the new PNGs, using absolute paths.
  - If `build/` was cleaned, read the artifact back with the Artifact tool's `read` action.
- **The rules for every world** are in `docs/agent/WORLD_BRIEF.md`, outside the repo. A copy of the essentials is below in case that file is gone.
- **The owner replies and reads in Egyptian Arabic.** Every message to them is in Arabic, including short status lines.

## Status: 18 of 23 worlds are built

| World | State | Where |
|---|---|---|
| Pantry | merged | main (before 20/11) |
| Pharmacy (violet) | merged | #612 |
| Shopping, Appointments | merged | #613 |
| Transactions, Budget, Statement | merged | #614 |
| Games: Zado's Hop, Zado Sorts, Catch the Stars, ball combo | merged | #618 |
| Tasbih garden (a flower every 33, the tree grows every 99, day/night, seeds through `zad_game_reward('tasbih_garden')`) | merged | #620 |
| Subscriptions (a 30-day calendar ribbon) | **open, CI green earlier; re-check and merge** | #616 |
| Chef (scene, recipe detail, cooked sheet, Home card, meat drawing) | **open; merge before #605** | #619 |
| Places (pin with pulsing rings; tabs moved to the bottom) | **open** | #621 |
| Brain, fully dark; old sphere replaced by the living `BrainMapStage` | **open** | #622 |
| Documents, Maintenance | **open** | #623 |
| Notifications, Achievements | **open** | #625 |
| Chat, Profile, Premium, Prices, Offers, Companion | not started | — |

Other work that landed the same day:

- **#615, Play rejection fix.** The `isMonitoringTool` declaration is removed from the manifest and Gradle, and `ENABLE_KIDS_GEOFENCING` now defaults to false. Version `1.0.9+12`. Before it merged: analyze was clean, `flutter test` passed (2211 tests, `EXIT=0`), and the arm64 release build passed with no `isMonitoringTool` in the merged manifest. **The next Play upload needs `versionCode` greater than 12.**
- **#617, «حالة زاد» card on Home.** It replaces `PermissionBanners` and shows each permission's live state with its fix. When everything works it collapses to one green line; a snoozed row keeps the line amber, never green.
  - Location fixes, from measured causes:
    - The fix uses `LocationAccuracy.high`. The server still receives the coarse point (3 decimals, about 110 m).
    - The last-known fallback is refused when older than 30 minutes (`kLastKnownFor`), in both the nearby screen and street alerts.
    - Geofences are re-registered on start and on every resume.
- **#605, Amazon on every missing item:** still open, with conflicts. Its old pantry, shopping and recipe edits must be ported onto the new world layouts. Do it **after** #619 merges, as one builder slice.

## Unfinished work in worktrees (check these first)

All worktrees live in `/workspaces/zad-w<name>`. **Never put anything in /tmp; it is wiped mid-session.** That happened twice on 20/11 and cost two builders' work.

- `/workspaces/zad-wbrain`, `/workspaces/zad-wdocs`: pushed as #622 and #623. Remove them after merge.
- `/workspaces/zad-wnotif` (`feat/worlds-notif`)
  - **Notifications:** every notification wears its SOURCE world's colour and art, grouped by day in the account zone.
  - **Achievements:** a trophy shelf, with locked badges as grey silhouettes.
  - Both are WIP and nothing is committed yet.
- `/workspaces/zad-wtasbih`: merged, so remove it.
- `/workspaces/zad-wsubs`, `/workspaces/zad-wchef`, `/workspaces/zad-wplaces`: remove each once its PR merges, to free disk (the root disk is 32 GB and was at 117 MB free once).
- `/workspaces/zad-terms` (`feat/terms-reconsent`): older uncommitted work. Not part of the worlds; don't touch it without asking.

## How the work ran (cheap and fast)

1. **One builder per world.** Use `sonnet-builder` with a short prompt: "Read docs/agent/WORLD_BRIEF.md first", then the world name, the `ZadWorld` value, the worktree, its screens, what to keep, and its tests. Run at most 3 builders at once.
2. **Fresh worktree off origin/main:**
   ```
   git worktree add -b feat/worlds-<x> /workspaces/zad-w<x> origin/main
   cp zad_flutter/env.json <wt>/zad_flutter/
   mkdir -p <wt>/zad_flutter/build
   ```
3. **Verify every builder report myself.** Open the screenshot PNG (`build/screens/world_<x>.png`) and check the commit. A builder saying "done" is not evidence.
4. **Push and open a PR.** First run `docs/agent/worlds_tools/merge_main.sh <worktree>`. It merges origin/main, unions the ARB conflicts (every world adds keys to the same three ARB files, so each merge conflicts there), runs `gen-l10n` and analyze, commits and pushes. The ARB merge is done by `docs/agent/worlds_tools/arb_union.py` (`--theirs` keeps main's value on a clash).
5. **CI (`build-debug-apk.yml` → `verify`)** runs `flutter analyze` and the full `flutter test`. Merge when it is green; the owner allows merging after green CI.
   - **After each merge, the other open PRs conflict again** (ARB files). Run `merge_main.sh` on them and wait for CI again.
   - The `saudi_coverage_test` fails when a new Egyptian-only string lacks an `app_ar_SA.arb` entry.
6. **After each slice, update the board.**

### The brief's essentials, in case `world_brief.md` is lost

Every page uses `ZadWorldScaffold` and its `ZadWorld` value:
- a painted, animated scene with the user's companion in a pose;
- a heavy title and a real state line;
- calm white `ZadWorldCard` cards;
- the «متصلة بـ» strip;
- `ZadWorldTone.dark` only for the brain.

The owner's rules:
- Merge into the existing screen and never drop a feature.
- No patching: rebuild the body and delete the old layout.
- No emoji, only drawings (`shared/worlds/art`).
- Strings go in app_ar (Egyptian), app_ar_SA (Saudi) and app_en.
- Never raise the arabic-literals baseline.
- Tap targets are ≥44dp, and the primary action is docked at the bottom.
- Every list has an empty state, and reduced motion is respected.
- No LLM call on screen open.
- Respect the feature boundaries.
- Seeds come only from the server writer `zad_game_reward`.

Testing:
- Widget tests set reduced motion, because looping scenes make `pumpAndSettle` time out.
- Screenshot tests are skipped unless `ZAD_SCREENS=1`: 430x932 at dpr 2, `loadZadFonts`, `matchesGoldenFile('../../../build/screens/world_<x>.png')`.

## What is left, in order

1. Follow-ups from #625:
   - **Server achievements have no client entry.** The six ids granted by migration 20261116010000 are missing from `kAchievementCatalog`: first_receipt, first_transaction, streak_7, tasbih_tree, saved_1000 and zado_run_300. Each needs a Lottie file and a catalogue entry.
   - **Notification source is a guess.** The notification's source world is guessed from keywords. To make it exact, add a `source` column to `app_notifications`.
2. Merge #616, #619, #621, #622, #623 and #625 once green (run `merge_main.sh` again after each merge).
3. Port #605 (Amazon) onto the worlds.
4. Build the remaining worlds: chat, profile/settings (4 groups + 5 groups, including «الإعلانات والخصوصية»), premium, prices, offers, companion.
5. Wire the launch moment with Zado into the app. The Flutter code is in `docs/agent/previews/launch_moment/launch_moment.dart.txt` (copy into lib/ when wiring), which is not wired and untested. The approved preview is at the bottom of the board.
6. Before the next Play upload:
   - bump `versionCode` above 12;
   - run the full local checks (analyze, `flutter test -j 2`, a release build). The release build needs ~3 GB free on `/`, and the Gradle cache under `~/zt/gradle` gets re-downloaded if it is missing.
