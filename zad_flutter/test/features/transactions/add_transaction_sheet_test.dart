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
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';
import 'package:zad/features/transactions/presentation/add_transaction_sheet.dart';

class _Unreachable implements TransactionsRemote {
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

  Finder amountField() => find.byType(TextField).first;
  Finder titleField() => find.byType(TextField).at(1);
  Finder saveButton() => find.widgetWithText(FilledButton, 'احفظ');

  /// Taps save and settles. Safe because the boxes are in memory — see the
  /// note at the top of the file.
  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
  }

  testWidgets('save is refused until there is an amount and a name', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);

    await tester.enterText(amountField(), '50');
    await tester.pump();
    // Amount alone is not enough: an unnamed row is one nobody can recognise
    // in the list a week later.
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);

    await tester.enterText(titleField(), 'قهوة');
    await tester.pump();
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
  });

  testWidgets('saving writes to Hive and queues, with no network', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.enterText(amountField(), '125.5');
    await tester.enterText(titleField(), 'قهوة');
    await tester.pump();
    await tapSave(tester);

    expect(transactions.length, 1, reason: 'nothing reached the cache');
    final queued = outbox.entries().single;
    expect(queued.kind, OutboxKind.insertTransaction);
    expect(queued.payload['amount'], 125.5);
    expect(queued.payload['title'], 'قهوة');
    // Counted as upserts, not as every call: saving refreshes the list, and
    // that read is a background fetch the form did not wait for. What must not
    // happen is the *write* going out before the sheet returns.
    expect(remote.upserts, 0, reason: 'the save pushed to the server inline');
  });

  testWidgets('an Arabic-typed amount saves the same as a Latin one', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.enterText(amountField(), '١٢٥٫٥');
    await tester.enterText(titleField(), 'قهوة');
    await tester.pump();
    await tapSave(tester);

    expect(outbox.entries().single.payload['amount'], 125.5);
  });

  testWidgets('a transfer never offers the wallet it is leaving', (
    tester,
  ) async {
    // The domain throws on a transfer to the same wallet. Not offering it is
    // what keeps that unreachable from the UI.
    await pumpSheet(tester);

    await tester.tap(find.text('تحويل'));
    await tester.pumpAndSettle();

    // "من" offers all three; "إلى" offers the two that are left.
    expect(find.widgetWithText(ChoiceChip, 'كاش'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'بطاقة'), findsNWidgets(2));
    expect(find.widgetWithText(ChoiceChip, 'بنك'), findsNWidgets(2));
  });

  testWidgets('a transfer saves with its target and does not count as spend', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.text('تحويل'));
    await tester.pumpAndSettle();
    await tester.enterText(amountField(), '200');
    await tester.enterText(titleField(), 'من الكاش للبنك');
    await tester.pump();
    await tapSave(tester);

    final payload = outbox.entries().single.payload;
    expect(payload['txn_kind'], 'transfer');
    expect(payload['transfer_to'], isNotNull);
    expect(payload['transfer_to'], isNot(payload['wallet']));
    // Moving money is not spending it.
    expect(payload['counts_toward_budget'], isFalse);
  });

  testWidgets('income is saved as income, not as a negative expense', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.text('دخل'));
    await tester.pumpAndSettle();
    await tester.enterText(amountField(), '5000');
    await tester.enterText(titleField(), 'راتب');
    await tester.pump();
    await tapSave(tester);

    final payload = outbox.entries().single.payload;
    expect(payload['txn_kind'], 'income');
    expect(payload['is_expense'], isFalse);
    expect(payload['amount'], 5000);
  });
}
