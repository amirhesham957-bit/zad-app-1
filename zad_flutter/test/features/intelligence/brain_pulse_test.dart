// The pulse card follows a tap: a window, the highest day, the top category.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/intelligence/presentation/brain_pulse.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

final DateTime _now = DateTime.utc(2026, 11, 9, 12);

ZadTransaction _spent(String id, double amount, int daysAgo, String cat) =>
    ZadTransaction.expense(
      id: id,
      userId: 'u',
      amount: amount,
      title: id,
      createdAt: _now.subtract(Duration(days: daysAgo)),
      wallet: Wallet.cash,
      category: cat,
    );

void main() {
  setUpAll(tzdata.initializeTimeZones);

  late List<String> asked;

  Future<void> pump(WidgetTester tester) async {
    asked = <String>[];
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => _now),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: ZadL10n.localizationsDelegates,
          supportedLocales: ZadL10n.supportedLocales,
          home: Scaffold(
            body: BrainPulseCard(
              currency: 'EGP',
              onAsk: asked.add,
              rows: <ZadTransaction>[
                _spent('a', 100, 1, 'قهوة'),
                _spent('b', 500, 2, 'بقالة'),
                _spent('c', 50, 20, 'قهوة'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the highest day takes over the figure', (tester) async {
    await pump(tester);
    expect(find.text('آخر 14 يوم'), findsOneWidget);
    expect(find.text('600 EGP'), findsOneWidget);

    await tester.tap(find.text('أعلى يوم'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('500 EGP'), findsOneWidget);
    expect(find.text('آخر 14 يوم'), findsNothing);
  });

  testWidgets('a shorter window recounts, in Arabic plural', (tester) async {
    await pump(tester);
    await tester.tap(find.text('7'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('آخر 7 أيام'), findsOneWidget);
  });

  testWidgets('the biggest category becomes a question', (tester) async {
    await pump(tester);
    await tester.tap(find.text('بقالة'));
    expect(asked, <String>['حلل صرفي على بقالة']);
  });
}
