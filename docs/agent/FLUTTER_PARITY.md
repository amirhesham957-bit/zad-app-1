---
title: Flutter Parity — Kotlin vs Flutter
date: 2026-09-25
tags:
  - agent
  - flutter
  - migration
  - parity
aliases:
  - مقارنة كوتلن وفلاتر
  - FLUTTER_PARITY
---

# Flutter Parity — Kotlin vs Flutter

This checklist covers every screen, card, sheet and button in the Kotlin app
(`app/src/main/java/com/example/`) and where its Flutter counterpart stands. The
owner asked for it on 2026-09-25: "مش عاوزين ننسى ولا زر ولا ميزة".
[[FLUTTER_MIGRATION]] covers the conventions and history; this note is the
**what-is-missing** list. Update the mark in the same commit that lands a row.

> [!info] Legend
> ✅ ported · ⚠️ partial (what is missing is written beside it) · ❌ missing ·
> 🚫 deliberately not ported, with the reason and who decided · 💀 dead in Kotlin
> (defined but never called, so nothing to port)

> [!warning] Rules that override "1:1"
> - No model call on screen open. A Kotlin card that fires an LLM call on entry
>   is ported as **tap to ask**, never auto-fired (see [[CLAUDE]]).
> - Owner cancellations stand: the live voice call (`zad-voice-live`), the
>   archive screen, the keystore and Play work.
> - `ACCESS_BACKGROUND_LOCATION` is not declared, so features that need it
>   (geofence alerts) are 🚫 until the owner decides otherwise.
> - Styling follows [[FLUTTER_UI_TOOLKIT]]: Kotlin's colours, radii and layout,
>   built from `zad_flutter/lib/design/`.

## Shell and navigation

| Kotlin | Flutter | Notes |
|---|---|---|
| Bottom bar: home, assistant, inventory, camera, voice, more (`ZadShell`) | ⚠️ | Flutter tabs are الرئيسية · المعاملات · زاد · البيت · تأكيدات. No camera or voice sheet in the bar, and no "more" sheet. |
| `ZadMoreSheet`: grid of every section | ❌ | The same list as `ZadSectionsGrid`. |
| `ZadCameraSheet`: receipt / inventory / pharmacy scan choice | ⚠️ | The receipt scanner exists; the chooser sheet and the inventory/pharmacy camera modes are missing. |
| `ZadVoiceBottomSheet`: talk to Zad from anywhere | ⚠️ | Voice input exists inside the chat only. |
| Drawer (`zadDrawerEntries`, 13 entries) | ❌ | Covered once the sections grid and more sheet exist. |
| Deep-link routes (`inventory`, `shopping`, `pharmacy`, `budget`, `family`, `maintenance`, `subscriptions`, `tasks`, `tasbiha`, `notifications`, `profile`, `statement`, `appointments`, `camera`) | ⚠️ | `shell_navigation.dart` has tabs plus `proposals`. |
| Kids mode route lock (child role: home + family only) | ❌ | Needs Family → kids. |
| `DraggableFloatingCompanion` / `CompanionOrb` / `OrbAccessoryPicker` | ❌ | Floating orb for Zad. |
| `ZadAgentOverlay` | ❌ | |

## Home (`HomeScreen.kt`, 2,684 lines)

| Kotlin card | Flutter | Notes |
|---|---|---|
| `TravelBanner` | ❌ | |
| `OfflineBanner` | ❌ | Flutter shows a stale dot on the balance only. |
| Greeting row + camera shortcut | ❌ | |
| `BrokeModeBanner` / `BrokeModeDialog` (broke mode) | ❌ | |
| `SavingsChallengeCard` + share | ❌ | |
| `HomeActivationCard` (balance, bank reading, first item, first goal) + `LifeGoalPickerSheet` | ❌ | |
| `WhoAreYouCard` | ❌ | The profile edit exists in brain screens. |
| `LocationAlertsCard` | 🚫 | Needs geofence plus background location; see above. |
| `InventoryCheckInCard` (decrement / finished / still have) | ❌ | |
| `LiveMarketTicker` + "ساهم بسعر" | ❌ | Kotlin fetches on open (cooldown); Flutter has crowd prices. |
| `ZadWalletHeroCard`: available, ≈ when unsure, spent/committed chips, خصم سريع, تعديل الميزانية, edit icon, tap for "why changed", long press for quick expense | ✅ | `ZadBalanceCard`, which keeps its pace bar on top. The tap opens the action log (see `WhyChangedSheet`). |
| `ZadMinimalMetricsDuo`: safe daily spend, days left | ✅ | `metrics_duo.dart`. Kotlin printed the number twice ("12 12 يوم"); Flutter prints it once. |
| FX-excluded notice ("استُبعدت N معاملة") | ❌ | |
| `BankListeningPill` | ✅ | `BankAccessCard`. |
| `ZadSectionsGrid` (15 sections, badges, show all/less) | ⚠️ | `sections_grid.dart`, with badges and show all/less. 11 sections so far, including شيف زاد and الأسعار, which Flutter already has. Appointments, budget, tasbiha, maintenance, statement import and premium plans join when their screens land. |
| `TelegramLinkBanner` / `ZadTelegramCommunityCard` / `TelegramBotSheet` / `TelegramLinkPromptSheet` | ❌ | |
| `ZadFoodShortagesGlanceCard`: health, shortages, confirm, add to list | ✅ | `glance_cards.dart`. "Low" uses the pantry's shortage rule, not Kotlin's `qty ≤ 2`. The tile shows the quantity, or the days to expiry when known; Kotlin labelled the quantity as days. Kotlin's `onConfirm` was never wired to a button. |
| `ZadPharmacyGlanceCard`: adherence %, next dose, take dose | ✅ | Adherence comes from the schedule over 7 days (`weeklyAdherence`). "خدت الجرعة" shows only when the dose can be recorded, the pharmacy screen's rule. |
| `WeekWithZadCard` + share image | ❌ | |
| `TasbihaHomeWidget` | ❌ | Needs Tasbiha. |
| `ZadSubscriptionsGlanceCard` | ✅ | Replaces `SubscriptionsEntryCard`. Accents go by rank; Kotlin hard-coded colours for "نتفليكس" and "الجيم". |
| `SmartChefSection` / `UrgentRecipeCard` / `ZadChefCard` | ⚠️ | Recipes live in البيت; no Home section. Kotlin's automatic urgent-recipes call is 🚫 (a model call on data change). |
| Bank proposals on Home (`TransactionProposalCard`) | ⚠️ | A tab of their own in Flutter. |
| Insights (`zad_insights` home cards, dismiss reason, question card, currency-settings button) | ✅ | `4cc97cdb`. The currency-settings shortcut is missing. |
| `PremiumTransactionsRow` + full-list dialog | ❌ | The transactions tab exists. |
| Amazon rail (`ZadAmazonDealCard`, `ZadAmazonSearchChip`) | ❌ | Affiliate. |
| `AiAlertBanner` | ❌ | |
| `ZadQuickExpenseSheet` | ✅ | `quick_expense_sheet.dart`. Card wallet as in Kotlin. No auto-classify call when the category is empty (Kotlin fires one). |
| `BudgetEditSheet`: set the balance, recent transactions, edit category, delete | ✅ | `monthly_limit_sheet.dart`: the balance (prefilled with the current one), the preview, and the period's expenses, each with edit and delete. |
| `QuickDeductDialog`, `AddTransactionDialog` | ⚠️ | Covered by the add-transaction sheet? Check. |
| `WhyChangedSheet` | ✅ | The card tap opens the action log (`agent_actions` in words, with undo) instead of raw `zad_brain_runs.mutations`. |
| `GroceryPurchasePromptDialog` | ❌ | |
| `RecipeDetailDialog` | ✅ | Recipes sheet. |
| `AgentSummaryCard`, `AutoSuggestionsCard`, `PredictionCard`, `OutingSuggestionCard`, `EventsRadarCard` | ❌ | Model calls. Port as tap to ask. |
| `NotificationPermissionCard` | ✅ | Alerts permission (`bc044a77`). |
| `KidsModeContent` (child home: allowance, tasks, family chat, tasbiha, shopping suggestions, purchase request) | ❌ | |
| `ZadBezierSpendChart` / `ZadWeeklySpendChartCard` | 💀 | Kotlin never calls `ZadWeeklySpendChartCard`. |

## Other screens

| Kotlin screen | Flutter | Missing |
|---|---|---|
| `LoginScreen`, `SignUpScreen` | ✅ | |
| `OnboardingScreen` | ✅ | |
| `MarketSelectionScreen` | ✅ | Changing the market later from profile (limit conversion). |
| `BudgetGateScreen` (first-run budget + market) | ⚠️ | Check against the monthly-limit sheet. |
| `BudgetScreen` / `FinancesScreen`: category budgets, category insight, edit, transactions by date, transaction edit, obligations (add/edit), debts | ⚠️ | `finances_screen.dart` ("الميزانية" in the grid): available with ≈, obligations (`zad_obligations`: add/edit/delete, queued and read back, status and bar), income/spent/budget, insight strip → chat, category budgets on the device with edit and the tapped `behavior_analysis`, subscriptions card, month totals, add FAB, and a link to the transactions tab (a tab of its own here). Missing: broke mode, the savings challenge, the budget suggestion (needs two past months of rows), and the debts tab. |
| Transactions (list + manual entry) | ✅ | Edit (`TransactionEditDialog`: title, amount, kind, category) and delete, queued and read back. The four filters (الكل/المصروفات/الدخل/البنك). A tap shows the row's edit and delete, as in `TxRowItem`. Kotlin's merchant→category memory on edit is not ported. |
| `InventoryScreen`: categories, low-stock banner, expiring soon, edit, shortages, search, empty states | ⚠️ | Pantry exists; check each part. |
| `ShoppingListScreen`: budget header, priority chips, grocery suggestions, affiliate footer | ⚠️ | List exists. |
| `PantryShoppingScreen` (tabs) | ✅ | Household tab. |
| `PharmacyScreen`: expiry tracker, grid, smart add, dose picker, refill, stats, family pharmacy | ⚠️ | Schedule, doses and snooze exist. |
| `CameraScreen` (receipt / inventory / pharmacy modes, manual inventory) | ⚠️ | Receipt only. |
| `SubscriptionsScreen`: list, add/edit | ✅ | The debt planner, live deals, challenges and sinking-funds cards are 🚫/❌ (see [[FLUTTER_MIGRATION]] §6.3). |
| `FamilyScreen`: groceries, kids spending, members, spend limits, tasks/chores, goals, chat (SOS, purchase, poll), invite/join | ⚠️ | Membership only. |
| `BrainFamilyScreen` | ❌ | |
| `ZadIntelligenceScreen` (40 cards: donut, velocity, trends, monthly bars, what-if, stress test, inflation, nudges, health score, depletion, report export…) | ❌ | Analytics. |
| `ZadMemoryScreen`, `AgentActionLogScreen`, `BrainHealthScreen`, `ZadKnowledgeMapScreen` | ✅ | |
| `NotificationCenterScreen` | ✅ | |
| `NearbyDealsScreen` | ✅ | Nearby view. |
| `PriceReportingScreen` | ✅ | Prices screen. |
| `RecipeDetailScreen` | ✅ | |
| `RecommendationsScreen` | ❌ | |
| `TasbihaScreen`: garden, family garden, challenges, create/rename tree | ❌ | |
| `AppointmentsScreen`: appointments, place reminders, obligations link | ❌ | Place reminders need geofence (🚫). |
| `MaintenanceScreen` | ❌ | |
| `AchievementsScreen` | ❌ | |
| `StatementImportScreen` (CSV mapping, preview) | ❌ | |
| `ProfileScreen`: regional settings, life goal, edit name | ⚠️ | Settings exists. |
| `ProfileSubScreens`: edit profile, family management, payment & budget, assistant alerts, bank reading status | ⚠️ | |
| `ZadSubscriptionPaywallScreen` | ❌ | Play billing. Owner said no Play work; ask before porting. |
| `HelpSupportScreen`, `TermsOfServiceScreen` | ❌ | |
| Ads (`AdGateManager`, rewarded brain ad, `AdEnergyBatteryCard`) | ❌ | Ask the owner. |

## Order of work

1. Home: hero card parity, metrics duo, quick expense, balance edit.
2. Home: glance cards (food, pharmacy, subscriptions), recent transactions.
3. Sections grid and more sheet, so every section is reachable.
4. Budget/finances screen.
5. Inventory, shopping and pharmacy gaps; camera modes.
6. Tasbiha, appointments, maintenance, achievements.
7. Family (chat, chores, goals, kids), then kids mode.
8. Intelligence screen (tap-to-ask cards).
9. Profile, help, terms, statement import, the rest of Home's cards.

## Related

- [[FLUTTER_MIGRATION]]
- [[FLUTTER_UI_TOOLKIT]]
- [[SKILLS_INDEX]]
