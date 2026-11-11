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
| #448 | Pantry rows, Home glance and Amazon needs share one item photo | passed, merged | not yet, needs the next APK |
| #449 | Floating buttons and the companion step aside while a list is read (Money, pantry, Home); room under each list; pantry names on two lines | passed | not yet, needs the next APK |
| #450 | Home: the tour and the occasion's story on one line; balance card in the occasion's first colour with the second as a corner glow | passed | not yet, needs the next APK; card colours seen only in a test render |
| #452 | Category ceilings on the account (`zad_category_budgets`), queued offline; the agent's `set_category_budget`; a phone's old ceilings go up once | passed | not yet, needs merging and the next APK |
| #455 | The other six screens with floating buttons (transactions, documents, maintenance, pharmacy, appointments, subscriptions) step them aside too, with room under each list | passed | not yet, needs the next APK |
| #456 | Home on the emulator (test account, White Friday): the balance card no longer fades to grey while it shrinks; the occasion banner uses the first colour with a corner glow; the greeting card's occasion outline is a faint hint | passed | seen before the fix on the emulator; after needs the next APK |
| #458 | The first three screens of a new account: «عرّفني بيك» in cards on Zad's canvas with green chosen answers; the budget gate on the canvas with a hero wallet and a large amount field, worded as the balance; «أول خطوة» with a progress bar, checks on done steps and step 3 lined up | passed | not yet, needs the next APK |
| #459 | Home: the deals on what the home is short of sit beside the pantry, subscriptions and pharmacy glance; the live-prices strip takes no room once it answered with nothing | passed | not yet, needs the next APK |
| #461 | Home shows one Telegram card at a time: the quiet «بوت زاد على تليجرام» card only when the link banner is snoozed and the account is unlinked, none once linked (seen doubled on the emulator) | passed | seen doubled before the fix; after needs the next APK |
| #462 | Home: the money comes right after the greeting, with the occasion banner and the tour below it; the glance tiles and report buttons use the same white card and coloured icon chip as the sections (`ZadIconChip`) | passed | not yet, needs the next APK; the companion should no longer sit on the balance card |
| #464 | «فلوسي»: the figures first (balance, summary, insight, obligations, category budgets), the broke-mode and 30-day offers after them, then the transactions; the balance block takes Zad's gradient and lift instead of flat green | passed | seen before the fix on the emulator; after needs the next APK |
| #465 | «بيتي»: each tab label on one line (shrinks a little when narrow); the pantry search is a filled rounded field instead of a bare underline | passed | seen before the fix on the emulator; after needs the next APK |
| #466 | «بيتي» empty states: the smart basket says «السلة فاضية» instead of «— EGP»; the pharmacy's three zero counts wait for the first medicine | passed | seen before the fix on the emulator; after needs the next APK |
| #467 | Recipes on an empty pantry: «ضيف للمخزن» in the empty state opens the add sheet; the two greyed chef buttons are hidden until the pantry has stock | passed | seen before the fix on the emulator; after needs the next APK |
| #468 | «عقل زاد» / «العائلة»: the four (and three) unnamed icons on the bar become named buttons with a coloured chip, in one row under the tabs | passed | seen unnamed before the fix; after needs the next APK |
| #469 | Home on the #467 APK: the empty live-prices strip and «ساهم بسعر» share one line; the companion peeks from the edge until the customer places it, instead of standing on the balance card | passed | both seen before the fix on the emulator; after needs the next APK |
| — | Free quota every 2 hours per kind (20 messages, 3 voice, 2 images), one balance with the bot; the ad ladder (5 · voice+5 · voice+image+5 · then 3); a paced full-screen ad at natural breaks (off in release until `ADMOB_INTERSTITIAL_UNIT` is set); the «طاقة زاد» sheet shows the three balances | passed | not yet, needs the next APK |
| — | Home deals: the cheapest local store first under each item, Amazon after it; the button reads «اطلبه من أمازون، يوصلك بسرعة»; the Amazon Associates line under the list; every amazon.eg/sa link the phone opens carries its own store tag. Family: on the chat tab the big card folds to one slim row (member count + SOS, back when pushed), and the screen no longer lifts itself over the keyboard inside the shell | passed | not yet: the emulator logged in and showed Home, then crashed twice for lack of memory |
| — | Home in the agreed order (ZAD_PLAN 10.8, `feat/home-identity`): money ⇒ four glance tiles ⇒ «كل الأقسام» as one line (`SectionsGrid(compact: true)`; its first two rows repeated the tiles) ⇒ deals bar ⇒ **new** «ماركتات وصيدليات جنبك» bar (`ZadSlots.homeNearbyStores`, kept snapshot only, a letter mark in its kind's colour, taps open «أماكني») ⇒ Amazon ⇒ chef ⇒ brief ⇒ bank pill and latest transactions; the rest after them. The tour moved to the profile («أنا وعيلتي»), the month's PDF and the dossier to «فلوسي» under the summary, the tasbih off Home (it is in the drawer's «المزيد»), Telegram lower on Home (it also raises the link sheet). Deals bar 336 ⇒ 284 (the «why» badge on the picture, the code an icon button beside Amazon, one row pinned to the foot, squircle with a soft shadow); «بندوّرلك» is one full-width line; the Associates line only under real cards | passed (`home_deal_card_test` guards the fullest card at 284, mutation-checked at 220) | not yet; seen only in `tool/screens` renders |

## Open bugs

- **Signing:** two CI builds on 2026-11-09 carried different keys, so Android refused to update one over the other. The `ZAD_DEBUG_KEYSTORE_B64` secret is missing or invalid, and only a person can set it. Until then an APK update on the owner's phone means uninstalling first.

## Left to do

- Verify on the phone everything marked "no" above.
- Luxury look on every remaining screen, iPhone-style components, animation, drawings.
- The occasion's vibe across the app, mostly in Premium, with small personal discounts.
- Chef: `nadia.elsayed.official` joined `RECIPE_ACCOUNTS`, and each country's trend hashtags (`RECIPE_HASHTAGS`) are searched like the topics (2026-11-10). More handles from the owner go in the same list.
- Brain map: a 3D sphere already exists (`knowledge_map_screen.dart`). Judge it on the phone before rebuilding.
- The bottom bar's mic still blends both occasion colours (`campaignGradient`); small enough to judge on the phone.
- Seen on the #467 APK (2026-11-10): the money now follows the greeting and the occasion banner sits under it (#462 confirmed). The empty price strip and the companion on the card were still there; #469 addresses both.
- Seen on the emulator 2026-11-10, still to do (Home order addressed on `feat/home-identity`, 11/11): Home stacks the location banner, an empty live-prices bar, «ساهم بسعر», the tour row, the greeting and the occasion banner above the money; Home mixes three tile styles (export buttons, glance cards, section squares); the companion sits on the balance card at rest.
- Recipes tab on an empty pantry: both buttons are disabled and nothing leads to the pantry (emulator, 2026-11-10).
- Explainer video.
- Privacy policy: v4.0 written to match the app (`docs/legal/privacy_policy_v4.md`, 2026-11-10). The owner pastes it into the Google Site; until then the site still says v3.1.
- Audit of Supabase columns per screen, and UI for tables that have none.
- "Anything I ask the bot isn't in the UI", measured 2026-11-09. Real accounts wrote almost nothing from app chat in 30 days (2 `set_life_goal`; the 253 runs in `agent_actions` are the acceptance account `a11ce000`). On the owner's account: 20 chat runs in 14 days, 1 write, 2 runs rejected. Causes found: "add X to my pantry quantity 1" became an expense (fixed in #438); a sleep time became a money proposal (fixed in #451); a spending cap per category had no tool because those caps lived only on the device, so the model tried `set_monthly_limit` and was refused (closed by #452). App chat text is not stored on the server, so the requests behind the other runs can't be read. Screens that load on open (appointments, debts, maintenance) are not stale after a chat.
- 136 of 499 Dart files are over 300 lines (measured 2026-11-09). Split one folder at a time.
- iPhone: there is no `ios/` folder yet.

## Checked and found fine (2026-11-09)

- All 62 tables and 10 functions the app calls directly exist on the live database; all 159 tables have RLS on. Column types were not checked.
- Each need's Amazon link carries the store's own id: `zad04-21` for amazon.eg, `zad0b-21` for amazon.sa.

## Decided

- Item pictures: a real photo that moves slowly (`ZadItemPhoto`). No animation library covers every grocery item realistically, and a video per row is too heavy.

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
- iPhone cannot read other apps' notifications, so bank reading needs another route there.

## The owner's code rules (2026-11-09)

Readable by a beginner. Screens in `pages/`, shared pieces in `components/`, saving and
loading in `data/`. One job per file. No file over 300 lines. Check for an existing piece
before writing a new one. Clean up one folder at a time without changing behaviour. Legal
sources only: official APIs and the search pool, no scraping of TikTok or Instagram, no
proxy rotation. Zero-cost infrastructure. Keep the `admob-ssv` verification.
