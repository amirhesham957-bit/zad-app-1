# Worlds UI build: handoff (updated 2026-11-21, after the power cut)

## START HERE (2026-11-21)

**The previous container died in a power cut.** Work that was never pushed is gone: the companion world rebuild, Home-as-world v1, and the occasions ambience. The board had them marked done/doing; it is now corrected to **21 of 23**. Lesson: push every WIP commit before touching the board.

**State right now**
- `main` = `77bdef34` (#627 merged: profile/settings, prices, premium, chat). Everything up to #627 is merged; only #605 (Amazon) and #300 are open.
- **`feat/worlds-home` (pushed, no PR yet)**, worktree `/workspaces/zad-whome`. Home rebuilt on `ZadWorldScaffold`: account-zone sky (dawn 05-08, morning 08-12, noon 12-16, evening 16-19, night 19-05), greeting title, money state line, «عوالمك» grid in world art, new «النهارده في بيتك» card, tasbih, offers (Shein slot, nearby, Amazon). Analyze clean, `+210 ~9` tests passed, screenshot `build/screens/world_home.png`.
  - **Fix before the PR** (seen in the screenshot):
    1. With no name the title reads «نهارك سعيد يا ...» — drop «يا» when the name is empty.
    2. The tasbih card renders empty («0/0», a tofu box).
    3. «اشتراكاتك وأدويتك» duplicates «النهارده في بيتك» — merge or drop one.
  - Then: install on the emulator, screenshots to the owner, `merge_main.sh`, PR, CI, merge.
- **Board:** https://claude.ai/artifact/HwDtRcvuZZiQ9Qi44gC73K. Local source `zad_flutter/build/board/board.html` in the main checkout (gitignored). It still lacks the pharmacy (3 shots: `world_pharmacy*.png` from `test/features/pharmacy/pharmacy_family_test.dart` and `test/shared/worlds/world_scaffold_test.dart`), inventory, `games_hub.png`/`games_run.png` (`test/features/companion/games_hub_test.dart`, `test/shared/companion/games_widgets_test.dart`) and the new Home. Render with `ZAD_SCREENS=1 flutter test --update-goldens <file>`. The owner asked for these.
- **Quota mod:** `/home/codespace/.claude/dev-mods/<session>/quota` (pane «الكوتة», `/quota`, status line). It lives in the session's mods folder; a new session needs it re-created or copied (not in the repo).

**Order agreed with the owner (2026-11-21)**
1. Finish Home (3 fixes, emulator check, PR).
2. Companion world (rebuild from `shots/world_companion.png` on the board: garden scene, level/seeds/streak card, today's tasks, weekly challenge, wardrobe, docked «ربّت على زادو»), games hub as a world (`ZadWorld.games` maps to null today), «عروضي» (`ZadWorld.offers`, no screen at all).
3. Not-yet-world screens (counted 2026-11-21): family, household, brain_family (one world), savings, intelligence, nearby, scan, support (2), bank, market, proposals. Auth/onboarding keep Zado from #601; chat keeps its compact header on purpose.
4. Occasions ambience, #605 Amazon port, launch moment, the 6 missing achievements, notification `source` column, Play prep (`versionCode` > 12).
- Estimate given to the owner: 8–12 hours of work over several sessions; max 2 builders at once on this 32 GB disk.
- The family league game was planned on 15/11 and has no code.

**Environment traps (this container)**
- Root disk is 32 GB and was full twice. `/tmp` is a **separate 107 GB disk** (`/dev/sda1`), but notes say it gets wiped — keep only re-creatable things there.
- Flutter 3.47.9 at `~/flutter`; Android SDK at `~/android-sdk` (platforms 36 + 37.0, build-tools 36). The NDK was deleted to make room; Gradle re-downloads it on the next build (~2.2 GB).
- Emulator: the AVD `zadlite` (Android 11 `aosp_atd` x86_64, pixel_4, 2 GB RAM, 2G data) lives in `/tmp/zad-avd`; run with `ANDROID_AVD_HOME=/tmp/zad-avd emulator -avd zadlite -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect -no-snapshot`. It boots, the debug APK (`~/zad-home.apk`, x64) installs, but **the emulator process died twice right after launching the app**. Not diagnosed yet: next try `-gpu swangle_indirect` or `-gpu guest`, and check `/tmp/android-codespace/emu-crash-*.db`. Stop Gradle daemons first (`./gradlew --stop` in `zad_flutter/android`); they held ~5 GB of RAM.
- `zad_flutter/env.json` (gitignored) is written in both checkouts with the project's public anon key (`get_publishable_keys`).

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
