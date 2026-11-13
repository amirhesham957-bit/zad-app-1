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
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_appear.dart';
import 'package:zad/core/design/components/zad_balance_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_scroll_shrink.dart';
import 'package:zad/core/design/components/zad_trailing_gap.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
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
import 'package:zad/features/home/presentation/home_glance_widgets.dart';
import 'package:zad/features/home/presentation/inventory_check_in_card.dart';
import 'package:zad/features/home/presentation/metrics_duo.dart';
import 'package:zad/features/home/presentation/occasion_card.dart';
import 'package:zad/features/home/presentation/permission_banners.dart';
import 'package:zad/features/home/presentation/quiet_banner.dart';
import 'package:zad/features/home/presentation/sections_grid.dart';
import 'package:zad/features/home/presentation/subscribe_pulse_card.dart';
import 'package:zad/features/home/presentation/travel_banner.dart';
import 'package:zad/features/home/presentation/urgent_recipe_card.dart';
import 'package:zad/features/home/presentation/who_are_you_card.dart';
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
import 'package:zad/shared/quota/presentation/ad_week_card.dart';
import 'package:zad/shared/quota/presentation/out_of_attempts_card.dart';
import 'package:zad/shared/quota/presentation/rewards_card.dart';

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
      onRefresh: () async {
        // «حالة البيت» too (ZAD_PLAN ٦.٤): the brief's server lines.
        unawaited(
          ref.read(homeSignalsControllerProvider.notifier).refresh(force: true),
        );
        await ref.read(budgetControllerProvider.notifier).refresh(force: true);
      },
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
          // «قراءة رسائل البنك متوقفة» / «موقعك غير مفعّل» (owner 7/11): at
          // the top, each one tap from the screen that fixes it.
          const PermissionBanners(),
          // Live prices at the top (owner, 2026-11-09).
          ZadAppearOnEntry(child: ZadSlots.liveMarketTickerSlot()),
          ZadAppearOnEntry(
            child: HomeCompanionHeader(
              onOpenVoice: onOpenVoice ?? () {},
              onOpenCamera: onOpenCamera ?? () {},
            ),
          ),
          const SizedBox(height: 16),
          // ZAD_PLAN ١٠.٨ (owner 11/11): one clear thing per level, in this
          // order — the money, the four glance tiles, then four sideways bars
          // (deals, the shops near you, Amazon, the chef), the brief and the
          // latest transactions. Everything else follows them.
          // The money right under the greeting (owner, 2026-10-05; emulator,
          // 2026-11-10: six blocks above it pushed it off the first screen).
          _Budget(view: view),
          // The occasion's banner (app_campaigns), when one runs; the balance
          // card already wears the occasion's colours.
          const ZadAppearOnEntry(child: CampaignBannerSlot()),
          // «حكايات زاد», the occasion's story, when it has one. The tour
          // that shared its line moved to the profile.
          const ZadAppearOnEntry(child: CampaignStoriesStrip()),
          const FxExcludedNotice(),
          // The pantry, the shortages, the pharmacy and the subscriptions at
          // a look (owner, 2026-11-09), each opening its own page.
          const ZadAppearOnEntry(delayMs: 25, child: HomeGlanceWidgets()),
          // Every other section behind one line — the grid's first two rows
          // were the four tiles above a second time.
          const ZadAppearOnEntry(
            delayMs: 25,
            child: SectionsGrid(compact: true),
          ),
          const SizedBox(height: ZadSpacing.sm),
          // «عروض على نواقصك» (owner 4/11, a sideways bar with pictures since
          // 11/11): real deals on what the home is short of.
          ZadAppearOnEntry(
            delayMs: 30,
            child: ZadSlots.homeDealsCarousel(
              // The occasion's mark beside the title (HOME_REVIEW ٢), when
              // its colours read on white.
              occasion: switch (ref.watch(homeCampaignProvider)?.campaign) {
                final c? when c.readableOnWhite => c,
                _ => null,
              },
            ),
          ),
          // The supermarkets and pharmacies near the customer, from the list
          // «أماكني» kept — it was buried there.
          ZadAppearOnEntry(delayMs: 35, child: ZadSlots.homeNearbyStores()),
          // «تسوق من أمازون»: a card per thing the home is short of.
          const ZadAppearOnEntry(delayMs: 40, child: HomeAmazonStrip()),
          // شيف زاد: the last recipes asked for, a tap to ask.
          ZadAppearOnEntry(delayMs: 45, child: ZadSlots.homeChefSection()),
          // «موجز زاد النهارده»: the brain says what matters today.
          const ZadAppearOnEntry(delayMs: 50, child: DailyBriefCard()),
          const SizedBox(height: 16),
          // The bank channel's state, then what it brought.
          const BankListeningPill(),
          const SizedBox(height: 18),
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
          // Attempts ran out: the ad button where it can be found (owner 6/11).
          const OutOfAttemptsCard(),
          // «مكافآت زاد» (owner 13/11): the ad, the plans and the bot always
          // have a way in, not only when attempts run low or the bot is
          // unlinked. Hides itself while the card above shows.
          const RewardsCard(),
          // «اشترك» (ZAD_PLAN ٨ب.٣): free customers, once a session.
          const SubscribePulseCard(),
          // «شفت ١٥ إعلان الأسبوع ده» — once a week, free customers only.
          const AdWeekCard(),
          ZadTrailingGap(gap: 16, child: ZadSlots.brokeModeSlot()),
          ZadTrailingGap(gap: 16, child: ZadSlots.savingsChallengeSlot()),
          const HomeActivationSlot(),
          const WhoAreYouCard(),
          const InventoryCheckInSlot(),
          // The bot's link, while it is missing (owner, 2026-10-13: the
          // reminders come from Telegram). Lower than before, not gone — it
          // also raises the first-visit link sheet.
          ZadAppearOnEntry(delayMs: 40, child: ZadSlots.homeTelegramBlocks()),
          const SizedBox(height: 16),
          ZadTrailingGap(
            gap: 18,
            child: ZadSlots.homeInsightsSection(onOpenCamera: onOpenCamera),
          ),
          // The tasbih lives in the drawer's «المزيد» (ZAD_PLAN ١٠.٨).
          // Kotlin: the alert banner, then «العقل → الوصفات», then the gap.
          const AiAlertBannerSlot(),
          const UrgentRecipeSlot(),
          // Kotlin: room under the last card for the floating companion.
          const SizedBox(height: 128),
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
