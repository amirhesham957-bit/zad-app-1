/// Whether bank messages are actually reaching the app.
///
/// The distinction this exists to draw: **granted is not the same as
/// running**. Android kills a notification listener under memory pressure or
/// after an update and sometimes never rebinds it, and nothing in the UI used
/// to tell the difference — the old banner read the permission and nothing
/// else. The result was an ingest table that stayed completely empty while the
/// permission was switched on, and no way to know why.
///
/// So there are three states here, not two, and the middle one is the whole
/// point.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/features/bank/data/bank_capture_marker.dart';
import 'package:zad/features/bank/data/notification_drain.dart';

/// How the bank channel stands.
enum BankAccessHealth {
  /// The user has not granted notification access. Nothing can arrive.
  notGranted,

  /// Granted, and something has arrived. Working.
  flowing,

  /// Granted, but nothing has ever been captured.
  ///
  /// Either the phone has genuinely had no notifications worth capturing, or
  /// the service is not bound. The app cannot tell those apart, so it says so
  /// and offers the one action that helps.
  grantedButSilent,
}

/// What the screen draws.
class BankAccessState {
  /// Creates a state.
  const new({
    required this.granted,
    required this.pending,
    this.lastCapturedAt,
    this.lastConnectedAt,
    this.lastSeenAnyAt,
    this.testResult,
    this.checking = false,
  });

  /// Whether notification access is granted.
  final bool granted;

  /// How many captured notifications are waiting to be drained.
  final int pending;

  /// When this device last captured anything at all, ever.
  final DateTime? lastCapturedAt;

  /// When the listener service last bound (Kotlin's `lastConnectedAt`).
  final DateTime? lastConnectedAt;

  /// When it last saw any notification at all, even one it then ignored
  /// (Kotlin's `lastSawNotificationAt`).
  final DateTime? lastSeenAnyAt;

  /// The test notification: `sent`, `received_by_listener`, or null.
  final String? testResult;

  /// Whether a check is in flight.
  final bool checking;

  /// Kotlin's `BankReadingStatus.isListenerAlive`: granted, bound at least
  /// once, and a notification seen in the last ten minutes — a phone can be
  /// genuinely quiet, and that much grace keeps the pill from flapping.
  bool isAlive(DateTime now) =>
      granted &&
      lastConnectedAt != null &&
      lastSeenAnyAt != null &&
      now.difference(lastSeenAnyAt!) < const Duration(minutes: 10);

  /// The reading to show.
  BankAccessHealth get health {
    if (!granted) return BankAccessHealth.notGranted;
    if (lastCapturedAt == null && pending == 0) {
      return BankAccessHealth.grantedButSilent;
    }
    return BankAccessHealth.flowing;
  }

  /// A copy with the given fields replaced.
  BankAccessState copyWith({
    bool? granted,
    int? pending,
    DateTime? lastCapturedAt,
    bool? checking,
  }) => BankAccessState(
    granted: granted ?? this.granted,
    pending: pending ?? this.pending,
    lastCapturedAt: lastCapturedAt ?? this.lastCapturedAt,
    lastConnectedAt: lastConnectedAt,
    lastSeenAnyAt: lastSeenAnyAt,
    testResult: testResult,
    checking: checking ?? this.checking,
  );
}

/// Reads and repairs the bank channel's health.
class BankAccessController extends Notifier<BankAccessState> {
  @override
  BankAccessState build() {
    // Synchronous, from what is already on the device — the same rule as the
    // budget: a screen opens with what is known and asks afterwards. That
    // includes the last check's answer: starting from "not granted" put the
    // enable-bank-reading step on home for a moment on every launch.
    final marker = ref.read(bankCaptureMarkerProvider);
    final known = marker.lastAccess();
    final state = BankAccessState(
      granted: known.granted,
      pending: 0,
      lastCapturedAt: marker.lastCapturedAt(),
      lastConnectedAt: known.connectedAt,
    );
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return state;
  }

  /// Asks the platform where things stand.
  ///
  /// Also asks Android to rebind while it is here. That call is a no-op when
  /// the service is already bound, and it is the only thing that fixes the
  /// case where it is not — so doing it on every check costs nothing and is
  /// the difference between a channel that silently died and one that comes
  /// back.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    state = state.copyWith(checking: true);

    try {
      final listener = ref.read(bankListenerProvider);
      final granted = await listener.isPermissionGranted();
      if (granted) await listener.requestRebind();
      final pending = granted ? await listener.pendingCount() : 0;
      final status = await listener.listenerStatus();

      if (!ref.mounted) return;
      final marker = ref.read(bankCaptureMarkerProvider);
      // A listener that reports no bind this time keeps the last one we saw —
      // the platform forgets it across process restarts, the step should not.
      final connectedAt =
          status.lastConnectedAt ?? (granted ? state.lastConnectedAt : null);
      state = BankAccessState(
        granted: granted,
        pending: pending,
        lastCapturedAt: marker.lastCapturedAt(),
        lastConnectedAt: connectedAt,
        lastSeenAnyAt: status.lastSeenAnyAt,
        testResult: status.testResult,
      );
      await marker.rememberAccess(granted: granted, connectedAt: connectedAt);
    } on Object {
      // The plugin is not there — a test host, or a platform without it. Not
      // an error worth showing anyone; it just means nothing is flowing.
      if (!ref.mounted) return;
      state = state.copyWith(checking: false, granted: false);
    }
  }

  /// Opens the system screen. There is no in-app prompt for this permission.
  Future<void> openSettings() async {
    await ref.read(bankListenerProvider).openPermissionSettings();
  }

  /// Kotlin's `BankReadingStatus.repairListening` — «اضغط للإصلاح»: rebind
  /// when access is granted; otherwise the only fix is the customer turning
  /// it back on, so go straight to that screen. MIUI's battery manager kills
  /// the service and revokes the permission with it, and a silent rebind
  /// there does nothing at all.
  Future<void> repair() async {
    final listener = ref.read(bankListenerProvider);
    try {
      if (await listener.isPermissionGranted()) {
        await listener.requestRebind();
      } else {
        await listener.openPermissionSettings();
      }
    } on Object {
      // No plugin (a test host). Nothing to repair.
    }
    await refresh();
  }
}

/// The bank channel's health.
final bankAccessControllerProvider =
    NotifierProvider<BankAccessController, BankAccessState>(
      BankAccessController.new,
    );
