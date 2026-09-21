// Reading a receipt, and the two things that must not happen afterwards.
//
// The first is the one the Kotlin screen gets wrong today: `receiptType ==
// "budget_card"` means the photograph is a balance or salary notice, so its
// `total` is money the customer *has*. Kotlin lets that fall through to the
// generic branch and records it as an expense — wrong amount, wrong direction,
// and the budget moves against itself. Here it is refused outright and offered
// as the ceiling instead.
//
// The second is quieter. `category` is written into `zad_transactions.category`
// and every breakdown in the product buckets by exact string match, so a value
// outside the eleven becomes an orphan bucket that no screen adds up. The
// server clamps, and the client does not trust it to.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/data/receipt_scanner.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';
import 'package:zad/features/settings/data/settings_repository.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

class _FakeCamera implements ReceiptCamera {
  Uint8List? image = Uint8List.fromList(<int>[1, 2, 3]);
  ReceiptImageSource? asked;

  @override
  Future<Uint8List?> capture(ReceiptImageSource source) async {
    asked = source;
    return image;
  }
}

class _FakeScanner implements ReceiptScanner {
  Map<String, dynamic> answer = _receipt();
  Exception? failWith;
  int calls = 0;

  @override
  Future<ScannedReceipt> scan({
    required String userId,
    required Uint8List image,
  }) async {
    calls++;
    if (failWith case final e?) throw e;
    return ScannedReceipt.fromJson(answer);
  }
}

class _OfflineBudget implements BudgetRemote {
  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) => Future<Map<String, dynamic>>.error(const SocketException('offline'));
}

class _NoTransactions implements TransactionsRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchPeriod({
    required String userId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async => <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;
}

class _FakeSettingsRemote implements SettingsRemote {
  Map<String, dynamic>? row = <String, dynamic>{};

  @override
  Future<Map<String, dynamic>?> fetch({required String userId}) async => row;

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> sent,
  ) async {
    final next = <String, dynamic>{...?row};
    for (final entry in sent.entries) {
      if (entry.key == 'id') continue;
      next[entry.key] = entry.value;
    }
    row = next;
    return next;
  }
}

/// The shape `analyze_receipt` answers with.
Map<String, dynamic> _receipt({
  double total = 248.75,
  String category = 'البقالة',
  String storeName = 'بنده',
  String receiptType = 'grocery',
  List<Object?>? items,
}) => <String, dynamic>{
  'total': total,
  'category': category,
  'storeName': storeName,
  'receiptType': receiptType,
  'items':
      items ??
      <Object?>[
        <String, dynamic>{
          'name': 'لبن',
          'price': 12.5,
          'quantity': 2.0,
          'unit': 'لتر',
          'category': 'ألبان',
        },
      ],
};

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> transactions;
  late Box<String> outboxBox;
  late _FakeCamera camera;
  late _FakeScanner scanner;

  final now = DateTime.parse('2026-09-20T09:00:00Z');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_scan_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents');
    transactions = await Hive.openBox<String>('transactions');
    outboxBox = await Hive.openBox<String>('outbox');
    camera = _FakeCamera();
    scanner = _FakeScanner();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  ProviderContainer containerWith() {
    late TransactionsRepository txns;
    late SettingsRepository settings;

    // Dispatched on kind, exactly as `outboxProvider` does. A harness that
    // sent everything to the transactions repository would hand a settings
    // payload to the wrong sender, and the failure would look like a bug in
    // the code under test.
    final outbox = Outbox(
      box: outboxBox,
      send: (entry) async => switch (entry.kind) {
        OutboxKind.insertTransaction => await txns.sendQueued(entry),
        OutboxKind.updateAccountSettings => await settings.sendQueued(entry),
        _ => throw StateError('no sender for "${entry.kind}"'),
      },
      clock: () => now,
    );
    txns = TransactionsRepository(
      cache: transactions,
      remote: _NoTransactions(),
      outbox: () => outbox,
      newId: () => 'txn-1',
      signedInUserId: () => 'user-1',
    );
    settings = SettingsRepository(
      cache: documents,
      remote: _FakeSettingsRemote(),
      outbox: () => outbox,
      signedInUserId: () => 'user-1',
      now: () => now,
    );

    return ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: outboxBox,
            transactions: transactions,
            documents: documents,
            chat: documents,
            inventory: documents,
            shopping: documents,
            pharmacy: documents,
            subscriptions: documents,
            device: documents,
          ),
        ),
        nowProvider.overrideWithValue(() => now),
        outboxProvider.overrideWithValue(outbox),
        signedInUserIdProvider.overrideWithValue(() => 'user-1'),
        transactionsRepositoryProvider.overrideWithValue(txns),
        settingsRepositoryProvider.overrideWithValue(settings),
        receiptCameraProvider.overrideWithValue(camera),
        receiptScannerProvider.overrideWithValue(scanner),
        budgetRepositoryProvider.overrideWithValue(
          BudgetRepository(
            cache: documents,
            remote: _OfflineBudget(),
            signedInUserId: () => 'user-1',
          ),
        ),
      ],
    );
  }

  List<ZadTransaction> recorded(ProviderContainer c) =>
      c.read(transactionsRepositoryProvider).allCached();

  group('reading the response', () {
    test('parses the shape the action answers with', () {
      final receipt = ScannedReceipt.fromJson(_receipt());

      expect(receipt.total, 248.75);
      expect(receipt.category, 'البقالة');
      expect(receipt.storeName, 'بنده');
      expect(receipt.type, ReceiptType.grocery);
      expect(receipt.items.single.name, 'لبن');
      expect(receipt.items.single.unit, 'لتر');
    });

    test('drops a line with no name rather than showing a blank row', () {
      final receipt = ScannedReceipt.fromJson(
        _receipt(
          items: <Object?>[
            <String, dynamic>{'name': '', 'price': 5.0},
            <String, dynamic>{'price': 7.0},
            <String, dynamic>{'name': 'عيش', 'price': 3.0},
          ],
        ),
      );

      expect(receipt.items.single.name, 'عيش');
    });

    test('an unknown receiptType is grocery, never budget_card', () {
      // budget_card changes what the sheet offers to do. It must be reached
      // only when the server actually said so.
      expect(ReceiptType.fromWire('something_new'), ReceiptType.grocery);
      expect(ReceiptType.fromWire(null), ReceiptType.grocery);
      expect(ReceiptType.fromWire('budget_card'), ReceiptType.budgetCard);
    });

    test('the empty answer is not usable', () {
      // This is exactly what the action returns when the image was unreadable
      // or the model said nothing, and it is indistinguishable from a real
      // failure in its shape.
      final receipt = ScannedReceipt.fromJson(<String, dynamic>{
        'total': 0,
        'category': '',
        'storeName': '',
        'receiptType': 'grocery',
        'items': <Object?>[],
      });

      expect(receipt.isUsable, isFalse);
    });
  });

  group('scanning', () {
    test('a good read leaves a reading waiting to be confirmed', () async {
      final container = containerWith();
      addTearDown(container.dispose);

      await container
          .read(scanControllerProvider.notifier)
          .scan(ReceiptImageSource.camera);

      final view = container.read(scanControllerProvider);
      expect(view.stage, ScanStage.ready);
      expect(view.receipt?.storeName, 'بنده');
      expect(camera.asked, ReceiptImageSource.camera);
      // Nothing written. The reading is a proposal, not a transaction.
      expect(recorded(container), isEmpty);
    });

    test('backing out of the picker is not a failure', () async {
      camera.image = null;
      final container = containerWith();
      addTearDown(container.dispose);

      await container
          .read(scanControllerProvider.notifier)
          .scan(ReceiptImageSource.gallery);

      expect(container.read(scanControllerProvider).stage, ScanStage.idle);
      expect(scanner.calls, 0);
    });

    test('a read that found nothing is unreadable, not failed', () async {
      // Different words for different fixes: this one is solved by a steadier
      // photograph, and retrying the same image would not help.
      scanner.answer = _receipt(total: 0, items: <Object?>[]);
      final container = containerWith();
      addTearDown(container.dispose);

      await container
          .read(scanControllerProvider.notifier)
          .scan(ReceiptImageSource.camera);

      expect(
        container.read(scanControllerProvider).stage,
        ScanStage.unreadable,
      );
      expect(container.read(scanControllerProvider).receipt, isNull);
    });

    test('a transport failure is failed, and keeps the error', () async {
      scanner.failWith = const SocketException('offline');
      final container = containerWith();
      addTearDown(container.dispose);

      await container
          .read(scanControllerProvider.notifier)
          .scan(ReceiptImageSource.camera);

      final view = container.read(scanControllerProvider);
      expect(view.stage, ScanStage.failed);
      expect(view.error, isNotNull);
    });
  });

  group('saving a purchase', () {
    test('records an expense through the outbox', () async {
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(scanControllerProvider.notifier);

      await controller.scan(ReceiptImageSource.camera);
      expect(await controller.saveAsTransaction(), isTrue);

      final txn = recorded(container).single;
      expect(txn.amount, 248.75);
      expect(txn.isExpense, isTrue);
      expect(txn.title, 'بنده');
      expect(txn.category, 'البقالة');
      expect(txn.isPending, isTrue, reason: 'it goes out through the queue');
      expect(container.read(scanControllerProvider).stage, ScanStage.idle);
    });

    test('a correction is what gets saved, not what was read', () async {
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(scanControllerProvider.notifier);

      await controller.scan(ReceiptImageSource.camera);
      controller.correct(total: 300, category: 'المطاعم');
      await controller.saveAsTransaction();

      final txn = recorded(container).single;
      expect(txn.amount, 300);
      expect(txn.category, 'المطاعم');
    });

    test('a category outside the eleven is dropped, not written', () async {
      // The server clamps this, and got it wrong once anyway — a supermarket
      // receipt came back "مواليد" on 2026-08-15. Writing it would put the
      // spend in a bucket no breakdown in the app adds up.
      scanner.answer = _receipt(category: 'مواليد');
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(scanControllerProvider.notifier);

      await controller.scan(ReceiptImageSource.camera);
      await controller.saveAsTransaction();

      expect(recorded(container).single.category, isNull);
    });

    test('a receipt with no total cannot be saved', () async {
      scanner.answer = _receipt(total: 0);
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(scanControllerProvider.notifier);

      await controller.scan(ReceiptImageSource.camera);
      // It read an item, so it is usable and on screen — but there is no
      // figure to record.
      expect(container.read(scanControllerProvider).stage, ScanStage.ready);
      expect(await controller.saveAsTransaction(), isFalse);
      expect(recorded(container), isEmpty);
    });
  });

  group('a balance card is not a purchase', () {
    test('refuses to record it as an expense', () async {
      scanner.answer = _receipt(
        receiptType: 'budget_card',
        total: 9000,
        storeName: '',
        items: <Object?>[],
      );
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(scanControllerProvider.notifier);

      await controller.scan(ReceiptImageSource.camera);
      expect(
        container.read(scanControllerProvider).receipt?.type,
        ReceiptType.budgetCard,
      );

      // The bug this exists to prevent: a salary notice becoming a 9,000
      // expense.
      expect(await controller.saveAsTransaction(), isFalse);
      expect(recorded(container), isEmpty);
    });

    test('offers the figure as the cycle ceiling instead', () async {
      scanner.answer = _receipt(
        receiptType: 'budget_card',
        total: 9000,
        items: <Object?>[],
      );
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(scanControllerProvider.notifier);

      await controller.scan(ReceiptImageSource.camera);
      expect(await controller.useAsMonthlyLimit(), isTrue);

      expect(
        container.read(settingsRepositoryProvider).cached()?.monthlyLimit,
        9000,
      );
      expect(recorded(container), isEmpty);
    });
  });
}
