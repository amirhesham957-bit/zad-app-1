/// Broke mode and the savings challenge, on screen.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/modes/domain/modes.dart';

/// What the screens draw.
class ModesView {
  /// Creates a view.
  const new({
    this.broke,
    this.challenge,
    this.busy = false,
    this.failed = false,
  });

  /// The broke-mode row, running or not.
  final BrokeMode? broke;

  /// The active challenge.
  final SavingsChallenge? challenge;

  /// A write is in flight.
  final bool busy;

  /// The last write did not read back.
  final bool failed;
}

/// Holds both.
class ModesController extends Notifier<ModesView> {
  @override
  ModesView build() {
    final c = ref.read(modesRepositoryProvider).cached();
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return ModesView(broke: c.broke, challenge: c.challenge);
  }

  /// Reads both again.
  Future<void> refresh() async {
    try {
      final r = await ref.read(modesRepositoryProvider).refresh();
      if (!ref.mounted) return;
      state = ModesView(broke: r.broke, challenge: r.challenge);
    } on Object {
      // Keeps what it had; neither card is the balance.
    }
  }

  /// Whether broke mode is running now.
  bool get brokeActive =>
      state.broke?.isActiveAt(ref.read(nowProvider)()) ?? false;

  /// Turns broke mode on; [cashLeft] null means "use my balance".
  Future<bool> activateBroke(double? cashLeft) async {
    final snapshot = ref.read(budgetControllerProvider).snapshot;
    final now = ref.read(nowProvider)();
    final plan = brokeModePlan(
      cashLeft: cashLeft,
      available: snapshot?.spendable,
      limitConfirmed: snapshot?.limitConfirmed ?? false,
      daysLeft: snapshot?.daysLeft ?? 1,
      cycleEnd: snapshot?.cycleEnd,
      now: now,
    );
    return await _write(
      () => ref
          .read(modesRepositoryProvider)
          .activateBrokeMode(plan, currency: snapshot?.currency, now: now),
    );
  }

  /// Turns broke mode off.
  Future<bool> endBroke() => _write(
    () => ref
        .read(modesRepositoryProvider)
        .endBrokeMode(now: ref.read(nowProvider)()),
  );

  /// Starts a challenge.
  Future<bool> startChallenge(double dailyCap, int lengthDays) => _write(
    () => ref
        .read(modesRepositoryProvider)
        .startChallenge(
          dailyCap: dailyCap,
          lengthDays: lengthDays,
          today: today(),
          currency: ref.read(budgetControllerProvider).snapshot?.currency,
        ),
  );

  /// Stops the challenge.
  Future<bool> stopChallenge() async {
    final c = state.challenge;
    if (c == null) return true;
    return await _write(
      () => ref
          .read(modesRepositoryProvider)
          .abandonChallenge(c.id, now: ref.read(nowProvider)()),
    );
  }

  /// Today in the account's market zone, as a civil date.
  DateTime today() {
    final local = tz.TZDateTime.from(
      ref.read(nowProvider)().toUtc(),
      tz.getLocation(ref.read(accountTimeZoneProvider)),
    );
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// Whether [at] falls on [today] in the account's zone.
  bool isToday(DateTime at) {
    final local = tz.TZDateTime.from(
      at.toUtc(),
      tz.getLocation(ref.read(accountTimeZoneProvider)),
    );
    final t = today();
    return local.year == t.year && local.month == t.month && local.day == t.day;
  }

  Future<bool> _write(Future<bool> Function() write) async {
    state = ModesView(
      broke: state.broke,
      challenge: state.challenge,
      busy: true,
    );
    var ok = false;
    try {
      ok = await write();
    } on Object {
      ok = false;
    }
    if (!ref.mounted) return ok;
    final c = ref.read(modesRepositoryProvider).cached();
    state = ModesView(broke: c.broke, challenge: c.challenge, failed: !ok);
    return ok;
  }
}

/// Broke mode and the savings challenge.
final modesControllerProvider = NotifierProvider<ModesController, ModesView>(
  ModesController.new,
);
