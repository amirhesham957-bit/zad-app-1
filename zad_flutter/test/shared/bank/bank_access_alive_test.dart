// Home's bank pill: green whenever the listener is bound and has not gone two
// days without seeing anything. It used to want a notification in the last
// ten minutes, and read a quiet phone as «وقف» (owner, 2026-10-13).

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';

void main() {
  final now = DateTime(2026, 10, 13, 4, 10);

  BankAccessState state({
    bool granted = true,
    DateTime? connected,
    DateTime? seen,
  }) => BankAccessState(
    granted: granted,
    pending: 0,
    lastConnectedAt: connected,
    lastSeenAnyAt: seen,
  );

  test('a quiet hour is still listening', () {
    final s = state(
      connected: now.subtract(const Duration(hours: 5)),
      seen: now.subtract(const Duration(hours: 1)),
    );
    expect(s.isAlive(now), isTrue);
  });

  test('just granted, bound, nothing seen yet — listening', () {
    final s = state(connected: now.subtract(const Duration(seconds: 3)));
    expect(s.isAlive(now), isTrue);
  });

  test('two days without a single notification — stopped', () {
    final s = state(
      connected: now.subtract(const Duration(days: 3)),
      seen: now.subtract(const Duration(days: 2)),
    );
    expect(s.isAlive(now), isFalse);
  });

  test('never bound — stopped', () {
    expect(state(seen: now).isAlive(now), isFalse);
  });

  test('not granted — stopped', () {
    final s = state(granted: false, connected: now, seen: now);
    expect(s.isAlive(now), isFalse);
  });
}
