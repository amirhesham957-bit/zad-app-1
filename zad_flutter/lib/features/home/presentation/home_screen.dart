/// The first screen, and the one that has to be instant.
///
/// It draws whatever is already on the device in its first frame and asks the
/// server afterwards. There is no loading state over the figures: a spinner
/// that resolves into the same number a second later is a worse experience than
/// the number with a mark on it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/period/budget_period.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_balance_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/features/bank/presentation/bank_access_card.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';
import 'package:zad/features/notifications/presentation/notification_center_screen.dart';
import 'package:zad/features/settings/presentation/monthly_limit_sheet.dart';
import 'package:zad/features/settings/presentation/settings_screen.dart';
import 'package:zad/features/subscriptions/presentation/subscriptions_screen.dart';

/// Home.
class HomeScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(budgetControllerProvider);

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: RefreshIndicator(
        // force: the cooldown exists to stop *automatic* refetching on every
        // re-entry. A user who pulled the screen down asked for it, and being
        // told "not yet" would just make them pull again.
        onRefresh: () =>
            ref.read(budgetControllerProvider.notifier).refresh(force: true),
        child: CustomScrollView(
          // Always scrollable, so the pull gesture exists even when the content
          // is one card and does not fill the screen.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverAppBar(
              title: const Text('زاد'),
              floating: true,
              backgroundColor: Colors.transparent,
              // Settings rather than sign-out. The way out is in there, with
              // the warning about unsent writes beside it — an icon in the app
              // bar put the most destructive action on this screen one tap
              // from the balance.
              actions: <Widget>[
                const NotificationBell(),
                IconButton(
                  onPressed: () => showSettingsScreen(context),
                  icon: const Icon(ZadIcons.settings),
                  tooltip: 'الإعدادات',
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(ZadSpacing.gutter),
              sliver: SliverList.list(
                children: <Widget>[
                  _Budget(view: view),
                  // Right under the money, because it is what the money's
                  // "committed" part is made of.
                  const SizedBox(height: ZadSpacing.md),
                  const SubscriptionsEntryCard(),
                  // Below the money, not above it. The channel's health is
                  // worth saying when it is broken, but the balance is what
                  // the screen is for — and the card renders nothing at all
                  // when the channel is working.
                  const SizedBox(height: ZadSpacing.lg),
                  const BankAccessCard(),
                ],
              ),
            ),
          ],
        ),
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
      return ZadEmptyState(
        icon: view.error != null ? ZadIcons.failed : ZadIcons.budget,
        title: view.error != null ? 'مقدرتش أوصل للسيرفر' : 'بنجهّز ميزانيتك',
        message: view.error != null
            ? 'هنحاول تاني لوحدنا. تقدر تسحب الشاشة لتحت دلوقتي.'
            : 'ثانية واحدة وهتلاقي كل حاجة هنا.',
        tone: view.error != null ? ZadEmptyTone.problem : ZadEmptyTone.waiting,
      );
    }

    return ZadBalanceCard(
      spendable: view.spendable,
      spent: snapshot.spent,
      openingBalance: snapshot.openingBalance,
      committed: snapshot.committed,
      currency: snapshot.currency,
      period: _periodOf(snapshot),
      now: ref.read(nowProvider)(),
      // Either the server has not confirmed this session's figures, or a local
      // write is still queued and the number on screen is this device's
      // arithmetic rather than the server's.
      isStale: view.isStale || view.pendingSpend > 0,
      // The card has always offered this and it has always been null, so
      // tapping "لسه محددتش ميزانيتك" did nothing — `ZadPressable` disables
      // the press outright when its callback is null, so there was not even
      // a scale to say the tap had registered.
      onSetBudget: () => showMonthlyLimitSheet(context),
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
