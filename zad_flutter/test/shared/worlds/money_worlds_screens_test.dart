// The four money worlds (المعاملات، الميزانية، كشف الحساب، الاشتراكات), with
// sample data, rendered to build/screens/ when ZAD_SCREENS=1:
//   ZAD_SCREENS=1 flutter test -j 1 --update-goldens \
//     test/shared/worlds/money_worlds_screens_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/transactions/presentation/transactions_screen.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: <Override>[
    ...quietOrbOverrides,
    nowProvider.overrideWithValue(() => DateTime.utc(2026, 9, 25, 9)),
    accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
    ...overrides,
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ZadTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: ZadL10n.supportedLocales,
    localizationsDelegates: ZadL10n.localizationsDelegates,
    home: home,
  ),
);

Future<void> _phone(WidgetTester tester) async {
  await loadZadFonts();
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  ZadScreens.worldScreen = (w) => (_) async {};
}

class _Txns extends TransactionsController {
  new(this.rows);
  final List<ZadTransaction> rows;
  @override
  TransactionsView build() => TransactionsView(rows: rows);
  @override
  Future<void> refresh({bool force = false}) async {}
}

ZadTransaction _tx(
  String id,
  String title,
  double amount, {
  String? category,
  bool income = false,
  String? source,
  String? bank,
  int hour = 8,
}) => ZadTransaction.fromJson(<String, dynamic>{
  'id': id,
  'user_id': 'u',
  'amount': amount,
  'title': title,
  'category': category,
  'created_at': DateTime.utc(2026, 9, 25, hour).toIso8601String(),
  'wallet': 'card',
  'txn_kind': income ? 'income' : 'expense',
  'is_expense': !income,
  'source_type': source,
  'bank_name': bank,
});

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });
  tearDown(() => ZadScreens.worldScreen = (_) => null);
  final shoot = Platform.environment['ZAD_SCREENS'] == '1';

  testWidgets('screenshot: the transactions world', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(
      _app(const TransactionsScreen(), [
        transactionsControllerProvider.overrideWith(
          () => _Txns(<ZadTransaction>[
            _tx(
              '1',
              'قهوة',
              50,
              category: 'المشروبات',
              source: 'bank_sms',
              bank: 'الراجحي',
            ),
            _tx(
              '2',
              'بنده',
              214,
              category: 'البقالة',
              source: 'receipt',
              hour: 7,
            ),
            _tx(
              '3',
              'بنزين',
              90,
              category: 'مواصلات',
              source: 'voice',
              hour: 6,
            ),
            _tx(
              '4',
              'النهدي',
              38,
              category: 'الرعاية الصحية',
              source: 'bank_notification',
              bank: 'الأهلي',
              hour: 5,
            ),
            _tx('5', 'مرتب', 12000, income: true, category: 'دخل', hour: 4),
          ]),
        ),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_transactions.png'),
    );
    await tester.pumpWidget(const SizedBox());
  }, skip: !shoot);
}
