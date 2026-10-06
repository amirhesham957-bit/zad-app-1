/// The first screen, and the one that has to be instant.
///
/// It draws whatever is already on the device in its first frame and asks the
/// server afterwards. There is no loading state over the figures: a spinner
/// that resolves into the same number a second later is a worse experience than
/// the number with a mark on it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_appear.dart';
import 'package:zad/core/design/components/zad_balance_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_trailing_gap.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/period/budget_period.dart';
import 'package:zad/features/home/application/home_campaign.dart';
import 'package:zad/features/home/presentation/bank_listening_pill.dart';
import 'package:zad/features/home/presentation/birthday_celebration.dart';
import 'package:zad/features/home/presentation/campaign_banner.dart';
import 'package:zad/features/home/presentation/campaign_stories.dart';
import 'package:zad/features/home/presentation/daily_brief_card.dart';
import 'package:zad/features/home/presentation/grocery_purchase_prompt.dart';
import 'package:zad/features/home/presentation/home_activation_card.dart';
import 'package:zad/features/home/presentation/home_amazon_strip.dart';
import 'package:zad/features/home/presentation/home_blocks.dart';
import 'package:zad/features/home/presentation/inventory_check_in_card.dart';
import 'package:zad/features/home/presentation/metrics_duo.dart';
import 'package:zad/features/home/presentation/occasion_card.dart';
import 'package:zad/features/home/presentation/quiet_banner.dart';
import 'package:zad/features/home/presentation/sections_grid.dart';
import 'package:zad/features/home/presentation/tasbiha_home_widget.dart';
import 'package:zad/features/home/presentation/travel_banner.dart';
import 'package:zad/features/home/presentation/urgent_recipe_card.dart';
import 'package:zad/features/home/presentation/who_are_you_card.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/budget/data/upcoming_outings.dart';
import 'package:zad/shared/budget/domain/budget_snapshot.dart';
import 'package:zad/shared/budget/domain/event_day_budget.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';

/// Home.
///
/// زاد's home: the companion row and the occasion's banner, the wallet card
/// and its two metrics, the brain's daily brief, the sections, the bank's
/// waiting proposals, the modes, the bank channel, the latest transactions,
/// and what the brain noticed. Each
/// block enters the way Kotlin's `AppearOnEntry` does, with Kotlin's
/// per-block delays.
class HomeScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({this.onOpenVoice, this.onOpenCamera, super.key});

  /// The companion row: talk to زاد (the shell opens the mic).
  final VoidCallback? onOpenVoice;

  /// The companion row's camera circle (the shell's camera sheet).
  final VoidCallback? onOpenCamera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(budgetControllerProvider);

    return RefreshIndicator(
      // force: the cooldown exists to stop *automatic* refetching on every
      // re-entry. A user who pulled the screen down asked for it, and being
      // told "not yet" would just make them pull again.
      onRefresh: () =>
          ref.read(budgetControllerProvider.notifier).refresh(force: true),
      child: ListView(
        // Keeps the offset if the shell rebuilds this subtree (the budget
        // gate, kids mode) instead of starting over at the top.
        key: const PageStorageKey<String>('home'),
        // Always scrollable, so the pull gesture exists even when the content
        // is one card and does not fill the screen.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        children: <Widget>[
          // A quiet period the customer asked for, with the way out of it.
          const QuietModeBanner(),
          // The day's occasion first: it is there one day a year.
          const OccasionCardSlot(),
          // The customer's own birthday opens with the cake, once a year.
          const BirthdayCelebration(),
          // Kotlin's order: the travel suggestion, then the offline banner.
          const TravelBannerSlot(),
          const GroceryPurchasePromptHost(),
          const HomeOfflineBanner(),
          // «حكايات زاد»: the occasion's story, when it has one.
          const CampaignStoriesStrip(),
          ZadAppearOnEntry(
            child: HomeCompanionHeader(
              onOpenVoice: onOpenVoice ?? () {},
              onOpenCamera: onOpenCamera ?? () {},
            ),
          ),
          const SizedBox(height: 16),
          // The occasion's banner (app_campaigns), under the greeting.
          const ZadAppearOnEntry(child: CampaignBannerSlot()),
          // The money right under the greeting and the occasion's banner
          // (owner, 2026-10-05): it had slid under the brief and the grid.
          _Budget(view: view),
          const FxExcludedNotice(),
          // «تسوق من أمازون» in its empty shape: «إضافة» and «اقتراح», no
          // products (owner, 2026-10-05; the product row stays off home).
          const HomeAmazonStrip(),
          // «موجز زاد النهارده»: the brain says what matters today.
          // It replaced the grid of seventeen sections and the pantry,
          // pharmacy and subscriptions cards (2026-09-30) — the pantry lives
          // in بيتي, the obligations in فلوسي, every section in the drawer.
          const ZadAppearOnEntry(child: DailyBriefCard()),
          const SizedBox(height: 16),
          // The sections back under the brief, eight at a glance and the rest
          // behind «المزيد» (owner, 2026-10-01: the squares were missed).
          const ZadAppearOnEntry(delayMs: 30, child: SectionsGrid()),
          const SizedBox(height: 16),
          ZadSlots.homeProposalsSection(),
          ZadTrailingGap(gap: 16, child: ZadSlots.brokeModeSlot()),
          ZadTrailingGap(gap: 16, child: ZadSlots.savingsChallengeSlot()),
          const HomeActivationSlot(),
          const WhoAreYouCard(),
          const InventoryCheckInSlot(),
          ZadAppearOnEntry(child: ZadSlots.liveMarketTickerSlot()),
          ZadAppearOnEntry(delayMs: 80, child: ZadSlots.homeTelegramBlocks()),
          const SizedBox(height: 16),
          const ZadAppearOnEntry(delayMs: 95, child: TasbihaHomeSlot()),
          ZadAppearOnEntry(delayMs: 105, child: ZadSlots.homeChefSection()),
          // The bank channel's state, then what it brought and what the brain
          // made of it.
          const BankListeningPill(),
          const SizedBox(height: 18),
          ZadSlots.stuckNotificationsSlot(),
          const HomeRecentTransactions(),
          const SizedBox(height: 18),
          ZadTrailingGap(
            gap: 18,
            child: ZadSlots.homeInsightsSection(onOpenCamera: onOpenCamera),
          ),
          // The Amazon product row is hidden until there is a product API
          // key: its five seeded products had stock photos and Saudi prices
          // (2026-10-01). Its empty strip sits under the budget.
          // Kotlin: the alert banner, then «العقل → الوصفات», then the gap.
          const AiAlertBannerSlot(),
          const UrgentRecipeSlot(),
          // Kotlin: room under the last card for the floating companion.
          const SizedBox(height: 112),
        ],
      ),
    );
  }
}

class _Budget extends ConsumerWidget {
  const new({required this.view});

  final BudgetView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = view.snapshot;

    // Nothing cached and nothing fetched yet — a genuinely empty first launch,
    // not a slow one. A snapshot without a cycle is treated the same way: its
    // figures were computed against a range it did not report, so there is
    // nothing honest to draw them beside.
    if (snapshot == null ||
        snapshot.cycleStart == null ||
        snapshot.cycleEnd == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: ZadEmptyState(
          icon: view.error != null ? ZadIcons.failed : ZadIcons.budget,
          title: view.error != null ? 'مقدرتش أوصل للسيرفر' : 'بنجهّز ميزانيتك',
          message: view.error != null
              ? 'هنحاول تاني لوحدنا. تقدر تسحب الشاشة لتحت دلوقتي.'
              : 'ثانية واحدة وهتلاقي كل حاجة هنا.',
          tone: view.error != null
              ? ZadEmptyTone.problem
              : ZadEmptyTone.waiting,
        ),
      );
    }

    final period = _periodOf(snapshot);
    final now = ref.read(nowProvider)();
    final spendable = view.spendable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ZadAppearOnEntry(
          child: ZadBalanceCard(
            spendable: spendable,
            spent: snapshot.spent,
            openingBalance: snapshot.openingBalance,
            committed: snapshot.committed,
            currency: snapshot.currency,
            period: period,
            now: now,
            // Either the server has not confirmed this session's figures, or a
            // local write is still queued and the number on screen is this
            // device's arithmetic rather than the server's.
            isStale: view.isStale || view.pendingSpend > 0,
            // The occasion's colours, when a campaign runs and they read.
            gradient: campaignGradient(ref.watch(homeCampaignProvider)),
            // Kotlin's tap opens WhyChangedSheet — «ليه الرقم اتغيّر؟».
            onTap: () => ZadScreens.openWhyChanged(context),
            onSetBudget: () => ZadScreens.showMonthlyLimitSheet(context),
            onQuickExpense: () => ZadScreens.showQuickExpenseSheet(context),
            onEditBalance: () => ZadScreens.showMonthlyLimitSheet(context),
          ),
        ),
        const SizedBox(height: 14),
        if (spendable != null) ...<Widget>[
          ZadAppearOnEntry(
            delayMs: 40,
            child: HomeMetricsDuo(
              spendable: spendable,
              daysLeft: math.max(1, period.daysToLiveOn(now)),
              event: _eventDay(ref, spendable, period.daysToLiveOn(now), now),
              currency: snapshot.currency,
              payday: period.isCalendarMonth ? null : period.periodEnd,
            ),
          ),
          const SizedBox(height: 14),
        ],
        ZadAppearOnEntry(
          delayMs: 60,
          child: ZadSlots.homeReportsRow(
            spent: snapshot.spent,
            spendable: spendable,
            daysLeft: math.max(1, period.daysToLiveOn(now)),
            currency: snapshot.currency,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  /// The day's share once outings in the coming week are weighed in
  /// (الشريحة ٤٠). Null while the week's appointments load, or when none is
  /// an outing — the plain division then stands.
  ({EventDayBudget budget, String caption})? _eventDay(
    WidgetRef ref,
    double spendable,
    int daysLeft,
    DateTime now,
  ) {
    final outings = ref.watch(upcomingOutingsProvider).value;
    if (outings == null || outings.isEmpty) return null;
    final tz.Location zone;
    try {
      zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    } on Object {
      return null;
    }
    DateTime local(DateTime utc) => tz.TZDateTime.from(utc.toUtc(), zone);
    final e = eventDayBudget(
      spendable: spendable,
      daysLeft: daysLeft,
      appointments: outings,
      now: now,
      toLocal: local,
    );
    if (e == null) return null;
    final day = local(now).add(Duration(days: e.eventInDays));
    return (budget: e, caption: eventDayCaption(e, weekday: day.weekday));
  }

  /// The card's period, taken from the snapshot the money came from.
  ///
  /// Deliberately not recomputed: the server's `days_left` is what its
  /// `daily_allowance_left` was divided by, and a card showing a different
  /// number of days beside those figures would be quietly inconsistent.
  BudgetPeriod _periodOf(BudgetSnapshot snapshot) => BudgetPeriod.fromServer(
    cycleStart: snapshot.cycleStart!,
    cycleEnd: snapshot.cycleEnd!,
    timeZone: snapshot.timeZone,
  );
}
