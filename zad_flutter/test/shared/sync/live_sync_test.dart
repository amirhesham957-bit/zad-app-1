// A change on the server reaches the open screens — once per burst, and only
// screens that are already built.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/sync/live_sync.dart';

import '../../support/quiet_household.dart';

class _Changes implements LiveChanges {
  final List<String> watched = <String>[];
  final List<StreamController<String>> streams = <StreamController<String>>[];
  int cancelled = 0;

  StreamController<String> get last => streams.last;

  @override
  Stream<String> watch(String userId) {
    watched.add(userId);
    final c = StreamController<String>(onCancel: () => cancelled++);
    streams.add(c);
    return c.stream;
  }
}

class _CountingPharmacy extends QuietPharmacy {
  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;
}

void main() {
  // testWidgets for its fake clock: tester.pump moves time, timers included.
  testWidgets('a burst on one table is one refresh, after it settles', (
    tester,
  ) async {
    final changes = _Changes();
    final heard = <String>[];
    final sync = LiveSync(changes: changes, onChange: (t) async => heard.add(t))
      ..start('u');

    // A receipt writes several pantry rows in a moment.
    for (var i = 0; i < 5; i++) {
      changes.last.add('zad_inventory');
      await tester.pump(const Duration(milliseconds: 200));
    }
    changes.last.add('zad_transactions');
    await tester.pump();
    expect(heard, isEmpty, reason: 'still settling');

    await tester.pump(const Duration(seconds: 1));
    expect(heard, <String>['zad_inventory', 'zad_transactions']);
    unawaited(sync.stop());
    await tester.pump();
  });

  testWidgets('stopping drops what was gathered and leaves the channel', (
    tester,
  ) async {
    final changes = _Changes();
    final heard = <String>[];
    final sync = LiveSync(changes: changes, onChange: (t) async => heard.add(t))
      ..start('u');
    changes.last.add('zad_transactions');
    await tester.pump();
    unawaited(sync.stop());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(heard, isEmpty);
    expect(changes.cancelled, 1);
    expect(sync.isRunning, isFalse);
  });

  testWidgets('the same account once; another account replaces it', (
    tester,
  ) async {
    final changes = _Changes();
    final sync = LiveSync(changes: changes, onChange: (_) async {})
      ..start('a')
      ..start('a');
    expect(changes.watched, <String>['a']);

    sync.start('b');
    await tester.pump();
    expect(changes.watched, <String>['a', 'b']);
    expect(changes.cancelled, 1);
    expect(sync.isRunning, isTrue, reason: 'b is still listening');
    unawaited(sync.stop());
    await tester.pump();
  });

  testWidgets('a failing refresh does not stop the next one', (tester) async {
    final changes = _Changes();
    var calls = 0;
    final sync = LiveSync(
      changes: changes,
      onChange: (_) async {
        calls++;
        throw StateError('offline');
      },
    )..start('u');
    changes.last.add('zad_inventory');
    await tester.pump(const Duration(seconds: 2));
    changes.last.add('zad_inventory');
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 2);
    unawaited(sync.stop());
    await tester.pump();
  });

  group('refreshAfterLiveChange', () {
    late _CountingPharmacy pharmacy;
    late ProviderContainer container;
    final refresher = Provider<Future<void> Function(String)>(
      (ref) =>
          (table) => refreshAfterLiveChange(ref, table),
    );

    setUp(() {
      pharmacy = _CountingPharmacy();
      container = ProviderContainer(
        overrides: [pharmacyControllerProvider.overrideWith(() => pharmacy)],
      );
    });
    tearDown(() => container.dispose());

    test('refreshes the pharmacy when it is on screen', () async {
      container.read(pharmacyControllerProvider);
      await container.read(refresher)('zad_pharmacy_items');
      expect(pharmacy.refreshes, 1);
    });

    test('builds nothing that was not open', () async {
      await container.read(refresher)('zad_pharmacy_items');
      await container.read(refresher)('zad_transactions');
      expect(pharmacy.refreshes, 0);
      expect(container.exists(pharmacyControllerProvider), isFalse);
      expect(container.exists(budgetControllerProvider), isFalse);
    });

    test('an unknown table does nothing', () async {
      container.read(pharmacyControllerProvider);
      await container.read(refresher)('agent_logs');
      expect(pharmacy.refreshes, 0);
    });
  });
}
