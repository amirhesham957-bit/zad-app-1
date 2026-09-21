// Three states, not two.
//
// "Granted" and "working" are different things, and the gap between them is
// what left an ingest table empty for weeks with the permission switched on.
// A reading that cannot express the middle state cannot report that failure.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/bank/application/bank_access_controller.dart';
import 'package:zad_bank_listener/zad_bank_listener.dart';

class _FakeListener implements ZadBankListener {
  new({this.granted = true, this.pending = 0});

  bool granted;
  int pending;
  Exception? failWith;
  int rebinds = 0;
  int settingsOpened = 0;

  @override
  Future<bool> isPermissionGranted() async {
    if (failWith case final e?) throw e;
    return granted;
  }

  @override
  Future<bool> requestRebind() async {
    rebinds++;
    return granted;
  }

  @override
  Future<int> pendingCount() async => pending;

  @override
  Future<void> openPermissionSettings() async => settingsOpened++;

  @override
  Future<List<CapturedNotification>> peek({int limit = 100}) async =>
      const <CapturedNotification>[];

  @override
  Future<void> acknowledge(Iterable<int> ids) async {}
}

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> chatBox;
  late _FakeListener listener;
  late ProviderContainer container;

  Future<void> build({bool granted = true, int pending = 0}) async {
    listener = _FakeListener(granted: granted, pending: pending);
    container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: documents,
            transactions: documents,
            documents: documents,
            chat: chatBox,
            inventory: chatBox,
            shopping: chatBox,
            pharmacy: chatBox,
          ),
        ),
        bankListenerProvider.overrideWithValue(listener),
      ],
    );
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_access_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents');
    chatBox = await Hive.openBox<String>('chat');
  });

  tearDown(() async {
    container.dispose();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('not granted is not granted', () async {
    await build(granted: false);
    await container.read(bankAccessControllerProvider.notifier).refresh();

    expect(
      container.read(bankAccessControllerProvider).health,
      BankAccessHealth.notGranted,
    );
  });

  test('granted with nothing ever captured is reported, not hidden', () async {
    // The signature of a service Android never bound. A UI that only read the
    // permission would call this working.
    await build();
    await container.read(bankAccessControllerProvider.notifier).refresh();

    expect(
      container.read(bankAccessControllerProvider).health,
      BankAccessHealth.grantedButSilent,
    );
  });

  test('granted with something waiting is flowing', () async {
    await build(pending: 3);
    await container.read(bankAccessControllerProvider.notifier).refresh();

    expect(
      container.read(bankAccessControllerProvider).health,
      BankAccessHealth.flowing,
    );
  });

  test('a past capture counts, even with the inbox empty now', () async {
    await build();
    await container
        .read(bankCaptureMarkerProvider)
        .sawCapture(DateTime.utc(2026, 9, 20));
    await container.read(bankAccessControllerProvider.notifier).refresh();

    // Nothing pending because the drain already emptied it — that is health,
    // not silence.
    expect(
      container.read(bankAccessControllerProvider).health,
      BankAccessHealth.flowing,
    );
  });

  test('every check asks Android to rebind', () async {
    // A no-op when the service is already bound, and the only thing that fixes
    // it when it is not. Cheap enough to do unconditionally.
    //
    // Counted as "at least once" rather than exactly once on purpose: building
    // the controller kicks its own refresh, so a screen opening already costs
    // one. That is the intent — the repair should happen without anyone asking
    // for it.
    await build();
    await container.read(bankAccessControllerProvider.notifier).refresh();
    expect(listener.rebinds, greaterThanOrEqualTo(1));
  });

  test('it does not ask to rebind what was never granted', () async {
    await build(granted: false);
    await container.read(bankAccessControllerProvider.notifier).refresh();
    expect(listener.rebinds, 0);
  });

  test('a missing plugin reads as not granted, not as a crash', () async {
    await build();
    listener.failWith = MissingPluginException('no implementation');
    await container.read(bankAccessControllerProvider.notifier).refresh();

    expect(
      container.read(bankAccessControllerProvider).health,
      BankAccessHealth.notGranted,
    );
  });
}
