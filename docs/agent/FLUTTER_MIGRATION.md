# Flutter migration — status, conventions, and what is left

**Last updated 2026-09-21. HEAD `427dca37` on `origin/main`** (the personal fork
`amirhesham957-bit/zad-app-1` — see "Where the commits live" below).

**The decision:** the owner decided to finish the Flutter client first, whatever
it takes, and to keep going until the whole app is converted. Until then the
Kotlin app (`app/`) is still the one that ships and the one CI builds. Both
clients share one Supabase project — same tables, same RLS, same edge
functions — so the migration is a client rewrite, not a system one, and it can
land screen by screen.

Size at `427dca37` (measured, not estimated): Flutter `lib/` is 16,309 lines
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
   flutter test                       # 439 passing at 427dca37
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
| Pharmacy — schedule, doses, local snooze | `features/pharmacy` | `13d1d01c`, screens `427dca37` |
| Household tab (pantry / shopping / pharmacy) | `features/household` | `427dca37` |

Shell tabs: الرئيسية · المعاملات · زاد (chat) · البيت · تأكيدات.

Android: `INTERNET` is declared in the **main** manifest (the template only put
it in debug/profile, so every release build had no network — `51608a88`);
launcher label is `@string/app_name` = زاد. Declared permissions in the release
APK: INTERNET, ACCESS_NETWORK_STATE, RECORD_AUDIO. No SMS, no CAMERA (the
scanner uses the system camera intent via `image_picker`).

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
- **Mutation checks found two real test gaps:** (1) reading the date in UTC
  instead of the market zone passed every test because they all ran at noon UTC
  — boundary tests at 22:00Z/02:00Z now pin it; (2) slots were `TZDateTime`,
  and `TZDateTime == DateTime` is false while the reverse is true — slots are
  now plain UTC `DateTime`s.
- **Doses are recorded only through `zad_log_pharmacy_dose_atomic`** (decrements
  stock, carries fractions, adds to shopping list — one transaction). Idempotent
  on `(user_id, item_id, scheduled_at)`; `duplicate` = success.
- **`zad_dose_snoozes` has no insert policy** for authenticated users (only the
  Telegram bot writes it, service role). App snooze is device-only.
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

1. **Server-side dose snooze** — a migration adding an owner-insert policy on
   `zad_dose_snoozes`, so the app's snooze also silences the server nudge.
2. **Transcript-only action** on `zad-core-intelligence` (wraps the existing
   `transcribeAudio`) to stop paying for `voice_agent`'s unused intent call.
   Swap point: `chat/data/transcriber.dart`.
3. **KGP deprecation warning** from `zad_bank_listener`'s `build.gradle` —
   **deferred by the owner** while the APK builds. Do not touch unless asked.
4. **Archive screen — cancelled by the owner.** It is not defined anywhere in
   the product; do not build it.
5. Where commits should end up: this Codespace can only push to the fork (see
   below). Getting work into the ship repo needs a PR or a token with write.

---

## 6. What is left, in order

Ordered by value and dependency, not by screen count. Each item = one slice,
one commit, full verification, report, then continue.

1. **Onboarding + market selection** (`OnboardingScreen`,
   `MarketSelectionScreen`). Sets `zad_users.country`/`currency`. High priority:
   with `country` null the account zone falls back to UTC, which shifts doses
   and the budget period. (CLAUDE.md records 4 of 6 prod accounts with
   `country = null`.) Must write through the settings outbox with read-back.
2. **Receipt items → pantry.** The scanner shows line items as "review only";
   `InventoryRepository` now exists, so wire grocery receipts into the pantry
   (Kotlin's `injectScannedItems`), and route `receiptType: pharmacy` to the
   pharmacy.
3. **Subscriptions** (`SubscriptionsScreen`) — feeds `committed` in the budget.
4. **Family** (`FamilyScreen`, `BrainFamilyScreen`) — shared pantry, children,
   spend limits; RLS via `get_my_family_ids()`.
5. **Notification center** (`NotificationCenterScreen`) and push/FCM tokens.
6. **Recipes** (`RecipeDetailScreen`, `RecommendationsScreen`) — pantry-driven.
7. **Prices & deals** (`NearbyDealsScreen`, `PriceReportingScreen`).
8. **Brain screens** (`ZadMemoryScreen`, `ZadKnowledgeMapScreen`,
   `AgentActionLogScreen`, `BrainHealthScreen`).
9. **The rest:** `AppointmentsScreen`, `MaintenanceScreen`,
   `AchievementsScreen`, `TasbihaScreen`, `StatementImportScreen`,
   `ZadSubscriptionPaywallScreen`, `TermsOfServiceScreen`, `HelpSupportScreen`,
   `ProfileScreen`/`ProfileSubScreens`, `FinancesScreen`, `BudgetScreen`.
10. **Live voice call** (`zad-voice-live`) — large; do last.
11. **Shipping:** a Flutter CI workflow, real release signing, Play listing.

---

## Where the commits live

`origin` = `amirhesham957-bit/zad-app-1` (personal fork, created automatically
because the Codespace token is read-only on `seam1010x-lab/zad-app`).
`upstream` = `seam1010x-lab/zad-app`, the ship repo. `git push origin main`
works; nothing here can push to `upstream`. See memory note
`codespace-git-forks-origin`.
