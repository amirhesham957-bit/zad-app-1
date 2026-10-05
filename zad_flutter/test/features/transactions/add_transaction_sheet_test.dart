// The manual write, end to end through the form.
//
// The claim: typing an amount and a name puts a row in Hive and an entry in
// the outbox, with no network involved, and the list and the balance both know
// about it before the sheet closes.
//
// The boxes here are in memory, opened with `bytes:` rather than from a temp
// directory, and that is load-bearing. A real disk write inside a testWidgets
// body does not progress against the faked clock: the save never completes and
// the test hangs rather than fails — which cost two runs before the cause was
// found, and `tester.runAsync` does not rescue it, because the pending future
// was created inside the fake zone.
//
// In-memory boxes remove the IO entirely instead of working around it. Do not
// swap these for `Hive.init(tempDir)`.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/transactions/presentation/add_transaction_sheet.dart';
import 'package:zad/shared/budget/data/budget_repository.dart';
import 'package:zad/shared/budget/domain/budget_snapshot.dart';
import 'package:zad/shared/transactions/data/transactions_remote.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';

class _Unreachable implements TransactionsRemote {
  @override
  Future<Map<String, dynamic>?> updateReturning(
    Map<String, dynamic> patch,
  ) async => null;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> exists(String id) async => false;

  int fetches = 0;
  int upserts = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchPeriod({
    required String userId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    fetches++;
    return <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    upserts++;
    return row;
  }
}

class _OfflineBudget implements BudgetRemote {
  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) => Future<Map<String, dynamic>>.error(const SocketException('offline'));
}

Map<String, dynamic> _budgetState() => <String, dynamic>{
  'user_id': 'user-1',
  'currency': 'ج.م',
  'timezone': 'Africa/Cairo',
  'spent': 0,
  'income': 0,
  'committed': 0,
  'days_left': 5,
  'cycle_length_days': 31,
  'threat': 'SAFE',
  'unverified_count': 0,
  'computed_at': '2026-09-20T12:00:00Z',
  'available': 1000,
  'remaining': 1000,
  'opening_balance': 8000,
  'limit_confirmed': true,
  'cycle_start': '2026-08-25',
  'cycle_end': '2026-09-25',
};

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> transactions;
  late Box<String> outboxBox;
  late _Unreachable remote;
  late Outbox outbox;
  late ProviderContainer container;

  final now = DateTime.parse('2026-09-20T12:00:00Z');

  setUpAll(tz_data.initializeTimeZones);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_add_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents', bytes: Uint8List(0));
    transactions = await Hive.openBox<String>(
      'transactions',
      bytes: Uint8List(0),
    );
    outboxBox = await Hive.openBox<String>('outbox', bytes: Uint8List(0));
    remote = _Unreachable();

    await documents.put(
      'budget_state',
      jsonEncode(BudgetSnapshot.fromJson(_budgetState()).toJson()),
    );

    late TransactionsRepository txns;
    outbox = Outbox(
      box: outboxBox,
      send: (e) => txns.sendQueued(e),
      clock: () => now,
    );
    txns = TransactionsRepository(
      cache: transactions,
      remote: remote,
      outbox: () => outbox,
      newId: () => 'txn-${transactions.length + 1}',
      signedInUserId: () => 'user-1',
    );

    container = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(() => now),
        signedInUserIdProvider.overrideWithValue(() => 'user-1'),
        transactionsRepositoryProvider.overrideWithValue(txns),
        budgetRepositoryProvider.overrideWithValue(
          BudgetRepository(
            cache: documents,
            remote: _OfflineBudget(),
            signedInUserId: () => 'user-1',
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    // close, not deleteFromDisk: a memory box has no disk, and asking one to
    // delete itself throws.
    await Hive.close();
    await dir.delete(recursive: true);
  });

  /// Opens the sheet the way the app does.
  ///
  /// Presented as a real modal route rather than as a screen body, because the
  /// form pops itself when it saves. Mounted as a body there is nothing to
  /// pop, the spinner never clears, and pumpAndSettle times out — which reads
  /// as "saving is broken" when it is the harness that is wrong.
  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showAddTransactionSheet(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // Kotlin's order: description, amount, category (expense only).
  Finder titleField() => find.byType(TextField).at(0);
  Finder amountField() => find.byType(TextField).at(1);
  bool chipOn(WidgetTester tester, String label) => tester
      .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
      .selected;
  Finder saveButton([String text = 'خصم المبلغ']) =>
      find.widgetWithText(FilledButton, text);

  /// Taps save and settles. Safe because the boxes are in memory — see the
  /// note at the top of the file.
  Future<void> tapSave(
    WidgetTester tester, [
    String text = 'خصم المبلغ',
  ]) async {
    await tester.tap(saveButton(text));
    await tester.pumpAndSettle();
  }

  testWidgets("Kotlin's sheet: title, the two chips, no category guessed yet", (
    tester,
  ) async {
    await pumpSheet(tester);
    expect(find.text('إضافة مصروف'), findsOneWidget);
    expect(find.text('خصم (مصروف)'), findsOneWidget);
    expect(find.text('إيداع (راتب)'), findsOneWidget);
    // The category is a chip now, not free text (ZAD_LIVING_BRAIN.md §11).
    expect(find.byType(TextField), findsNWidgets(2));
    expect(
      tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .where((c) => c.selected),
      isEmpty,
    );
  });

  testWidgets('the description suggests the category; a tapped chip wins', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(titleField(), 'بنزين العربية');
    await tester.pump();
    expect(chipOn(tester, 'الوقود'), isTrue);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'المواصلات'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'المواصلات'));
    await tester.pump();
    await tester.enterText(titleField(), 'بنزين وزيت');
    await tester.pump();
    expect(chipOn(tester, 'المواصلات'), isTrue, reason: 'the pick held');
    await tester.enterText(amountField(), '300');
    await tapSave(tester);
    expect(outbox.entries().single.payload['category'], 'المواصلات');
  });

  testWidgets('a description that says nothing saves «أخرى», never «عام»', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(titleField(), 'حلاقة');
    await tester.enterText(amountField(), '80');
    await tapSave(tester);
    expect(outbox.entries().single.payload['category'], 'أخرى');
  });

  testWidgets('saving writes to Hive and queues, with no network', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(titleField(), 'قهوة');
    await tester.enterText(amountField(), '125.5');
    await tapSave(tester);

    expect(transactions.length, 1, reason: 'nothing reached the cache');
    final queued = outbox.entries().single;
    expect(queued.kind, OutboxKind.insertTransaction);
    expect(queued.payload['amount'], 125.5);
    expect(queued.payload['title'], 'قهوة');
    expect(queued.payload['category'], 'المطاعم', reason: 'قهوة is a café');
    expect(queued.payload['wallet'], 'card');
    expect(remote.upserts, 0, reason: 'the save pushed to the server inline');
  });

  testWidgets('an Arabic-typed amount saves the same as a Latin one', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(titleField(), 'قهوة');
    await tester.enterText(amountField(), '١٢٥٫٥');
    await tapSave(tester);
    expect(outbox.entries().single.payload['amount'], 125.5);
  });

  testWidgets("an empty description is Kotlin's «بدون وصف»", (tester) async {
    await pumpSheet(tester);
    await tester.enterText(amountField(), '10');
    await tapSave(tester);
    expect(outbox.entries().single.payload['title'], 'بدون وصف');
  });

  testWidgets('income is saved as income under «دخل»', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text('إيداع (راتب)'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة دخل/راتب'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2), reason: 'no category');
    await tester.enterText(titleField(), 'راتب');
    await tester.enterText(amountField(), '5000');
    await tapSave(tester, 'إضافة المبلغ');

    final payload = outbox.entries().single.payload;
    expect(payload['txn_kind'], 'income');
    expect(payload['is_expense'], isFalse);
    expect(payload['amount'], 5000);
    expect(payload['category'], 'دخل');
  });
}
