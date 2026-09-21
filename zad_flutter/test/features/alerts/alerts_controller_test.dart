// The controller registers a token only when it changed, asks for the
// permission once per phone and never again, sends a blocked permission to the
// system settings, and turns a tapped alert into the right tab.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/features/alerts/application/alerts_controller.dart';
import 'package:zad/features/alerts/data/notification_permission.dart';
import 'package:zad/features/alerts/data/push_platform.dart';
import 'package:zad/features/alerts/data/push_registrar.dart';
import 'package:zad/features/alerts/domain/push_alert.dart';

class _Platform extends SilentPushPlatform {
  String? current = 'token-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final StreamController<String> refreshes =
      StreamController<String>.broadcast();
  void Function(AlertDestination?)? opened;

  @override
  Future<void> start({
    required void Function(PushAlert alert) onAlert,
    required void Function(AlertDestination? destination) onOpened,
  }) async => opened = onOpened;

  @override
  Future<String?> token() async => current;

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;
}

class _Permission implements NotificationPermission {
  new(this.now);
  AlertPermission now;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<AlertPermission> status() async => now;

  @override
  Future<AlertPermission> request() async {
    requests++;
    return now = AlertPermission.granted;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

class _Remote implements PushTokenRemote {
  @override
  Future<Map<String, dynamic>> register(String token) async =>
      <String, dynamic>{'ok': true};

  @override
  Future<void> unregister(String token) async {}
}

void main() {
  late Directory dir;
  late Box<String> box;
  late Box<String> device;
  late _Platform platform;
  late _Permission permission;
  late ProviderContainer container;
  late Outbox outbox;
  var run = 0;

  Future<void> build(AlertPermission starting) async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_alerts_test');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('box$run');
    // Its own box, as on the phone: the device flags and the outbox share
    // key names ("push_token").
    device = await Hive.openBox<String>('device$run');
    platform = _Platform();
    permission = _Permission(starting);
    outbox = Outbox(box: box, send: (_) async {});
    final store = ZadLocalStore(
      outbox: box,
      transactions: box,
      documents: box,
      chat: box,
      inventory: box,
      shopping: box,
      pharmacy: box,
      subscriptions: box,
      device: device,
    );
    container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        pushPlatformProvider.overrideWithValue(platform),
        notificationPermissionProvider.overrideWithValue(permission),
        pushRegistrarProvider.overrideWithValue(
          PushRegistrar(
            device: device,
            remote: _Remote.new,
            platform: platform,
            outbox: () => outbox,
          ),
        ),
      ],
    );
  }

  tearDown(() async {
    container.dispose();
    await platform.refreshes.close();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test(
    'start registers the token once, and again only when it changes',
    () async {
      await build(AlertPermission.granted);
      final alerts = container.read(alertsControllerProvider.notifier);

      await alerts.start();
      await alerts.start();
      expect(outbox.entries(), hasLength(1));
      await outbox.flush();

      await alerts.start();
      expect(outbox.entries(), isEmpty, reason: 'same token, nothing to send');

      platform.refreshes.add(
        'token-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      await pumpEventQueue();
      expect(outbox.entries().single.payload['token'], startsWith('token-bbb'));
      expect(
        container.read(alertsControllerProvider).permission,
        AlertPermission.granted,
      );
    },
  );

  test('the prompt is shown once per phone, never again', () async {
    await build(AlertPermission.denied);
    final alerts = container.read(alertsControllerProvider.notifier);

    await alerts.askOnce();
    expect(permission.requests, 1);

    permission.now = AlertPermission.denied;
    await alerts.askOnce();
    expect(permission.requests, 1, reason: 'asked already; settings only now');
  });

  test('already granted: nothing is asked and nothing recorded', () async {
    await build(AlertPermission.granted);
    await container.read(alertsControllerProvider.notifier).askOnce();
    expect(permission.requests, 0);
    expect(device.get(AlertsController.askedKey), isNull);
  });

  test('blocked for good: the button opens the system settings', () async {
    await build(AlertPermission.blocked);
    await container.read(alertsControllerProvider.notifier).enable();
    expect(permission.settingsOpened, 1);
    expect(permission.requests, 0);
  });

  test('a tapped proposals alert opens the confirmations tab', () async {
    await build(AlertPermission.granted);
    await container.read(alertsControllerProvider.notifier).start();

    platform.opened!(AlertDestination.proposals);
    expect(container.read(shellNavigationProvider), ShellTab.proposals);

    container.read(shellNavigationProvider.notifier).shown();
    platform.opened!(null);
    expect(container.read(shellNavigationProvider), isNull);
  });
}
