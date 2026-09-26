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
import 'package:zad/core/period/budget_period.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_appear.dart';
import 'package:zad/design/components/zad_balance_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/components/zad_trailing_gap.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/features/bank/presentation/bank_access_card.dart';
import 'package:zad/features/brain/presentation/agent_action_log_screen.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';
import 'package:zad/features/home/presentation/glance_cards.dart';
import 'package:zad/features/home/presentation/home_blocks.dart';
import 'package:zad/features/home/presentation/metrics_duo.dart';
import 'package:zad/features/home/presentation/sections_grid.dart';
import 'package:zad/features/insights/presentation/insight_cards.dart';
import 'package:zad/features/modes/presentation/modes_cards.dart';
import 'package:zad/features/proposals/presentation/proposals_screen.dart';
import 'package:zad/features/settings/presentation/monthly_limit_sheet.dart';
import 'package:zad/features/transactions/presentation/quick_expense_sheet.dart';

/// Home.
///
/// Laid out in Kotlin HomeScreen's order, with its gaps: 16dp on top, 20dp
/// either side, and the blocks in the sequence Kotlin draws them — the
/// companion row, the modes, the wallet card and its two metrics, the bank
/// channel, the sections grid, the pantry, the pharmacy, the subscriptions,
/// the bank's waiting proposals, what the brain noticed, and the latest
/// transactions. Each block enters the way Kotlin's `AppearOnEntry` does,
/// with Kotlin's per-block delays.
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
        // Always scrollable, so the pull gesture exists even when the content
        // is one card and does not fill the screen.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        children: <Widget>[
          const HomeOfflineBanner(),
          ZadAppearOnEntry(
            child: HomeCompanionHeader(
              onOpenVoice: onOpenVoice ?? () {},
              onOpenCamera: onOpenCamera ?? () {},
            ),
          ),
          const SizedBox(height: 16),
          const ZadTrailingGap(gap: 16, child: BrokeModeSlot()),
          const ZadTrailingGap(gap: 16, child: SavingsChallengeSlot()),
          _Budget(view: view),
          const ZadTrailingGap(gap: 18, child: BankAccessCard()),
          // Kotlin's grid sits a further 16dp in from the page padding.
          const ZadAppearOnEntry(
            delayMs: 50,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionsGrid(),
            ),
          ),
          const SizedBox(height: 16),
          const ZadAppearOnEntry(
            delayMs: 65,
            child: ZadTrailingGap(gap: 18, child: PantryGlanceCard()),
          ),
          const ZadAppearOnEntry(
            delayMs: 85,
            child: ZadTrailingGap(gap: 18, child: PharmacyGlanceCard()),
          ),
          const ZadAppearOnEntry(
            delayMs: 100,
            child: ZadTrailingGap(gap: 18, child: SubscriptionsGlanceCard()),
          ),
          const HomeProposalsSection(),
          const ZadTrailingGap(gap: 18, child: HomeInsightsSection()),
          const HomeRecentTransactions(),
          const SizedBox(height: 18),
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
            // Kotlin's tap opens "ليه الرقم اتغيّر؟" — what the brain changed
            // lately. This client's answer to that question is the action log:
            // the same changes, in words, with undo.
            onTap: () => showAgentActionLog(context),
            onSetBudget: () => showMonthlyLimitSheet(context),
            onQuickExpense: () => showQuickExpenseSheet(context),
            onEditBalance: () => showMonthlyLimitSheet(context),
          ),
        ),
        const SizedBox(height: 14),
        if (spendable != null) ...<Widget>[
          ZadAppearOnEntry(
            delayMs: 40,
            child: HomeMetricsDuo(
              spendable: spendable,
              daysLeft: math.max(0, period.daysRemainingFrom(now)),
              currency: snapshot.currency,
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
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
