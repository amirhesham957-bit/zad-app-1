// The home proposal cards swipe (ZAD_PLAN ٢.٤): right confirms, left
// postpones — by the hand, in an RTL app — and only a card whose own button
// says «تأكيد» confirms by swipe.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/proposals/application/proposal_snooze.dart';
import 'package:zad/features/proposals/presentation/proposals_screen.dart';
import 'package:zad/shared/proposals/domain/transaction_proposal.dart';

TransactionProposal _proposal({String status = 'awaiting_confirmation'}) =>
    TransactionProposal.fromJson(<String, dynamic>{
      'id': 'p1',
      'amount': 125.5,
      'title': 'مشتريات',
      'status': status,
      'created_at': '2026-09-20T09:00:00Z',
      'expires_at': '2026-09-27T09:00:00Z',
      'txn_kind': status == 'needs_classification' ? null : 'expense',
    });

void main() {
  late List<String> calls;

  Future<void> pump(WidgetTester tester, TransactionProposal p) {
    calls = <String>[];
    return tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SwipeableProposal(
              proposal: p,
              busy: false,
              onConfirm: () => calls.add('confirm'),
              onPostpone: () => calls.add('postpone'),
              child: const SizedBox(
                height: 120,
                width: double.infinity,
                child: Text('card'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a hand moving right confirms, and the card stays', (
    tester,
  ) async {
    await pump(tester, _proposal());
    await tester.fling(find.text('card'), const Offset(500, 0), 2000);
    await tester.pumpAndSettle();
    expect(calls, <String>['confirm']);
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('a hand moving left postpones', (tester) async {
    await pump(tester, _proposal());
    await tester.fling(find.text('card'), const Offset(-500, 0), 2000);
    await tester.pumpAndSettle();
    expect(calls, <String>['postpone']);
  });

  testWidgets('a proposal still asking its direction never confirms by swipe', (
    tester,
  ) async {
    await pump(tester, _proposal(status: 'needs_classification'));
    await tester.fling(find.text('card'), const Offset(500, 0), 2000);
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });

  test('a postponed proposal comes back after four hours', () {
    var now = DateTime.utc(2026, 10, 18, 12);
    final container = ProviderContainer(
      overrides: [nowProvider.overrideWithValue(() => now)],
    );
    addTearDown(container.dispose);
    final snooze = container.read(proposalSnoozeProvider.notifier)
      ..snooze('p1');
    expect(snooze.isSnoozed('p1', now), isTrue);
    now = now.add(kProposalSnooze);
    expect(snooze.isSnoozed('p1', now), isFalse);
  });
}
