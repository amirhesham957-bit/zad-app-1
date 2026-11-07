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
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/bank/data/bank_capture_marker.dart';
import 'package:zad/shared/bank/data/device_send_key.dart';
import 'package:zad/shared/bank/data/notification_drain.dart';
import 'package:zad/shared/session/product_events.dart';

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

  /// Granted, worked, and has seen nothing at all for [kListenerStallAfter].
  ///
  /// The listener sees every notification on the phone (WhatsApp included),
  /// not only bank ones, so two days of nothing is a dead service, not a
  /// quiet phone. The owner's phone stopped sending on 2026-10-05 and nothing
  /// said so: this state used to read as [flowing] once anything had ever
  /// been captured.
  stalled,
}

/// The product event a reading sends (ZAD_PLAN ٣.١, «نبض المستمع»).
///
/// The owner's phone stopped reading the bank on 2026-10-05 and the server
/// could not tell: the screen said so, but only to whoever opened it. Each
/// open now leaves `bank.<state>` in `zad_product_events`, so whose listener
/// stalled is one query — name and time only, nothing from a message.
String bankPulseEvent(BankAccessHealth health) => switch (health) {
  BankAccessHealth.notGranted => 'bank.off',
  BankAccessHealth.flowing => 'bank.flowing',
  BankAccessHealth.grantedButSilent => 'bank.silent',
  BankAccessHealth.stalled => 'bank.stalled',
};

/// At most one pulse per state in this window, however often the app opens.
const Duration kBankPulseEvery = Duration(hours: 12);

/// Captured notifications waiting on the phone that count as a backlog: more
/// than one drain's worth of ordinary traffic.
const int kBankBacklogAt = 5;

/// How long without any notification seen before the listener counts as
/// stopped.
///
/// Twelve hours, not two days (owner, 2026-11-07): the listener sees every
/// notification on the phone, not only the bank's, and the owner's Xiaomi
/// stopped it daily — a BDC payment at 15:22 on 6/11 never reached the server,
/// and two days of silence meant the banner and the watchdog's «اضغط للإصلاح»
/// came two days of payments too late. Same value as the Kotlin watchdog's
/// `STALL_AFTER_MS`.
const Duration kListenerStallAfter = Duration(hours: 12);

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
    this.checkedAt,
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

  /// When the platform was last asked — the "now" [health] is judged at.
  final DateTime? checkedAt;

  /// Whether home's pill reads green: granted, bound at least once, and not
  /// [BankAccessHealth.stalled] — the same two days the bank screen uses.
  ///
  /// Kotlin's `isListenerAlive` also wanted a notification in the last ten
  /// minutes. That read every quiet phone, and every phone that had just
  /// been given the permission and seen nothing yet, as «وقف» while the
  /// listener was bound and working (owner, 2026-10-13).
  bool isAlive(DateTime now) {
    if (!granted || lastConnectedAt == null) return false;
    final seen = lastSeenAnyAt;
    return seen == null || now.difference(seen) < kListenerStallAfter;
  }

  /// The reading to show.
  BankAccessHealth get health {
    if (!granted) return BankAccessHealth.notGranted;
    final seen = lastSeenAnyAt;
    final at = checkedAt;
    if (seen != null &&
        at != null &&
        at.difference(seen) >= kListenerStallAfter) {
      return BankAccessHealth.stalled;
    }
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
    checkedAt: checkedAt,
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
        checkedAt: ref.read(nowProvider)(),
      );
      await marker.rememberAccess(granted: granted, connectedAt: connectedAt);
      _pulse();
      if (granted) _ensureDeviceKey();
    } on Object {
      // The plugin is not there — a test host, or a platform without it. Not
      // an error worth showing anyone; it just means nothing is flowing.
      if (!ref.mounted) return;
      state = state.copyWith(checking: false, granted: false);
    }
  }

  /// Sends [bankPulseEvent] for this reading. A statistic, never a feature:
  /// whatever goes wrong here stays here and never changes the reading.
  void _pulse() {
    if (!ref.mounted) return;
    try {
      final events = ref.read(productEventsProvider);
      unawaited(
        events
            .log(bankPulseEvent(state.health), every: kBankPulseEvery)
            .catchError((Object _) => false),
      );
      // «flowing» says the listener sees notifications, not that they leave
      // the phone. The owner's phone read «flowing» for two days while not
      // one notification reached the server (2026-11-04): this is the line
      // that would have said where they were.
      if (state.pending >= kBankBacklogAt) {
        unawaited(
          events
              .log('bank.backlog', every: kBankPulseEvery)
              .catchError((Object _) => false),
        );
      }
    } on Object {
      // No session graph (a test host, a headless engine).
    }
  }

  /// ٢.٧(ب): the key the closed app sends bank messages with. Registered here,
  /// where the app already checks the channel on every open, and only while
  /// reading is on — no key for a phone that sends nothing. Never fails the
  /// reading: without a key the inbox simply waits for the next open.
  void _ensureDeviceKey() {
    if (!ref.mounted) return;
    try {
      final userId = ref.read(signedInUserIdProvider)();
      if (userId == null) return;
      unawaited(
        ref
            .read(deviceSendKeyProvider)
            .ensureRegistered(userId)
            .then((_) {}, onError: (Object _) {}),
      );
    } on Object {
      // No session graph (a test host).
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
