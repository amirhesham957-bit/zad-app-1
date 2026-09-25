/// Who is signed in, and what has to happen when that changes.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/auth/application/auth_controller.dart';
import 'package:zad/features/brain/application/agent_actions_controller.dart';
import 'package:zad/features/brain/application/brain_health_controller.dart';
import 'package:zad/features/brain/application/knowledge_map_controller.dart';
import 'package:zad/features/brain/application/memory_controller.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/budget/presentation/finances_screen.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/insights/application/insights_controller.dart';
import 'package:zad/features/kids/application/kids_mode_controller.dart';
import 'package:zad/features/modes/application/modes_controller.dart';
import 'package:zad/features/notifications/application/notifications_controller.dart';
import 'package:zad/features/obligations/application/obligations_controller.dart';
import 'package:zad/features/proposals/application/proposals_controller.dart';
import 'package:zad/features/settings/application/settings_controller.dart';
import 'package:zad/features/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/features/tasbiha/application/tasbiha_controller.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';

/// The signed-in account id, or null.
///
/// Seeded **synchronously** from the client's restored session rather than
/// awaited from the stream. `Supabase.initialize` has already read the session
/// off disk by the time `bootstrap` returns, so the id is known before the
/// first frame — and a `StreamProvider` here would still have opened on
/// `AsyncLoading`, which is a spinner shown to somebody who was never signed
/// out. That is the same white-screen-on-open this app's whole cache exists to
/// avoid.
class SessionController extends Notifier<String?> {
  @override
  String? build() {
    final gateway = ref.watch(authGatewayProvider);

    final subscription = gateway.userIdChanges.listen((id) {
      // The stream is a ReplaySubject, so subscribing replays the events that
      // came before this listener existed and the seed is usually re-delivered
      // verbatim. Comparing first keeps that from looking like an account
      // change and invalidating the world on every rebuild.
      if (!ref.mounted || state == id) return;
      state = id;
      _forgetPreviousAccount();

      // A session is the one thing the queue was missing. Entries that failed
      // with `FlushStop.unauthenticated` are still sitting there uncharged —
      // including bank notifications captured before anybody signed in — and
      // the periodic tick would get to them within thirty seconds. Asking now
      // costs one call and makes signing in the moment the backlog moves.
      if (id != null) unawaited(ref.read(outboxRunnerProvider).flushNow());
    });
    ref.onDispose(subscription.cancel);

    return gateway.currentUserId;
  }

  /// Unsent writes belonging to the signed-in account.
  ///
  /// The screen asks before signing out, because these are rows the customer
  /// was already told were saved. They survive a sign-out — the outbox is not
  /// a cache — but they carry the *previous* account's `user_id`, so sending
  /// them under the next session's token is an RLS refusal, which the outbox
  /// classifies as permanent and turns into a dead letter.
  int get pendingWriteCount =>
      ref.read(outboxProvider).entries(includeDead: false).length;

  /// Ends the session and leaves nothing of it on the device.
  ///
  /// Throws `AuthFailure` if the server call fails — but the caches are cleared
  /// either way, from a `finally`. gotrue removes the stored session before it
  /// talks to the server, so a throw here means "signed out locally, the server
  /// was not told": keeping the previous account's figures on screen for that
  /// case would be the worst possible reading of an error.
  Future<void> signOut() async {
    // First, while the session can still delete its own row: this phone
    // stops receiving the account's alerts. Never throws, never blocks long.
    await ref.read(pushRegistrarProvider).unregister();
    try {
      await ref.read(authGatewayProvider).signOut();
    } finally {
      await ref.read(localStoreProvider).clearCaches();
      // Kotlin's LocalAccountData: the next account on this phone starts
      // with no kids-mode PIN and no hand-over mode.
      await KidsModeController.clearAccountState(
        ref.read(localStoreProvider).device,
      );
      if (ref.mounted) {
        state = null;
        _forgetPreviousAccount();
      }
    }
  }

  /// Drops every screen's in-memory copy of the last account's data.
  ///
  /// Clearing the boxes is not enough on its own: the controllers already read
  /// those boxes into state, and a `Notifier` that is not invalidated keeps
  /// holding what it read. Invalidating marks them stale without building
  /// them, so the screens that are actually on display refetch and the ones
  /// that are not cost nothing.
  void _forgetPreviousAccount() {
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
}

/// The session.
final sessionControllerProvider = NotifierProvider<SessionController, String?>(
  SessionController.new,
);
