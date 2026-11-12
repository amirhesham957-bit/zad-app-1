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
| — | «ملفي» (ZAD_PLAN ١٠.١٦ شريحة ٥): chips «منطقتك» — حجازي/نجدي/شرقي/جنوبي/عام — only when the dialect is Saudi (chosen, or a Saudi account with none); the Gulf markets (AE/QA/KW/BH/OM) and the «خليجي» dialect read the `ar_SA` screens | `flutter analyze` clean, 2,111 tests incl. the shell walkthrough | no |
| — | بيتي tidied (ZAD_PLAN ١٠.١ slice 5): one add button, on the right (it sat on the left beside a second camera button — the bar's camera is the way to scan); the − / + steppers are 44dp (were 26); «خلص» on the card takes a row to zero as one use, with «تراجع»; a tap on the card edits it and delete moved into the edit dialog; an empty pantry shows «أضف أساسيات بيتك بلمسة» — the market's staples ticked (Egypt: لبن/عيش, Gulf: حليب/خبز/تمر), one button adds them, a receipt link under it | widget tests (`pantry_cleanup_test.dart`), the 44dp guard mutation-checked, analyze, full suite | no |
| — | بيتي, «منخفض» (ZAD_PLAN ١٠.١ slice 3): a row's low level is a quarter of what was added, never below half a counted pack / 0.25 kg·l / 100 g·ml — the same rule on the phone (`defaultLowStockThreshold`) and in the server's insert trigger (`zad_default_low_stock_threshold`); the column's default of 2 is gone and the rows that carried it are recomputed (live: 29 of 40 «منخفض» ⇒ 2). The low banner names what is short instead of «(غير محدد)» | SQL test on a scratch Postgres + mutation; Flutter unit test, analyze, full suite | no |
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
| — | Ads (owner 11/11: one ad per AI request and per receipt scan, never over a task or a button): an inline «إعلان» banner in its own room under each reply that answered a request in this run, and on the «بقرا الفاتورة…» wait; a full-screen ad on every third AI reply (after the reply is on screen) and after a scan is saved, both under the existing pacer; a native ad (Google's small template, its own Ad badge) between the cards of the deals list and the recipes list, after the third card and then every sixth. CI now passes `ADMOB_INTERSTITIAL_UNIT`, `ADMOB_INLINE_UNIT` and `ADMOB_NATIVE_UNIT` (until now no Play build had an interstitial unit at all) | passed | not yet; the owner created the banner, interstitial and native units on 11/11; they still have to be added as repository secrets |
| — | Home deals: the cheapest local store first under each item, Amazon after it; the button reads «اطلبه من أمازون، يوصلك بسرعة»; the Amazon Associates line under the list; every amazon.eg/sa link the phone opens carries its own store tag. Family: on the chat tab the big card folds to one slim row (member count + SOS, back when pushed), and the screen no longer lifts itself over the keyboard inside the shell | passed | not yet: the emulator logged in and showed Home, then crashed twice for lack of memory |
| — | Home in the agreed order (ZAD_PLAN 10.8, `feat/home-identity`): money ⇒ four glance tiles ⇒ «كل الأقسام» as one line (`SectionsGrid(compact: true)`; its first two rows repeated the tiles) ⇒ deals bar ⇒ **new** «ماركتات وصيدليات جنبك» bar (`ZadSlots.homeNearbyStores`, kept snapshot only, a letter mark in its kind's colour, taps open «أماكني») ⇒ Amazon ⇒ chef ⇒ brief ⇒ bank pill and latest transactions; the rest after them. The tour moved to the profile («أنا وعيلتي»), the month's PDF and the dossier to «فلوسي» under the summary, the tasbih off Home (it is in the drawer's «المزيد»), Telegram lower on Home (it also raises the link sheet). Deals bar 336 ⇒ 284 (the «why» badge on the picture, the code an icon button beside Amazon, one row pinned to the foot, squircle with a soft shadow); «بندوّرلك» is one full-width line; the Associates line only under real cards | passed (`home_deal_card_test` guards the fullest card at 284, mutation-checked at 220) | not yet; seen only in `tool/screens` renders |
| — | Home: «جهّز زاد لبيتك» is one line (`HomeActivationLine`: a ring with the steps done, «٣ من ٤», the next undone step as a button, a chevron that opens the four-step card under it), instead of the full card between the transactions and Telegram | passed (`home_activation_line_test`: under 80dp tall, the step and the line act apart) | not yet; seen in a `tool/screens` render |
| — | Deals bar: the running occasion's badge and name beside «عروض على نواقصك» in its own colour (`OccasionMark`), passed from Home through `ZadSlots.homeDealsCarousel(occasion:)` so the deals feature never reads Home's campaign provider; only when the occasion's colours read on white | passed (`occasion_mark_test`) | not yet; needs a running campaign |
| — | Deals bar, SA/AE accounts: SHEIN offers from `zad_affiliate_offers` after the local deals and Amazon, the size of a deal card (picture, name, «تسوّق على SHEIN», a copy button only for a real shopper code), with SHEIN's commission line under them. The owner's referral code is never shown | passed (`shein_offers_test`: parser keeps onelink rows only — mutation-checked —, the card fits 284, `B8U6U` absent from `lib/`) | not yet; needs offers in the table and a Saudi account |
| — | Every tab: the header's 26sp title folds into the bar as the tab scrolls (56dp of scroll, `headerFoldDistance`), and the tab's name takes «زاد»'s place in the bar, the way an iPhone's large title folds; switching tabs opens it again. The shell turns vertical scrolls into `fold` (0–1). Not yet glass: the content does not run under the header, so a blur would have nothing behind it | passed (`header_fold_test`: ≥40dp shorter folded, the name shows only folded, opens back) | not yet; seen in `tool/screens` renders |
| — | «بيتي» expiry (0 of 40 rows had a date, 2026-11-12): the add and edit dialogs drop the free-text `YYYY-MM-DD` box (hint `2025-12-31`) for a field that opens the calendar from the account zone's today, chips «٣ أيام» / «أسبوع» / «شهر» and an × to clear. Left empty on add, the item gets its kind's usual shelf life (`shelf_life.dart`: meat 3, bread 4, veg 5, dairy/fruit 7, eggs 21, frozen 90, dry/grocery 180, cleaning and unknown none), shown as «تقديري: …»; receipt and shelf-photo intake give new rows the same guess. The row stores no «estimated» flag (no migration), so after saving the guess reads like any date | passed (`shelf_life_test`, `pantry_view_test`: «أسبوع» saves the Riyadh day + 7; `photo_scan_test`: intake guess; guard mutation-checked) | not yet; needs the next APK |
| — | New account, Saudi (ZAD_PLAN ١٠.١ slice 1 / ١٠.١٦): the screens follow the account's market the moment the settings cache fills (`cachedAccountSettingsProvider`) instead of after a restart — the zone too; «عرّفني بيك» and «أول خطوة» and the companion's lines are in the ARB with Saudi overrides; «عرّفني بيك» asks how many live at home (`household_size`, «عايش لوحدي» answers 1); the home greets with the «أناديك بإيه» name | `flutter analyze` clean, full suite, two mutation checks | the sign-up flow was walked on the emulator before the fix (Egyptian ticker seen); after the fix not yet — the emulator crashes on draw |
| — | Home «هل خلص X؟», stagnant rows, «هيخلص إمتى» in the export: read from the server (`zad_pantry_learning`, the home's rate across members) instead of the phone's Hive learner; every answer judges a bet (`zad_pantry_bets`) through the outbox, and the card stops asking at once (ZAD_PLAN ١٠.١ slice 4a) | passed (`pantry_learning_test` ×5, two mutations; SQL `pantry_learning_test`, three mutations) | not yet; needs the migration live and the next APK |
| — | Recipe detail: «طبختها» beside «إضافة النواقص» opens a sheet of the pantry rows the recipe names, each with a suggested amount by unit and a 44dp stepper, ticked by default; «اخصم N» takes them off through the pantry's own path (ZAD_PLAN ١٠.١ slice 4c) | passed (`cooking_plan_test` ×5, two mutations; arabic-literals and sheet-safe-area guards) | not yet |

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
