/// The first screen, and the one that has to be instant.
///
/// It draws whatever is already on the device in its first frame and asks the
/// server afterwards. There is no loading state over the figures: a spinner
/// that resolves into the same number a second later is a worse experience than
/// the number with a mark on it.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show TemplateType;
import 'package:intl/intl.dart' show NumberFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_appear.dart';
import 'package:zad/core/design/components/zad_balance_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_scroll_shrink.dart';
import 'package:zad/core/design/components/zad_trailing_gap.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/app_language.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/core/period/budget_period.dart';
import 'package:zad/features/home/application/home_campaign.dart';
import 'package:zad/features/home/presentation/bank_listening_pill.dart';
import 'package:zad/features/home/presentation/birthday_celebration.dart';
import 'package:zad/features/home/presentation/campaign_banner.dart';
import 'package:zad/features/home/presentation/campaign_stories.dart';
import 'package:zad/features/home/presentation/close_day_card.dart';
import 'package:zad/features/home/presentation/coverage_note.dart';
import 'package:zad/features/home/presentation/daily_brief_card.dart';
import 'package:zad/features/home/presentation/grocery_purchase_prompt.dart';
import 'package:zad/features/home/presentation/home_activation_card.dart';
import 'package:zad/features/home/presentation/home_amazon_strip.dart';
import 'package:zad/features/home/presentation/home_blocks.dart';
import 'package:zad/features/home/presentation/home_quick_cards.dart';
import 'package:zad/features/home/presentation/home_today_card.dart';
import 'package:zad/features/home/presentation/home_world_scene.dart';
import 'package:zad/features/home/presentation/inventory_check_in_card.dart';
import 'package:zad/features/home/presentation/metrics_duo.dart';
import 'package:zad/features/home/presentation/occasion_card.dart';
import 'package:zad/features/home/presentation/quiet_banner.dart';
import 'package:zad/features/home/presentation/sections_grid.dart';
import 'package:zad/features/home/presentation/subscribe_pulse_card.dart';
import 'package:zad/features/home/presentation/tasbiha_home_widget.dart';
import 'package:zad/features/home/presentation/travel_banner.dart';
import 'package:zad/features/home/presentation/trip_card.dart';
import 'package:zad/features/home/presentation/urgent_recipe_card.dart';
import 'package:zad/features/home/presentation/who_are_you_card.dart';
import 'package:zad/features/home/presentation/zad_status_card.dart';
import 'package:zad/shared/ads/presentation/native_ad.dart';
import 'package:zad/shared/brain/data/home_signals_controller.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/budget/data/upcoming_outings.dart';
import 'package:zad/shared/budget/domain/budget_snapshot.dart';
import 'package:zad/shared/budget/domain/event_day_budget.dart';
import 'package:zad/shared/budget/domain/spend_coverage.dart';
import 'package:zad/shared/day_close/presentation/close_day_sheet.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/profile/application/call_name.dart';
import 'package:zad/shared/quota/presentation/ad_week_card.dart';
import 'package:zad/shared/quota/presentation/out_of_attempts_card.dart';
import 'package:zad/shared/quota/presentation/rewards_card.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Home, as a world: a sky that follows the account's hour with the
/// companion in it, a greeting by name with one line of the money, then white
/// cards — the live prices, the money, «عوالمك», «النهارده في بيتك», the
/// tasbih and the offers — and under them everything else Home has always
/// carried. Each block enters the way Kotlin's `AppearOnEntry` does, with
/// Kotlin's per-block delays.
class HomeScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({this.onOpenVoice, this.onOpenCamera, super.key});

  /// The companion row: talk to زاد (the shell opens the mic).
  final VoidCallback? onOpenVoice;

  /// The companion row's camera circle (the shell's camera sheet).
  final VoidCallback? onOpenCamera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(budgetControllerProvider);
    final phase = homeDayPhaseNow(ref);
    final name = ref.watch(customerCallNameProvider)?.trim() ?? '';
    final named = name.isNotEmpty;

    return ZadWorldScaffold(
      world: ZadWorld.home,
      // Keeps the offset if the shell rebuilds this subtree (the budget
      // gate, kids mode) instead of starting over at the top.
      scrollKey: const PageStorageKey<String>('home'),
      showBack: false,
      title: switch (phase) {
        HomeDayPhase.dawn =>
          named ? l10n.homeGreetDawn(name) : l10n.homeGreetDawnAnon,
        HomeDayPhase.morning =>
          named ? l10n.homeGreetMorning(name) : l10n.homeGreetMorningAnon,
        HomeDayPhase.noon =>
          named ? l10n.homeGreetNoon(name) : l10n.homeGreetNoonAnon,
        HomeDayPhase.evening =>
          named ? l10n.homeGreetEvening(name) : l10n.homeGreetEveningAnon,
        HomeDayPhase.night =>
          named ? l10n.homeGreetNight(name) : l10n.homeGreetNightAnon,
      },
      stateLine: _stateLine(context, ref, view),
      scene: (loop) => HomeWorldScene(loop, phase: phase),
      zado: ZadWorldZado(left: 30, top: 58, state: phase.pose),
      // force: the cooldown exists to stop *automatic* refetching on every
      // re-entry. A user who pulled the screen down asked for it, and being
      // told "not yet" would just make them pull again.
      onRefresh: () async {
        // «حالة البيت» too (ZAD_PLAN ٦.٤): the brief's server lines.
        unawaited(
          ref.read(homeSignalsControllerProvider.notifier).refresh(force: true),
        );
        await ref.read(budgetControllerProvider.notifier).refresh(force: true);
      },
      bottomInset: 128,
      // The money first (owner): above the title and the hero scene.
      topSlivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            ZadSpacing.lg,
            ZadSpacing.gutter,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _Budget(view: view)),
        ),
      ],
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            ZadSpacing.lg,
            ZadSpacing.gutter,
            0,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              // A quiet period the customer asked for, with the way out of it.
              const QuietModeBanner(),
              // The day's occasion first: it is there one day a year.
              const OccasionCardSlot(),
              // The customer's own birthday opens with the cake, once a year.
              const BirthdayCelebration(),
              // Kotlin's order: the travel suggestion, then the offline banner.
              const TravelBannerSlot(),
              const TripCardSlot(),
              const GroceryPurchasePromptHost(),
              const HomeOfflineBanner(),
              // «حالة زاد» (owner 20/11): every permission and whether it
              // works now, each broken one with its fix; one green line when
              // all is well.
              const ZadStatusCard(),
              // 1. Live prices at the top (owner, 2026-11-09).
              ZadAppearOnEntry(child: ZadSlots.liveMarketTickerSlot()),
              ZadAppearOnEntry(
                child: HomeCompanionHeader(
                  onOpenVoice: onOpenVoice ?? () {},
                  onOpenCamera: onOpenCamera ?? () {},
                ),
              ),
              const SizedBox(height: ZadSpacing.lg),
              // Cooking and offers, one tap away (owner, P1.5b).
              const HomeQuickCards(),
              const SizedBox(height: ZadSpacing.lg),
              // The occasion's banner (app_campaigns), when one runs; the
              // balance card already wears the occasion's colours.
              const ZadAppearOnEntry(child: CampaignBannerSlot()),
              // «حكايات زاد», the occasion's story, when it has one.
              const ZadAppearOnEntry(child: CampaignStoriesStrip()),
              const FxExcludedNotice(),
              // 3. «عوالمك»: every section, drawn in its world's colour.
              const ZadAppearOnEntry(delayMs: 25, child: _WorldsCard()),
              const SizedBox(height: ZadSpacing.lg),
              // 4. «النهارده في بيتك».
              const ZadAppearOnEntry(delayMs: 25, child: HomeTodayCard()),
              const SizedBox(height: ZadSpacing.lg),
              // 5. The tasbih is back on Home (owner, 15/11).
              const ZadAppearOnEntry(delayMs: 25, child: TasbihaHomeSlot()),
              // 6. Offers: «عروض على نواقصك» (Shein with its code and the
              // deals on what the home is short of), the shops near the
              // customer, then Amazon.
              ZadAppearOnEntry(
                delayMs: 30,
                child: ZadSlots.homeDealsCarousel(
                  // The occasion's mark beside the title (HOME_REVIEW ٢),
                  // when its colours read on white.
                  occasion: switch (ref.watch(homeCampaignProvider)?.campaign) {
                    final c? when c.readableOnWhite => c,
                    _ => null,
                  },
                ),
              ),
              ZadAppearOnEntry(delayMs: 35, child: ZadSlots.homeNearbyStores()),
              // «تسوق من أمازون»: a card per thing the home is short of.
              const ZadAppearOnEntry(delayMs: 40, child: HomeAmazonStrip()),
              // One native ad (owner, 15/11), between two reading sections —
              // never beside a task or a button (owner 11/11). It takes no
              // room until an ad loads, and none for subscribers, kids or
              // where ads are off.
              const ZadNativeAd(templateType: TemplateType.medium),
              // شيف زاد: the last recipes asked for, a tap to ask.
              ZadAppearOnEntry(delayMs: 45, child: ZadSlots.homeChefSection()),
              // Out of attempts: the ad button where it can be found, then
              // «مكافآت زاد». OutOfAttemptsCard must stay immediately before
              // RewardsCard.
              const OutOfAttemptsCard(),
              const RewardsCard(),
              // «موجز زاد النهارده»: the brain says what matters today.
              const ZadAppearOnEntry(delayMs: 50, child: DailyBriefCard()),
              const SizedBox(height: ZadSpacing.lg),
              // The bank channel's state lives in «حالة زاد» at the top (one
              // place for every permission); here only what it brought.
              ZadSlots.stuckNotificationsSlot(),
              const HomeRecentTransactions(),
              const SizedBox(height: 18),
              // What waits on the customer, after the agreed blocks.
              ZadSlots.homeProposalsSection(),
              // ZAD_PLAN ٣.٢: in the evening, close the day.
              const ZadTrailingGap(
                gap: 16,
                child: ZadAppearOnEntry(delayMs: 30, child: CloseDayCard()),
              ),
              // «اشترك» (ZAD_PLAN ٨ب.٣): free customers, once a session.
              const SubscribePulseCard(),
              // «شفت ١٥ إعلان الأسبوع ده» — once a week, free customers only.
              const AdWeekCard(),
              ZadTrailingGap(gap: 16, child: ZadSlots.brokeModeSlot()),
              ZadTrailingGap(gap: 16, child: ZadSlots.savingsChallengeSlot()),
              const HomeActivationSlot(),
              const WhoAreYouCard(),
              const InventoryCheckInSlot(),
              // The bot's link, while it is missing (owner, 2026-10-13).
              ZadAppearOnEntry(
                delayMs: 40,
                child: ZadSlots.homeTelegramBlocks(),
              ),
              const SizedBox(height: ZadSpacing.lg),
              ZadTrailingGap(
                gap: 18,
                child: ZadSlots.homeInsightsSection(onOpenCamera: onOpenCamera),
              ),
              // Kotlin: the alert banner, then «العقل → الوصفات».
              const AiAlertBannerSlot(),
              const UrgentRecipeSlot(),
            ]),
          ),
        ),
      ],
    );
  }

  /// One line of real money: what can be spent and how long it has to last.
  String _stateLine(BuildContext context, WidgetRef ref, BudgetView view) {
    final l10n = context.l10n;
    final snapshot = view.snapshot;
    final spendable = view.spendable;
    if (snapshot == null ||
        snapshot.cycleStart == null ||
        snapshot.cycleEnd == null ||
        spendable == null) {
      return l10n.homeStateIdle;
    }
    final days = math.max(
      1,
      _periodOf(snapshot).daysToLiveOn(ref.read(nowProvider)()),
    );
    return l10n.homeStateMoney(
      NumberFormat('#,##0.##', 'en').format(spendable < 0 ? 0 : spendable),
      snapshot.currency,
      l10n.metricsDays(days),
    );
  }
}

/// The part of the day it is in the **account's** market zone, never the
/// device's (a customer in Cairo travelling through Dubai still wakes to
/// Cairo's morning).
HomeDayPhase homeDayPhaseNow(WidgetRef ref) {
  final now = ref.read(nowProvider)().toUtc();
  try {
    final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    return homeDayPhaseOf(tz.TZDateTime.from(now, zone).hour);
  } on Object {
    // The SQL's own fallback zone (Africa/Cairo), as a fixed offset.
    return homeDayPhaseOf(now.add(const Duration(hours: 2)).hour);
  }
}

/// «عوالمك»: the sections, drawn per world.
class _WorldsCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ZadWorldCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.homeWorldsTitle,
          style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          context.l10n.homeWorldsHint,
          style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.md),
        const SectionsGrid(),
      ],
    ),
  );
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
          title: view.error != null
              ? context.l10n.homeServerDown
              : context.l10n.homePreparing,
          message: view.error != null
              ? context.l10n.homeServerDownHint
              : context.l10n.homePreparingHint,
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
          // The money steps back as the list moves on (ZAD_PLAN ٢.٣), by size
          // only: faded over the light canvas, a dark occasion card turned a
          // muddy grey (seen on the emulator, 2026-11-10).
          child: ZadScrollShrink(
            minOpacity: 1,
            child: ZadBalanceCard(
              spendable: spendable,
              spent: snapshot.spent,
              openingBalance: snapshot.openingBalance,
              committed: snapshot.committed,
              currency: snapshot.currency,
              period: period,
              now: now,
              // Either the server has not confirmed this session's figures, or
              // a local write is still queued and the number on screen is this
              // device's arithmetic rather than the server's.
              isStale: view.isStale || view.pendingSpend > 0,
              // The occasion's colours, when a campaign runs and they read.
              gradient: campaignCardGradient(ref.watch(homeCampaignProvider)),
              glow: campaignCardGlow(ref.watch(homeCampaignProvider)),
              // Kotlin's tap opens WhyChangedSheet — «ليه الرقم اتغيّر؟».
              onTap: () => ZadScreens.openWhyChanged(context),
              onSetBudget: () => ZadScreens.showMonthlyLimitSheet(context),
              onQuickExpense: () => ZadScreens.showQuickExpenseSheet(context),
              onEditBalance: () => ZadScreens.showMonthlyLimitSheet(context),
            ),
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
        // ZAD_PLAN ٣.٤: how much of the spending Zad is seeing.
        if (spendCoverage(
              spent: snapshot.spent,
              cap: snapshot.openingBalance,
              capConfirmed: snapshot.limitConfirmed,
              cycleLengthDays: snapshot.cycleLengthDays,
              daysLeft: snapshot.daysLeft,
            )
            case final coverage?) ...<Widget>[
          ZadAppearOnEntry(
            delayMs: 50,
            child: CoverageNote(
              coverage: coverage,
              // Closing the day is what lets Zad see more tonight; the
              // sheet also links the bank.
              onTap: () => showCloseDaySheet(context, ref),
            ),
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 14),
      ],
    );
  }

  /// The day's share once outings in the coming week are weighed in
  /// (الشريحة ٤٢). Null while the week's appointments load, or when none is
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
    return (
      budget: e,
      caption: eventDayCaption(
        e,
        weekday: day.weekday,
        l10n: ref.read(zadL10nProvider),
      ),
    );
  }
}
