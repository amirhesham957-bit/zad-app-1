// The transactions list: Kotlin's four filters, and a tap that offers edit and
// delete on the row.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';
import 'package:zad/features/transactions/presentation/edit_transaction_sheet.dart';
import 'package:zad/features/transactions/presentation/transactions_screen.dart';

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
});

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionsControllerProvider.overrideWith(
          () => _Txns(<ZadTransaction>[
            _row('1', 'قهوة'),
            _row('2', 'مرتب', income: true),
            _row('3', 'سوبرماركت', source: 'notification_listener'),
          ]),
        ),
      ],
      child: MaterialApp(
        theme: ZadTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: TransactionsScreen(),
        ),
      ),
    ),
  );

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
    await tester.pumpAndSettle();
    expect(find.byType(EditTransactionSheet), findsOneWidget);
    expect(find.text('تعديل المعاملة'), findsOneWidget);
  });

  testWidgets('delete asks first', (tester) async {
    await pump(tester);
    await tester.tap(find.text('قهوة'));
    await tester.pump();
    await tester.tap(find.byIcon(ZadIcons.delete));
    await tester.pumpAndSettle();

    expect(find.text('هل أنت متأكد من حذف معاملة "قهوة"؟'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.text('قهوة'), findsOneWidget);
  });
}
