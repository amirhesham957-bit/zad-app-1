// The 14 days after asking to delete: the customer is asked once at the door,
// and no answer from the server never stops them there.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/app/account_restore.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';

class _Fake implements AccountDeletionRemote {
  new(this.purge, {this.fails = false});

  final DateTime? purge;
  final bool fails;
  int cancels = 0;

  @override
  Future<DateTime?> pendingPurge() async {
    if (fails) throw StateError('offline');
    return purge;
  }

  @override
  Future<bool> cancel() async {
    cancels++;
    return true;
  }
}

Future<void> _open(WidgetTester tester, _Fake fake) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accountDeletionProvider.overrideWithValue(fake)],
      child: MaterialApp(
        localizationsDelegates: ZadL10n.localizationsDelegates,
        supportedLocales: ZadL10n.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => offerAccountRestore(context, ref),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  test('days left: a part-day counts, and it is never zero', () {
    final now = DateTime.utc(2026, 11, 8, 12);
    expect(daysUntilPurge(now.add(const Duration(days: 14)), now), 14);
    expect(daysUntilPurge(now.add(const Duration(hours: 25)), now), 2);
    expect(daysUntilPurge(now.subtract(const Duration(hours: 1)), now), 1);
  });

  testWidgets('no deletion pending: nothing is asked', (tester) async {
    await _open(tester, _Fake(null));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the server does not answer: nothing is asked', (tester) async {
    await _open(tester, _Fake(null, fails: true));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a pending deletion is asked about, and restored on yes', (
    tester,
  ) async {
    final fake = _Fake(DateTime.now().toUtc().add(const Duration(days: 10)));
    await _open(tester, fake);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('account-restore-yes')));
    await tester.pumpAndSettle();
    expect(fake.cancels, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
