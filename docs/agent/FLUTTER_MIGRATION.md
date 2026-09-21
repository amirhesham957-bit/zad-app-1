# Flutter migration — status, conventions, and what is left

**Last updated 2026-09-21 (fourth session). HEAD `23dc6f54` (code), pushed** to `origin` (the personal fork `amirhesham957-bit/zad-app-1` —
see "Where the commits live" below — **a push there deploys to production**). Every
migration in the repo is live (§5 items 7 and 9).

**The decision:** the owner decided to finish the Flutter client first, whatever
it takes, and to keep going until the whole app is converted. Until then the
Kotlin app (`app/`) is still the one that ships and the one CI builds. Both
clients share one Supabase project — same tables, same RLS, same edge
functions — so the migration is a client rewrite, not a system one, and it can
land screen by screen.

Size at `427dca37` (measured then, not re-measured since — the second
session added market, subscriptions, onboarding and notifications): Flutter `lib/` is 16,309 lines
plus 10,045 lines of tests, against Kotlin's 76,148 across 34 screen files.
Twelve feature folders are ported; the list of what is left is §6.

---

## 1. Start here in a new session

1. **Check the branch against the ship repo.** `git fetch upstream && git
   rev-list --left-right --count upstream/main...HEAD`. Server work lands on
   `upstream/main`; if this fork is behind, merge it (do not hand-restore files
   — that is how the orphaned-migration problem on 2026-09-20 was fixed; memory
   note `fork-divergence-orphans-migrations`).
2. **Toolchain** (verify, do not assume — see CLAUDE.md "Response style"):
   ```sh
   export PATH="$HOME/flutter/bin:$PATH"
   export ANDROID_HOME="$HOME/android-sdk" ANDROID_SDK_ROOT="$HOME/android-sdk"
   cd zad_flutter && flutter pub get
   (cd packages/zad_bank_listener && flutter pub get)
   ```
   `env.json` (gitignored) must exist in `zad_flutter/` — recreate from
   `env.example.json`. Flutter 3.47.5 / Dart 3.13.4.
3. **Confirm the baseline before touching anything:**
   ```sh
   flutter analyze                    # must say "No issues found!"
   flutter test                       # 785 passing after the brain screens
   (cd packages/zad_bank_listener && flutter test)   # 15 passing
   flutter build apk --release --split-per-abi --dart-define-from-file=env.json
   ```
   The release APK for a phone is `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
   (~30 MB). Release is signed with debug keys (template default), so it installs
   without a keystore. After installing: Settings → Notifications → Notification
   access → enable "زاد — قراءة إشعارات البنك".

**No CI runs the Flutter app.** `.github/workflows/build-debug-apk.yml` builds
the Kotlin app only. Local runs are the only check — never report Flutter work
done without them.

---

## 2. Conventions every feature follows

Read one existing feature end to end before adding one; `features/settings/`
and `features/inventory/` are the cleanest examples.

- **Slices:** `features/<name>/{domain,data,application,presentation}`. Domain
  is pure (no clock, no storage, no network). Data holds a `*Remote` interface
  plus its `Supabase*Remote`, and a `*Repository`. Application holds Riverpod
  `Notifier`s. `lib/data/providers.dart` is the only place singletons are
  built; nothing else touches `Supabase.instance` or `Hive.box`.
- **Constructors** use the `const new(...)` / `factory fromJson(...)` style the
  codebase already has. `very_good_analysis` is strict; `flutter analyze` must
  be clean before a commit.
- **Offline first, always:** cache (Hive) → outbox → server, never the network
  first. Reads from the cache are synchronous so a screen opens on data, not a
  spinner. Every write:
  - is queued as an `OutboxEntry` whose **id is the server's conflict key**
    (`inventory:<rowId>`, `account_settings:<column>`, `dose:<item>:<slot>`), so
    re-editing replaces the queued write and a replay collides instead of
    duplicating;
  - is **read back** after the upsert and compared — `upsert` returning without
    an exception is not proof (Kotlin shipped for months on that assumption);
  - takes the **server's row as the winner** in the cache afterwards;
  - is dispatched by `OutboxKind` in `outboxProvider` — a new kind needs a
    branch there, and deletes are queued too (or the row comes back on refresh).
- **Refresh keeps queued rows.** A refresh replaces settled rows and drops ones
  the server no longer has, but never a row still pending.
- **Time:** anything civil (a dose time, an expiry date, "today") is computed
  in the **account's market zone** via `accountTimeZoneProvider`
  (`lib/core/period/account_time_zone.dart`): `marketTimeZone(country)` →
  budget snapshot zone → `UTC`. Never the device zone. Pure domain functions
  take the day/zone as arguments instead of reading the clock.
- **Data vs display strings:** categories, units, anything stored or matched on
  stays Arabic (CLAUDE.md i18n rule). E.g. the eleven transaction categories in
  `features/scan/domain/scanned_receipt.dart`, pantry units in `pantry_view.dart`.
- **Adding a Hive box** changes `ZadLocalStore`'s constructor, and every test
  harness that builds one must be updated (8 files at present:
  `auth_gate_test`, `session_controller_test`, `scan_controller_test`,
  `bank_access_controller_test`, `settings_controller_test`,
  `proposals_controller_test`, `home_screen_test`, `chat_controller_test`,
  plus `household_controllers_test` which builds its own). Known churn.
- **Screens in an `IndexedStack` build eagerly.** Anything that fetches on build
  must be built on first visit instead (see `zad_shell.dart`'s household tab
  and `household_screen.dart`).

### Test traps already paid for

- A **Hive write inside a `testWidgets` body never completes** under the faked
  clock — the test hangs. Put writes in `setUp`; make remotes used by widget
  tests *refuse* immediately so a background refresh cannot write.
- **`pumpAndSettle` times out** on any sheet with an autofocused field (the
  cursor blinks forever). Use `pump()` + `pump(400ms)`.
- Use **unique box names per test** (`'pantry$run'`) and **wait on real
  conditions** (a turn counter, `live?.isClosed == false`) rather than
  `Duration.zero` guesses.
- **`await HapticFeedback.*()` never completes under `flutter_test`** — anything
  after it (a snackbar, a pop) silently does not happen in the test. Don't await
  a haptic before something a test checks; `unawaited` it. The receipt sheet's
  `_save` still awaits one before popping (untested path).
- A Riverpod `onDispose` hook **may not touch `ref`** — capture what it needs in
  `build`.
- **Mutation-check the guards that matter**: break the rule, confirm a test
  fails, restore. It has found real gaps twice (see §4).

---

## 3. What is done

| Area | Where | Notes |
|---|---|---|
| Skeleton, design system, budget period (shared with SQL) | `app/`, `design/`, `core/period/` | earlier commits `4290096d`…`5e20b208` |
| Offline data layer — Hive CE, outbox, sync triggers | `data/` | drains on resume / reconnect / slow tick |
| Home — the green card from cache | `features/home`, `features/budget` | `onSetBudget` wired (`d41ab6e8`) |
| Bank channel — native listener + parity-tested gate | `packages/zad_bank_listener`, `features/bank` | SQLite store is a process singleton (`6cec18c1`) |
| Transactions list + manual entry | `features/transactions` | |
| Pending confirmations (proposals) | `features/proposals` | |
| Auth — login, sign-up, session gate, sign-out | `features/auth`, `app/auth_gate` | |
| Settings — monthly limit, salary day, bank permission, sign-out | `features/settings` | `d41ab6e8` |
| Receipt scanner (camera / gallery → `analyze_receipt`) | `features/scan` | `29ecf72f` |
| Chat with the agent (`zad-brain` `agent_turn_stream`) | `features/chat` | `80cc281a` |
| Voice input into the chat composer | `features/chat` | `8abcc369` |
| Pantry + shopping list (auto-add shortages) | `features/inventory` | `607d635c`, screens `427dca37` |
| Pharmacy — schedule, doses, snooze (server-side since the snooze commit) | `features/pharmacy` | `13d1d01c`, screens `427dca37` |
| Household tab (pantry / shopping / pharmacy) | `features/household` | `427dca37` |
| Market selection — gate after sign-in, 19 markets, `p_tz` fix | `features/market`, `app/auth_gate` | `cc8a0f3d` |
| Subscriptions — data layer (renewal mirror, repository, controller) | `features/subscriptions` | `ef639beb` |
| Subscriptions — screen, add/edit sheet, "دفعت", Home entry card | `features/subscriptions/presentation`, `features/home` | `ef7e4131` |
| Onboarding intro — 4 pages before login, once per phone (`device` box) | `features/onboarding` | `133adb79` |
| Notification center — `app_notifications`, read / mark-all, bell on Home | `features/notifications` | `388ee145` |
| Family membership — create / join (server functions), members, roles, leave | `features/family` | `52d80640` |
| Receipt items → pantry (grocery), shopping list ticked, consumption readings | `features/inventory/domain/receipt_intake.dart`, `features/scan` | `7124f68b` |
| Receipt items → pharmacy (restock / start medicines, per-line counts), list ticked | `features/pharmacy/domain/pharmacy_intake.dart`, `features/scan` | `b4ae5a31` |
| Pantry −/+ and hand-added rows → `manual` consumption readings | `features/inventory/application/pantry_controller.dart` | `9db280c2` |
| Recipes — شيف زاد as البيت's fourth section, recipe sheet, add-missing, like/dislike | `features/recipes` | `84c53a25` |
| Crowd prices — cheapest reported, city filter, leaderboard (no names), queued reports | `features/prices` (tag icon on البيت) | `912c23c5` |
| Shops near you — second tab of the prices screen, radius chips, list/medicine hints | `features/nearby` | `30019e51` |
| عقل زاد hub (brain icon on the chat) + سجل تعديلات زاد: agent_actions in words, undo via `zad_agent_undo` | `features/brain` | `978eecea` |
| زاد عارف عني إيه: profile (edit), habits (wipe outings), memory notes (forget) — online writes, read back | `features/brain` | `18cc32a6` |
| صحة عقل زاد: Kotlin's BrainHealth v2 verdict ported with its 20 cases; no disk cache on purpose | `features/brain` | `4fa99070` |
| خريطة زاد: areas around the budget, real edges only, "اسأل زاد" prefills the chat | `features/brain` | `23dc6f54` |

Shell tabs: الرئيسية · المعاملات · زاد (chat) · البيت · تأكيدات.

Android: `INTERNET` is declared in the **main** manifest (the template only put
it in debug/profile, so every release build had no network — `51608a88`);
launcher label is `@string/app_name` = زاد. Declared permissions in the release
APK (merged manifest, checked with `aapt2 dump xmltree` at `30019e51`): INTERNET,
ACCESS_NETWORK_STATE, RECORD_AUDIO, ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION.
No SMS, no CAMERA (the scanner uses the system camera intent via
`image_picker`), **no ACCESS_BACKGROUND_LOCATION and no foreground-service
permission** — geolocator's `GeolocatorLocationService` is removed with
`tools:node="remove"`; keep it that way.

---

## 4. Facts learned the hard way (do not re-learn)

- **`agent_turn_stream` is not real streaming.** The server runs the whole turn,
  then slices the finished reply into 24-char SSE frames. It also silently
  returns plain JSON for replies under 40 chars, any turn that ran a tool, and
  errors. The client handles both (`chat/data/agent_remote.dart`).
- **Agent tools run on the server.** `executed` is a receipt — never replay it
  through a repository (double writes). Refresh the money screens instead.
  `proposals` go back through `agent_confirm`.
- **`receiptType: "budget_card"`** is a balance/salary screenshot, not a
  purchase. Kotlin books it as an expense (bug, still live there). Flutter
  refuses and offers it as the monthly limit.
- **Transaction `category` must be one of the eleven** standard categories; an
  unknown one is dropped, not written (orphan bucket otherwise).
- **Voice transcription** goes through `voice_agent` because it is the only
  endpoint; only `transcript` is read, and it lands in the composer, not a
  turn. Cost: one wasted `callJsonModel` per clip (see open decisions).
- **Mic lifecycle:** one session at a time, stop before dispose, <500 ms or
  <1 KB clips never sent, temp file deleted on every path.
- **Dose times** match the server regex `^([01]?[0-9]|2[0-3]):[0-5][0-9]$` —
  `24:00` is invalid and skipped. Slots are civil times in the market zone over
  today and yesterday, mirroring `zad_enqueue_missed_doses`; 3 h answer window,
  30 min nudge delay.
- **The budget's `p_tz` outranks the account's country.**
  `zad_budget_state_legacy` resolves `coalesce(nullif(p_tz,''),
  zad_market_timezone(country))` (read off the deployed function 2026-09-21).
  The client used to send the last snapshot's zone or `'UTC'`, so the first
  answer became permanent. It now sends `serverTimeZoneArgumentProvider`: the
  market zone when the device knows the country, else `''` (server decides).
  Any new RPC that takes `p_tz` should use the same provider.
- **`accountTimeZoneProvider` is a plain cached `Provider`.** Whatever changes
  the cached country must `ref.invalidate` it (the market gate does; so does
  an account change in `SessionController`).
- **Market gate rules:** decide from the settings cache; an empty cache means
  *ask the server*, never *ask the customer* (Kotlin's "pick twice" bug,
  2026-09-14). Server unreachable + nothing cached → open the app (`unknown`).
  Cached null + unreachable → keep the picker. Only a country in `kMarkets`
  counts — an unknown code would still be UTC on the server.
- **A refresh that starts before a write is sent and returns after it is
  dequeued caches the stale row** — nothing queued is left to lay over it. The
  market gate re-asserts the pick in that case; `SettingsController` (limit,
  salary day) has the same window and does not yet.
- **Subscriptions' renewal date is a mirror of
  `zad_subscription_next_renewal`**, pinned by 24 cases whose expected values
  were produced by calling the *deployed* function (it is `IMMUTABLE`, so that
  is a pure read). Re-run that query when the SQL changes. "Mark paid" pays the
  renewal the server is reserving *now* and moves `renewal_date` past it; the
  expense goes under one of the eleven categories by `type`, never the row's
  free-text category.
- **Queue before cache, not after.** `SubscriptionsRepository._save` and
  `SettingsRepository.setMarket` enqueue first: a send of the row's previous
  version that settles in the gap cannot see a newer entry and writes the
  older server row over the edit. The pantry, shopping, pharmacy and the other
  settings setters still write cache-first — same window, not yet fixed.
- **Outbox `flush` leaves a replaced entry alone** (`93e503b0`). Per-row ids
  mean an edit during a send replaces the in-flight entry; `flush` used to
  delete it unsent on success, or write the old payload back over it on
  failure.
- **Mutation checks found four real test gaps:** (4) nothing tested that a
  settling subscription send leaves a newer edit on screen. (3) (3) the market gate's
  stale-read test waited on a cache value the send had already written, so it
  passed without the fix — it now waits on the second upsert. Earlier two: (1) reading the date in UTC
  instead of the market zone passed every test because they all ran at noon UTC
  — boundary tests at 22:00Z/02:00Z now pin it; (2) slots were `TZDateTime`,
  and `TZDateTime == DateTime` is false while the reverse is true — slots are
  now plain UTC `DateTime`s.
- **Doses are recorded only through `zad_log_pharmacy_dose_atomic`** (decrements
  stock, carries fractions, adds to shopping list — one transaction). Idempotent
  on `(user_id, item_id, scheduled_at)`; `duplicate` = success.
- **App snoozes reach the server (2026-09-21).** Migration
  `20260921120000_app_snoozes_its_own_doses` adds owner INSERT *and* UPDATE
  policies on `zad_dose_snoozes` (UPDATE because a re-snooze of the same slot
  is an upsert conflict), both checking the medicine is the caller's own. It
  was **run by hand on the live project** on the owner's instruction via
  `execute_sql` — *not* `apply_migration`, so no version was stamped and the
  ship repo's `db push` history is untouched; the file is idempotent and CI
  re-runs it harmlessly. Verified as a real account in a rolled-back block:
  own insert ok, re-snooze ok, another account's medicine `42501`, posing as
  another user `42501`. Snooze length is 15 min, the bot's
  `DOSE_SNOOZE_MINUTES` (the app had 30 while claiming to match).
- **Pharmacy stock comes in through `zad_pharmacy_restock`, never an upsert**
  (`20260921140000`). The dose RPC decrements `remaining_quantity`; a client
  read-add-write races it (Kotlin's `injectPharmacyReceipt` does exactly that).
  Each restock carries a client-made id recorded in `zad_pharmacy_restocks`, so an
  outbox replay adds nothing; the outbox entry is `restock:<id>` — per purchase,
  never merged. A new medicine is created by the same call with its first stock:
  `toUpsertJson` never sends `remaining_quantity` and the column **defaults to 1**,
  so `PharmacyRepository.add` alone would land a new medicine as one tablet (no UI
  calls `add` yet — whoever adds a manual "new medicine" sheet must use
  `restockNew` or send the count). A name the server already has is restocked
  there and the phone drops its local copy.
- **A pharmacy receipt counts in dose units, not boxes.** Box contents are read
  off the printed name ("30 قرص", "120 مل"); a strength (`مجم`, `mg`) is never a
  count. When the name does not say and the medicine is counted in tablets, the
  line asks the customer (`كام قرص؟`) and is skipped if left uncounted — Kotlin
  adds the box count, so two boxes of thirty became two tablets and the "running
  out" reminder went quiet. Medicine names match stricter than pantry items:
  every word of the shorter name and no conflicting strength
  (`medicineNamesMatch`).
- **The consumption learner sums drops between consecutive readings and ignores
  rises** (`zad_recompute_consumption`, read off the live function). So a reading
  is needed after + as well as − — Kotlin sends only after − and edits, which
  loses the consumption after any unreported rise. Repeated equal readings are
  harmless (no drop, no change to the span).
- **Family money is server-only** (`20260921150000`, live since 2026-09-21).
  Balances change only inside `zad_complete_chore`, `zad_reopen_chore`,
  `zad_contribute_to_challenge`, `zad_decide_purchase_request`, which raise a
  transaction-local flag (`zad.family_ledger`) the balance guard checks. Rewards,
  targets and windows are admins'; completion columns and challenge progress are
  server-only; a purchase request is PENDING in its sender's own name and only an
  admin's RPC decides it. When porting chores/challenges/requests, call these —
  never write `balance`, `is_completed`, progress rows or a request's metadata.
- **Recipes are asked for by a tap, never on open** (`features/recipes`). Kotlin
  calls `meal_suggestions` on every pantry change; the Flutter section shows the
  cached last answer with a pantry fingerprint and says when the pantry moved
  on. The request sends the pantry sorted and without zero-quantity rows, so an
  unchanged kitchen is the same text and hits the server's per-user cache
  (6 h). `rate_recipe` is meant to clear that cache — it matched nothing until
  `b325d34f` (the key had gained `v2:`); that fix shipped with the fork's CI deploy
  (run `35658640118`, 2026-09-21). Opinions are queued per dish
  under a UUID v5 of the name (Hive keys must be ASCII).
- **Crowd prices go through the server** (`20260921160000`, live — §5
  item 9). `price_index` let anyone, signed in or not, read every report with
  its `user_id` and insert unowned rows of any source; now clients write only
  through `zad_report_price` (idempotent on the phone's report id; one voice
  per person/item/store/city per 12 h — a second report corrects the first;
  30 new an hour; the account's own currency) and read only their own rows;
  `zad_cheapest_prices` is definer and `zad_price_leaderboard` returns rank,
  count and `is_me`, never an id. On the phone a report is checked against
  the same bounds before it is queued (`checkReport`), so the queue never
  holds one the server will refuse.
- **`ServerRefusal` is permanent** (`data/sync/sync_failure.dart`). An RPC that
  answers refusals as data (`{ok:false, reason}`) should throw it for reasons
  that retrying cannot change, so the outbox dead-letters at once instead of
  burning eight attempts. Transient reasons (`too_many`) throw anything else.
  Older senders (pharmacy restock/dose) still throw `StateError` for refusals.
- **Location: one fix on a tap, a coarse point on the wire** (`features/nearby`).
  Never a stream; on open no permission prompt and no new fix — only the OS's
  last position if under 30 minutes old; a tap takes one medium-accuracy fix
  (10 s limit). Only `GeoPoint.coarse` (3 decimals, ~110 m) leaves the phone,
  to `nearby_pois` and then Overpass; distances are computed locally and the
  exact fix is never stored. The kept list is reused within 500 m and 24 h;
  radius chips never fetch.
- **SQL behaviour tests run on a scratch Postgres**, not the live project:
  `supabase/sql/tests/scratch_scaffold.sql` (header has the docker commands) +
  `pharmacy_restock_test.sql` + `family_money_test.sql` (39 checks as four
  accounts). They refuse to run on a database with a `storage` schema.
- **`zad_shopping_list` has a partial unique index** on
  `(user_id, lower(trim(item_name))) where is_purchased = false`. The client
  dedupe mirrors it; a hand-typed duplicate lands as a permanent 409 → dead
  letter.
- **`zad_inventory` is household-shared** via a trigger-set `family_id`: never
  send it, never drop other members' rows on refresh.
- **CI:** `build-debug-apk.yml` accepts `GOOGLE_SERVICES_JSON` (raw) or
  `GOOGLE_SERVICES_JSON_BASE64`, and fails at the restore step if neither is
  valid (`3724b4fd`). The Codespace token **cannot re-run Actions**; a push
  triggers a fresh run instead.

---

## 5. Open decisions (the owner's call — ask, do not assume)

1. ~~Server-side dose snooze~~ — **decided and done 2026-09-21** (see §4).
2. **Transcript-only action** on `zad-core-intelligence` (wraps the existing
   `transcribeAudio`) to stop paying for `voice_agent`'s unused intent call.
   Swap point: `chat/data/transcriber.dart`.
3. **KGP deprecation warning** from `zad_bank_listener`'s `build.gradle` —
   **deferred by the owner** while the APK builds. Do not touch unless asked.
4. **Archive screen — cancelled by the owner.** It is not defined anywhere in
   the product; do not build it.
5. ~~Family RLS~~ — **closed 2026-09-21** by
   `20260921130000_family_membership_through_the_server` (owner: fix strictly,
   no Kotlin compatibility — it has no live users). Create/join only through
   `zad_create_family` / `zad_join_family` (security definer); no client insert
   policy on `family_members` or `family_groups`; families visible to members
   only; 40-bit invite codes (all 14 rotated), 10 failed joins an hour; one
   family per account; guard triggers on role, limits, membership moves and the
   last admin; an emptied family is deleted. Run by hand via `execute_sql` and
   verified as three real accounts in a rolled-back block (16 checks). Still
   open, family-internal: balances are credited by whoever completes a chore
   or challenge (client-side reward logic) — move rewards server-side. **Done in
   the repo 2026-09-21** (`f35d4716`, owner: "انقلها فوراً لدالة آمنة على
   السيرفر") — see item 7 for its live state.
6. Where commits should end up: this Codespace can only push to the fork (see
   below). Getting work into the ship repo needs a PR or a token with write.
7. ~~Two migrations awaiting the live project~~ — **applied 2026-09-21** on the
   owner's instruction ("معاك صلاحية كاملة لتشغيل الـ migrations عبر
   execute_sql"): `20260921140000_pharmacy_restock` then
   `20260921150000_family_money_through_the_server`, through `execute_sql` in
   `begin … commit`, so no version was stamped. Verified on live in rolled-back
   blocks with real accounts picked inside the block (no ids returned): restock
   7/7 (own +30, replay adds nothing, new medicine lands with its count, name
   clash, another account's medicine, posing as another account, log scoped);
   family money 21/21 (direct balance writes refused for child and admin, reward
   rules, completion once, admin-only reopen with take-back, challenge target and
   progress locked, pays once, request in a sibling's name and self-approval
   refused, admin approval debits, `family_messages` hidden from an outsider).
   Row counts unchanged afterwards. ⚠️ **Found while checking:**
   `supabase_migrations.schema_migrations` *does* hold `20260921120000` and
   `20260921130000` — contrary to what §4 says about the snooze migration being
   unstamped. Until the ship repo (`upstream`) has those two files, its CI
   `db push` fails with "Remote migration versions not found". Getting this
   fork's commits into `upstream` (item 6) fixes it; do not `repair`.
8. **Also found, not fixed:** any family member can post a `chat_messages` row
   under any `sender_id` (Kotlin inserts `zad_ai` messages from the phone). Only
   `PURCHASE_REQUEST` is now pinned to the sender's own name, because that is the
   one that moves money.
9. ~~`20260921160000_price_reports_through_the_server`~~ — **live.** The owner
   ordered it on 2026-09-21 ("لا يهمنا كوتلن" — Kotlin's direct inserts and
   its full leaderboard can break). It turned out to be live already: the
   fork's CI (run `35658640118`) had applied it on the docs push at 21:42,
   while this item still said it was waiting. Verified on live in a
   rolled-back block with real accounts, 15/15: report in the account's
   currency, name normalised, replay is a duplicate, same store and city is
   a correction, bad input refused, direct insert and update refused, both
   aggregates see the report, a second account reads none of the first's
   rows but its aggregates count them, `is_me` only for the reporter, anon
   reads nothing and calls nothing. `price_index` still had 0 rows afterwards.

---

## 6. What is left, in order

Ordered by value and dependency, not by screen count. Each item = one slice,
one commit, full verification, report, then continue.

1. ~~Market selection~~ — done (gate after sign-in). **Still open:** the
   pre-login intro carousel (done since — `features/onboarding`), and changing the market
   *later* from settings — Kotlin's profile does that with
   `convertLimitsForMarketChange`, which converts the monthly limit to the new
   currency; porting the picker without that conversion would leave the limit
   in the old currency's figures, so it was deliberately left out.
2. **Receipt items → pantry** — grocery done: ticked lines add to matching
   pantry rows (Kotlin's `namesMatch` rules, duplicates and double matches
   summed) or become new rows, open shopping-list lines are ticked off, and
   `zad_record_observation` gets a `camera_ocr` reading *before and after*
   each top-up (Kotlin sends only after, which hides the consumption since the
   last reading). Pharmacy receipts restock the pharmacy (`b4ae5a31`) and the
   pantry's −/+ send `manual` readings (`9db280c2`). **Still open:** a price
   column for medicines (Kotlin keeps `price`; Flutter's model does not).
3. ~~Subscriptions~~ — done (data layer + screens, Home entry card under the
   balance). Not ported, deliberately: Kotlin's AI detection
   (`detectSubscriptions`, an LLM call on screen open — CLAUDE.md forbids it)
   and the debt planner / deals / challenges cards that shared its old tab.
   Widget tests need `initializeDateFormatting('ar')` in `setUpAll` wherever a
   screen prints an Arabic month.
4. **Family** — membership done (create/join through `zad_create_family` /
   `zad_join_family`, members, roles, remove, leave, new invite code; entry is
   the family icon on the البيت tab). Still to port from the 2,597-line
   `FamilyScreen.kt`: family chat, requests/approvals, chores, challenges,
   sinking funds, spend limits UI, children's spending. Rewards and request
   decisions are server functions now (`f35d4716`, §4, live) — port the
   screens onto them. Membership writes deliberately bypass the
   outbox: they are online-only and read back; the money RPCs should too (none
   of them carries an idempotency key — a replayed contribution counts twice).
5. ~~Notification center~~ — done for `app_notifications` (list, read,
   mark all read up to the newest *seen*, bell with badge on Home). Not in it:
   push/FCM tokens, and the brain's `zad_insights` — none are `surface =
   'bell'` in the live table (all `home_card`/`voice`), so they belong with the
   Home card / brain screens, including Task 28's dismiss-with-reason.
6. ~~Recipes~~ — done (`84c53a25`). Not ported, deliberately: Kotlin's
   hard-coded fallback recipes (`generateDeterministicChefRecipes`) and the
   automatic "urgent recipes" call on every pantry change (both unrequested
   model calls or fake answers). A customer-tapped "use what is about to
   expire" ask is a possible follow-up.
7. ~~Prices & deals~~ — done: crowd prices (`912c23c5`) and shops near you
   (`30019e51`). Not ported: Kotlin's "live deals" / "price shock" web-search
   actions (`fetch_live_deals`, `fetch_price_shock_warnings` — model calls; no
   screen asked for them here) and its background geofence alerts
   (`GroceryGeofenceManager`, which needs the background-location permission
   this client deliberately does not declare).
8. ~~Brain screens~~ — done (`978eecea`, `18cc32a6`, `4fa99070`, `23dc6f54`).
   Differences from Kotlin, on purpose: undo is offered only for the seven
   tables `zad_agent_undo` restores, and is asked first; forget / profile save /
   outings wipe are online and read back (never queued: "forgotten" must be
   true on the next turn); the health screen keeps no cache on disk (a stale
   all-clear is the failure it exists to prevent); the map drops Kotlin's
   invented telemetry figures. Kotlin's tool/scope/source identifiers that
   leaked to the screen (`spending_pattern`, `add_obligation`, `voice`) all
   read as Arabic now.
9. **Alerts — the owner's explicit ask ("ولا تنسى التنبيهات").** The phone has
   to actually alert, not just list: FCM push (the server already sends to
   `zad_fcm_tokens` through `zad-brain/push.ts`; the table had 0 rows on
   2026-09-21), notification permission, foreground display, a tap that opens
   the right tab (`route: transaction_proposals`), and the brain's
   `zad_insights` home cards with dismiss-with-reason (Task 28). The
   token-takeover fix is `20260921170000_fcm_token_follows_the_device`.
10. **The rest:** `AppointmentsScreen`, `MaintenanceScreen`,
   `AchievementsScreen`, `TasbihaScreen`, `StatementImportScreen`,
   `ZadSubscriptionPaywallScreen`, `TermsOfServiceScreen`, `HelpSupportScreen`,
   `ProfileScreen`/`ProfileSubScreens`, `FinancesScreen`, `BudgetScreen`.
11. **The finish line:** a release APK signed with the debug key (already the
    template's setting, `android/app/build.gradle.kts`), sideloaded on the
    owner's phone to confirm the whole conversion works. **Out of scope, by
    the owner's decision on 2026-09-21:** an official keystore, the Play
    Console, a store listing, a Flutter CI workflow. **Cancelled for good:** the
    live voice call (`zad-voice-live`). Do not put it back on this list.

---

## Where the commits live

`origin` = `amirhesham957-bit/zad-app-1` (personal fork, created automatically
because the Codespace token is read-only on `seam1010x-lab/zad-app`).
`upstream` = `seam1010x-lab/zad-app`, the ship repo, which nothing here can push to.

⚠️ **A push to `origin main` deploys to production.** The fork has Actions on
and the deploy secrets set (Edge Functions runs since 2026-09-20), so
`edge-functions.yml` runs `supabase db push --include-all` and deploys every
edge function to `auuftqncrjsnyylolhbu`. A migration the owner has not approved
must not be on `main` when you push. After a push, read the run's `Push
migrations` log (`gh run list -R amirhesham957-bit/zad-app-1`). See memory note
`codespace-git-forks-origin`.
