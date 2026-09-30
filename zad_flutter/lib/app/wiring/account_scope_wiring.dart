/// Everything on the phone that belongs to one account, for [AccountScope].
///
/// When a feature starts holding account data in memory, its provider goes
/// in [forgetPreviousAccount]; the session itself never changes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/alerts/data/push_registrar.dart';
import 'package:zad/features/brain/application/agent_actions_controller.dart';
import 'package:zad/features/brain/application/brain_health_controller.dart';
import 'package:zad/features/brain/application/knowledge_map_controller.dart';
import 'package:zad/features/obligations/application/obligations_controller.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/auth/application/auth_controller.dart';
import 'package:zad/shared/brain/application/memory_controller.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/budget/application/category_budgets_controller.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/insights/application/insights_controller.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/modes/application/modes_controller.dart';
import 'package:zad/shared/notifications/application/notifications_controller.dart';
import 'package:zad/shared/proposals/application/proposals_controller.dart';
import 'package:zad/shared/session/account_scope.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/tasbiha/application/tasbiha_controller.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';

/// Binds [AccountScope].
void wireAccountScope() => AccountScope.bind(
  forgetPreviousAccount: forgetPreviousAccount,
  beforeSignOut: _beforeSignOut,
  afterSignOut: _afterSignOut,
);

/// Drops every screen's in-memory copy of the last account's data.
///
/// Clearing the boxes is not enough on its own: the controllers already read
/// those boxes into state, and a `Notifier` that is not invalidated keeps
/// holding what it read. Invalidating marks them stale without building
/// them, so the screens that are actually on display refetch and the ones
/// that are not cost nothing.
void forgetPreviousAccount(Ref ref) {
  ref
    ..invalidate(kidsModeProvider)
    ..invalidate(tasbihaControllerProvider)
    ..invalidate(transactionsControllerProvider)
    ..invalidate(budgetControllerProvider)
    ..invalidate(proposalsControllerProvider)
    // The zone is a plain provider computed from the last account's
    // country; left alone, the next account's doses and pantry dates would
    // be placed on the previous account's clock until the app restarted.
    ..invalidate(accountTimeZoneProvider)
    // And the settings screen's copy, which otherwise shows the previous
    // account's ceiling for as long as its ten-minute cooldown lasts.
    ..invalidate(settingsControllerProvider)
    ..invalidate(subscriptionsControllerProvider)
    ..invalidate(notificationsControllerProvider)
    ..invalidate(familyControllerProvider)
    // The four brain screens hold the last account's notes, profile,
    // actions and map in memory; the cleared box alone would leave them
    // on screen until each one's refresh landed.
    ..invalidate(agentActionsControllerProvider)
    ..invalidate(memoryControllerProvider)
    ..invalidate(brainHealthControllerProvider)
    ..invalidate(knowledgeMapControllerProvider)
    ..invalidate(insightsControllerProvider)
    ..invalidate(obligationsControllerProvider)
    ..invalidate(modesControllerProvider)
    ..invalidate(categoryBudgetsProvider)
    // The form too. Without this a failed sign-in leaves "الإيميل أو كلمة
    // السر مش مظبوطة" sitting under the button, and the next person to sign
    // out on this device is greeted by it before they have typed anything.
    ..invalidate(authControllerProvider);
}

Future<void> _beforeSignOut(Ref ref) async {
  // While the session can still delete its own row: this phone stops
  // receiving the account's alerts. Never throws, never blocks long.
  await ref.read(pushRegistrarProvider).unregister();
  // Kotlin's PharmacyReminderScheduler.cancelAll: the next account on this
  // phone must not be reminded of the last one's medicines.
  await ref
      .read(localRemindersProvider)
      .cancelAll()
      .then((_) {}, onError: (Object _) {});
}

Future<void> _afterSignOut(Ref ref) =>
    // Kotlin's LocalAccountData: the next account on this phone starts with
    // no kids-mode PIN and no hand-over mode.
    KidsModeController.clearAccountState(ref.read(localStoreProvider).device);
