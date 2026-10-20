/// Whether this account still has its first steps to take (ZAD_PLAN ٢.٩).
///
/// From install to the first recorded expense in three minutes: after
/// «عرّفني بيك», one screen walks through the first expense, notifications and
/// the Telegram bot, as steps rather than banners scattered over home.
///
/// Armed only by the introduction itself, so an account that was introduced
/// before this screen existed never sees it. Kept in the `device` box under
/// the account's id: a sign-out does not bring it back, and a second account
/// on the same phone gets its own.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';

/// Whether the first steps are due for the signed-in account.
class FirstStepsController extends Notifier<bool> {
  static String _key(String uid) => 'first_steps_due:$uid';

  @override
  bool build() {
    final uid = ref.watch(sessionControllerProvider);
    if (uid == null) return false;
    return ref.read(localStoreProvider).device.get(_key(uid)) == 'true';
  }

  /// Called by the introduction, before it saves: the steps follow it.
  void arm() {
    final uid = ref.read(sessionControllerProvider);
    if (uid == null || state) return;
    state = true;
    unawaited(ref.read(localStoreProvider).device.put(_key(uid), 'true'));
  }

  /// Done or put off — either way the app opens and the steps never return.
  void finish() {
    final uid = ref.read(sessionControllerProvider);
    if (uid == null || !state) return;
    state = false;
    unawaited(ref.read(localStoreProvider).device.delete(_key(uid)));
  }
}

/// The controller.
final firstStepsControllerProvider =
    NotifierProvider<FirstStepsController, bool>(FirstStepsController.new);

/// Whether the gate shows the first steps. Never in kids mode.
final firstStepsDueProvider = Provider<bool>((ref) {
  if (ref.watch(kidsModeActiveProvider)) return false;
  return ref.watch(firstStepsControllerProvider);
});
