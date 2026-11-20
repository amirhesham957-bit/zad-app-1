// The transactions list: Kotlin's four filters, and a tap that offers edit and
// delete on the row.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/transactions/presentation/edit_transaction_sheet.dart';
import 'package:zad/features/transactions/presentation/transactions_screen.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';
import 'package:zad/shared/worlds/art/art.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

final DateTime _at = DateTime.utc(2026, 9, 20, 10);

class _Txns extends TransactionsController {
  new(this.rows);

  final List<ZadTransaction> rows;

  @override
  TransactionsView build() => TransactionsView(rows: rows);

  @override
  Future<void> refresh({bool force = false}) async {}
}

ZadTransaction _row(
  String id,
  String title, {
  bool income = false,
  String? source,
  String? bank,
}) => ZadTransaction.fromJson(<String, dynamic>{
  'id': id,
  'user_id': 'u',
  'amount': 10,
  'title': title,
  'created_at': _at.toIso8601String(),
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

  Future<void> pump(
    WidgetTester tester, {
    bool still = false,
    double height = 1400,
    List<ZadTransaction>? rows,
  }) async {
    tester.view
      ..physicalSize = Size(360, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...quietOrbOverrides,
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 9, 20, 12)),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          transactionsControllerProvider.overrideWith(
            () => _Txns(
              rows ??
                  <ZadTransaction>[
                    _row('1', 'قهوة'),
                    _row('2', 'مرتب', income: true),
                    _row(
                      '3',
                      'سوبرماركت',
                      source: 'notification_listener',
                      bank: 'الراجحي',
                    ),
                    _row('4', 'بنزين', source: 'receipt'),
                  ],
            ),
          ),
        ],
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: MaterialApp(
            theme: ZadTheme.light(),
            locale: const Locale('ar'),
            supportedLocales: ZadL10n.supportedLocales,
            localizationsDelegates: ZadL10n.localizationsDelegates,
            home: const TransactionsScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the four filters keep what their names say', (tester) async {
    await pump(tester);
    expect(find.text('قهوة'), findsOneWidget);
    expect(find.text('مرتب'), findsOneWidget);

    await tester.tap(find.text('الدخل'));
    await tester.pump();
    expect(find.text('قهوة'), findsNothing);
    expect(find.text('مرتب'), findsOneWidget);

    await tester.tap(find.text('المصروفات'));
    await tester.pump();
    expect(find.text('مرتب'), findsNothing);
    expect(find.text('قهوة'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('البنك'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('البنك'));
    await tester.pump();
    expect(find.text('قهوة'), findsNothing);
    expect(find.text('سوبرماركت'), findsOneWidget);
  });

  testWidgets('a tap on a row offers edit and delete; edit opens the sheet', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byIcon(ZadIcons.edit), findsNothing);

    await tester.tap(find.text('قهوة'));
    await tester.pump();
    expect(find.byIcon(ZadIcons.edit), findsOneWidget);
    expect(find.byIcon(ZadIcons.delete), findsOneWidget);

    await tester.tap(find.byIcon(ZadIcons.edit));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(EditTransactionSheet), findsOneWidget);
    expect(find.text('تعديل المعاملة'), findsOneWidget);
  });

  testWidgets('delete asks first', (tester) async {
    await pump(tester);
    await tester.tap(find.text('قهوة'));
    await tester.pump();
    await tester.tap(find.byIcon(ZadIcons.delete));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('هل أنت متأكد من حذف معاملة "قهوة"؟'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('قهوة'), findsOneWidget);
  });

  testWidgets('has no overflow at 360x640; the world says what logged itself', (
    tester,
  ) async {
    await pump(tester, height: 640);
    expect(tester.takeException(), isNull);
    expect(find.text('المعاملات'), findsOneWidget);
    // Two of today's four rows came in without typing: a bank message and
    // a receipt photo.
    expect(find.text('اتنين اتسجلوا لوحدهم النهارده'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('every row shows where it came from, drawn', (tester) async {
    await pump(tester);
    expect(find.text('الراجحي · رسالة'), findsOneWidget);
    expect(find.text('فاتورة اتصورت'), findsOneWidget);
    expect(find.text('كتبتها بإيدك'), findsNWidgets(2));
    expect(find.byType(ZadArt), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with disableAnimations the scene is still', (tester) async {
    await pump(tester, still: true);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('screenshot: the transactions world', (tester) async {
    await loadZadFonts();
    ZadTransaction sample(
      String id,
      String title,
      num amount,
      String category,
      int day, {
      bool income = false,
      String? source,
      String? bank,
    }) => ZadTransaction.fromJson(<String, dynamic>{
      'id': id,
      'user_id': 'u',
      'amount': amount,
      'title': title,
      'category': category,
      'created_at': DateTime.utc(2026, 9, day, 10).toIso8601String(),
      'wallet': 'card',
      'txn_kind': income ? 'income' : 'expense',
      'is_expense': !income,
      'source_type': source,
      'bank_name': bank,
    });
    await pump(
      tester,
      still: true,
      rows: <ZadTransaction>[
        sample('1', 'مرتب سبتمبر', 12000, 'الراتب', 1, income: true),
        sample('2', 'كارفور المعادي', 1480, 'البقالة', 19, source: 'receipt'),
        sample('3', 'بنزين', 450, 'المواصلات', 18),
        sample(
          '4',
          'فودافون فاتورة',
          320,
          'الفواتير',
          15,
          source: 'notification_listener',
          bank: 'الأهلي',
        ),
        sample('5', 'قهوة', 65, 'مطاعم', 14),
        sample('6', 'صيدلية العزبي', 210, 'الرعاية الصحية', 12),
      ],
    );
    tester.view
      ..physicalSize = const Size(860, 1864)
      ..devicePixelRatio = 2;
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_transactions.png'),
    );
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
