# UI overhaul: the ledger

**Read this before touching any screen, and update it in the commit that changes one.**
It records what changed, how far each change was really checked, what is broken and what
is left, so a fix in one place doesn't quietly break another. If this file and the code
disagree, the code is right and this file gets corrected.

The owner's request list is the source of this work. The owner's code rules are at the end.

## How far each thing was checked

"Tests" means `flutter analyze` and the full `flutter test`, which include
`test/app/shell_walkthrough_test.dart`. "Phone" means seen working on the emulator on the
owner's real account, where only read-only taps are allowed.

| PR | What changed | Tests | Phone |
|---|---|---|---|
| #438 | «ضيف للبيت» is no longer logged as an expense | passed, merged | no |
| #439 | Live prices on top, language button beside the bell | passed, merged | seen on Home |
| #440 | Chef: full recipe, secrets, source link, ask the chef | passed, merged | yes: suggestions, full recipe, secrets; the source link needs a recipe that has one |
| #441 | Family: named header, labelled buttons, iPhone tool sheet, chat bubbles | passed, merged | yes: header, tool sheet, members tab; fixes below in the next APK |
| #442 | Brain: live money pulse, ring that answers a touch, charts from the first expense | passed, merged | yes: pulse card, 7/14/30, highest day |
| #443 | Profile: coloured badges, language, companion and Premium rows | passed, merged | yes: header and first groups; lower rows not opened |
| #444 | Guided tour over the real buttons, button on Home | passed, merged | yes: all 8 stops |
| #445 | Home needs: item photo, animation when there is none, store ids pinned by a test | passed, merged | not yet, needs the next APK |

## Open bugs

- **Signing:** two CI builds on 2026-11-09 carried different keys, so Android refused to update one over the other. The `ZAD_DEBUG_KEYSTORE_B64` secret is missing or invalid, and only a person can set it. Until then an APK update on the owner's phone means uninstalling first.
- The tour button's accessibility node is full width while only the pill can be tapped.

## Left to do

- Verify on the phone everything marked "no" above.
- Luxury look on every remaining screen, iPhone-style components, animation, drawings.
- The occasion's vibe across the app, mostly in Premium, with small personal discounts.
- Chef: famous chefs need the owner's TikTok handles for `RECIPE_ACCOUNTS`.
- Brain map: a 3D sphere already exists (`knowledge_map_screen.dart`). Judge it on the phone before rebuilding.
- Emoji elsewhere (pantry rows and others): the owner wants photos, not emoji.
- Explainer video.
- Privacy policy (Google Site, v3.1) must match the app: AdMob, Sentry, Firebase, background location, Gemini, Azure, Telegram.
- Audit of Supabase columns per screen, and UI for tables that have none.
- "Anything I ask the bot isn't in the UI": still to verify.
- 136 of 499 Dart files are over 300 lines (measured 2026-11-09). Split one folder at a time.
- iPhone: there is no `ios/` folder yet.

## Checked and found fine (2026-11-09)

- All 62 tables and 10 functions the app calls directly exist on the live database; all 159 tables have RLS on. Column types were not checked.
- Each need's Amazon link carries the store's own id: `zad04-21` for amazon.eg, `zad0b-21` for amazon.sa.

## Traps already paid for

- Running "Build Flutter Debug APK" by hand on a feature branch uploads that build to Google Play. Don't. PR runs build no APK; take it from a `main` run.
- A new merge cancels the running `main` build, so wait for the last one.
- Parallel branches always conflict in the ARB and generated l10n files. Merge the keys of both, regenerate, and check for conflict markers before committing.
- `/tmp` can be wiped between sessions, including the Android SDK and scratch scripts.
- The emulator must stay in airplane mode with Wi-Fi on, or the app reports the US and marks the account as travelling.
- Tests miss what a real phone shows: the family overflow appeared only on the emulator. Check every changed screen there.
- Look at the screen before every emulator tap. A back press can leave the app and the next tap lands on the launcher.
- Never tap «اعملها», add, delete or «حذف العائلة» on the owner's real account.

## Decisions waiting on the owner

- Folder layout: `pages/`, `components/` and `data/` inside each feature (recommended), or one top-level `lib/pages/`.
- TikTok handles for famous chefs.
- iPhone cannot read other apps' notifications, so bank reading needs another route there.

## The owner's code rules (2026-11-09)

Readable by a beginner. Screens in `pages/`, shared pieces in `components/`, saving and
loading in `data/`. One job per file. No file over 300 lines. Check for an existing piece
before writing a new one. Clean up one folder at a time without changing behaviour. Legal
sources only: official APIs and the search pool, no scraping of TikTok or Instagram, no
proxy rotation. Zero-cost infrastructure. Keep the `admob-ssv` verification.
