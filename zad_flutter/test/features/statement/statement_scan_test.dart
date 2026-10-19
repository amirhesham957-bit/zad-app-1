// A statement photo or PDF (ZAD_PLAN ٣.٣): the server's reading becomes the
// same review a CSV gets, a row the statement's own balance disagrees with
// starts unticked, and the banner says what the balance check found.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/statement/data/statement_reader.dart';
import 'package:zad/features/statement/domain/statement_import.dart';
import 'package:zad/features/statement/presentation/statement_import_screen.dart';
import 'package:zad/shared/transactions/data/merchant_categories.dart';

class _Reader implements StatementReader {
  new(this.answer, {this.error});

  final Map<String, dynamic>? answer;
  final Object? error;
  String? mime;

  @override
  Future<Map<String, dynamic>?> read({
    required String userId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    mime = mimeType;
    if (error case final e?) Error.throwWithStackTrace(e, StackTrace.current);
    return answer;
  }
}

class _NoCorrections implements MerchantCategories {
  @override
  String? categoryFor(String? merchant) => null;

  @override
  Future<void> remember(String? merchant, String? category) async {}
}

const Map<String, dynamic> _statement = <String, dynamic>{
  'currency': 'EGP',
  'check': 'mismatch',
  'dropped': 1,
  'rows': <Map<String, dynamic>>[
    <String, dynamic>{
      'date': '2026-10-01',
      'description': 'CARREFOUR MAADI',
      'amount': 250,
      'direction': 'debit',
      'balance_ok': true,
    },
    <String, dynamic>{
      'date': '2026-10-02',
      'description': 'راتب أكتوبر',
      'amount': 5000,
      'direction': 'credit',
      'balance_ok': null,
    },
    <String, dynamic>{
      'date': '2026-10-03',
      'description': 'ATM',
      'amount': 80,
      'direction': 'debit',
      'balance_ok': false,
    },
  ],
};

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  group('readScannedStatement', () {
    test('rows, direction, balance marks and the check are kept', () {
      final s = readScannedStatement(_statement)!;
      expect(s.rows, hasLength(3));
      expect(s.rows[0].isExpense, isTrue);
      expect(s.rows[1].isExpense, isFalse);
      expect(s.rows[2].balanceOk, isFalse);
      expect(s.rows[1].category, 'الراتب');
      expect(s.check, StatementCheck.mismatch);
      expect(s.dropped, 1);
      expect(s.currency, 'EGP');
      expect(s.rows.map((r) => r.rowIndex), <int>[0, 1, 2]);
    });

    test('a row with no real date or amount is skipped; none left is null', () {
      expect(
        readScannedStatement(<String, dynamic>{
          'rows': <Map<String, dynamic>>[
            <String, dynamic>{'date': 'x', 'amount': 5, 'direction': 'debit'},
            <String, dynamic>{'date': '2026-10-01', 'amount': 0},
          ],
        }),
        isNull,
      );
      expect(readScannedStatement(<String, dynamic>{}), isNull);
    });

    test('a blank description takes the imported title', () {
      final s = readScannedStatement(<String, dynamic>{
        'rows': <Map<String, dynamic>>[
          <String, dynamic>{
            'date': '2026-10-01',
            'description': '  ',
            'amount': 5,
            'direction': 'debit',
          },
        ],
      })!;
      expect(s.rows.single.title, kImportedTitle);
      expect(s.check, StatementCheck.unknown);
    });
  });

  test('file kinds and mime types go by the extension', () {
    expect(statementFileKind('kashf.PDF'), StatementFileKind.pdf);
    expect(statementFileKind('a.csv'), StatementFileKind.csv);
    expect(statementFileKind('IMG_1.jpeg'), StatementFileKind.image);
    expect(statementFileKind('notes.docx'), isNull);
    expect(statementFileKind('noext'), isNull);
    expect(statementMimeType('kashf.pdf'), 'application/pdf');
    expect(statementMimeType('s.png'), 'image/png');
    expect(statementMimeType('s.jpg'), 'image/jpeg');
  });

  Future<_Reader> pump(
    WidgetTester tester,
    StatementFile file, {
    Map<String, dynamic>? answer,
    Object? error,
  }) async {
    final reader = _Reader(answer, error: error);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statementReaderProvider.overrideWithValue(reader),
          merchantCategoriesProvider.overrideWithValue(_NoCorrections()),
          signedInUserIdProvider.overrideWithValue(() => 'u1'),
        ],
        child: MaterialApp(home: StatementImportScreen(initialFile: file)),
      ),
    );
    await tester.pumpAndSettle();
    return reader;
  }

  testWidgets('a shared PDF lands in the review; the unbalanced row waits', (
    tester,
  ) async {
    final reader = await pump(tester, (
      name: 'kashf.pdf',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    ), answer: _statement);
    expect(reader.mime, 'application/pdf');
    expect(find.textContaining('مش متطابقة مع رصيد الكشف'), findsOneWidget);
    expect(find.textContaining('في 1 صف ماقدرتش أقراه'), findsOneWidget);
    expect(find.textContaining('مش متطابق مع الصف ده'), findsOneWidget);
    expect(find.text('استيراد 2 معاملة'), findsOneWidget);
  });

  testWidgets('nothing read: the pick step says so', (tester) async {
    await pump(tester, (name: 'shot.png', bytes: Uint8List.fromList(<int>[1])));
    expect(find.textContaining('ما لقيتش حركات'), findsOneWidget);
    expect(find.text('اختيار الكشف'), findsOneWidget);
  });

  testWidgets("out of attempts: the server's own words", (tester) async {
    await pump(
      tester,
      (name: 'shot.jpg', bytes: Uint8List.fromList(<int>[1])),
      error: const FunctionException(
        status: 402,
        details: <String, dynamic>{'message': 'رصيد محاولاتك مايكفيش'},
      ),
    );
    expect(find.text('رصيد محاولاتك مايكفيش'), findsOneWidget);
  });

  testWidgets('a shared CSV still goes to the column mapping', (tester) async {
    final reader = await pump(tester, (
      name: 'export.csv',
      bytes: Uint8List.fromList(
        utf8.encode('date,title,amount\n2026-10-01,A,-5\n'),
      ),
    ));
    expect(reader.mime, isNull, reason: 'a CSV never leaves the phone');
    expect(find.text('متابعة للمراجعة'), findsOneWidget);
  });

  testWidgets('another file type is turned away without a call', (
    tester,
  ) async {
    final reader = await pump(tester, (
      name: 'notes.docx',
      bytes: Uint8List.fromList(<int>[1]),
    ));
    expect(reader.mime, isNull);
    expect(find.textContaining('تعذّرت قراءة الملف'), findsOneWidget);
  });
}
