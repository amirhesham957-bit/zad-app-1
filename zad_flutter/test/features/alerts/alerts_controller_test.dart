// The controller registers a token only when it changed, asks for the
// permission once per phone and never again, sends a blocked permission to the
// system settings, and turns a tapped alert into the right tab.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/features/alerts/application/alerts_controller.dart';
import 'package:zad/features/alerts/data/alert_prefs.dart';
import 'package:zad/features/alerts/data/notification_permission.dart';
import 'package:zad/features/alerts/data/push_platform.dart';
import 'package:zad/features/alerts/data/push_registrar.dart';
import 'package:zad/features/alerts/domain/push_alert.dart';
import 'package:zad/features/chat/application/voice_input_controller.dart';
import 'package:zad/features/proposals/application/proposals_controller.dart';
import 'package:zad/features/proposals/domain/transaction_proposal.dart';
import 'package:zad/features/voice/application/voice_output_controller.dart';
import 'package:zad/features/voice/data/voice_player.dart';
import 'package:zad/features/voice/data/voice_synthesizer.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';

class _Platform extends SilentPushPlatform {
  String? current = 'token-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final StreamController<String> refreshes =
      StreamController<String>.broadcast();
  void Function(PushAlert)? alerted;
  void Function(AlertDestination?)? opened;
  void Function(String, {required bool confirmed})? answered;
  void Function(String, String, {required bool taken})? dosed;
  void Function(String)? spoke;

  @override
  Future<void> start({
    required void Function(PushAlert alert) onAlert,
    required void Function(AlertDestination? destination) onOpened,
    void Function(String proposalId, {required bool confirmed})? onAnswer,
    void Function(String medicineId, String time, {required bool taken})?
    onDose,
    void Function(String speech)? onSpeak,
  }) async {
    alerted = onAlert;
    opened = onOpened;
    answered = onAnswer;
    dosed = onDose;
    spoke = onSpeak;
  }

  @override
  Future<String?> token() async => current;

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;
}

class _Proposals extends ProposalsController {
  final List<(String, ProposalDecision)> decisions =
      <(String, ProposalDecision)>[];

  @override
  ProposalsView build() => const ProposalsView();

  @override
  Future<ProposalOutcome?> decide(
    String proposalId,
    ProposalDecision decision,
  ) async {
    decisions.add((proposalId, decision));
    return null;
  }
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

class _Synth implements VoiceSynthesizer {
  final spoken = <String>[];

  @override
  Future<SpokenAudio> synthesize(String text) async {
    spoken.add(text);
    return (pcm: Uint8List(2), provider: 'gemini');
  }
}

class _SilentPlayer implements VoicePlayer {
  @override
  Future<void> play(Uint8List wav) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _Mic extends VoiceInputController {
  @override
  VoiceInputView build() => const VoiceInputView();
}

void main() {
  late Directory dir;
  late Box<String> box;
  late Box<String> device;
  late _Platform platform;
  late _Permission permission;
  late ProviderContainer container;
  late Outbox outbox;
  late _Synth synth;
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
    synth = _Synth();
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
        proposalsControllerProvider.overrideWith(_Proposals.new),
        notificationPermissionProvider.overrideWithValue(permission),
        voiceSynthesizerProvider.overrideWithValue(synth),
        voicePlayerProvider.overrideWithValue(_SilentPlayer()),
        voiceInputControllerProvider.overrideWith(_Mic.new),
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
    'every start registers the token again — the server may have dropped it',
    () async {
      await build(AlertPermission.granted);
      final alerts = container.read(alertsControllerProvider.notifier);

      await alerts.start();
      await alerts.start();
      expect(outbox.entries(), hasLength(1), reason: 'one entry at a time');
      await outbox.flush();

      await alerts.start();
      expect(
        outbox.entries(),
        hasLength(1),
        reason: 'same token, sent again: its row may be gone on the server',
      );
      await outbox.flush();

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

  test(
    'a button on a bank question answers it and opens the confirmations tab',
    () async {
      await build(AlertPermission.granted);
      await container.read(alertsControllerProvider.notifier).start();
      final proposals =
          container.read(proposalsControllerProvider.notifier) as _Proposals;

      platform.answered!('p-1', confirmed: true);
      await pumpEventQueue();
      platform.answered!('p-2', confirmed: false);
      await pumpEventQueue();

      expect(proposals.decisions, <(String, ProposalDecision)>[
        ('p-1', ProposalDecision.confirm),
        ('p-2', ProposalDecision.reject),
      ]);
      // A follow-up question (duplicate, direction) lands on that tab.
      expect(container.read(shellNavigationProvider), ShellTab.proposals);
    },
  );

  group("a voice moment is said in زاد's voice", () {
    const moment = PushAlert(
      title: 'موعد الدواء',
      body: 'حان موعد كونكور',
      speech: 'يا أمير ميعاد كونكور دلوقتي.',
    );

    test('arriving while the app is open, it is spoken', () async {
      await build(AlertPermission.granted);
      await container.read(alertsControllerProvider.notifier).start();
      platform.alerted!(moment);
      await pumpEventQueue();
      expect(synth.spoken, <String>['يا أمير ميعاد كونكور دلوقتي.']);
    });

    test('«اسمع زاد» on the notification speaks it and opens home', () async {
      await build(AlertPermission.granted);
      await container.read(alertsControllerProvider.notifier).start();
      platform.spoke!('صباح الخير يا أمير.');
      await pumpEventQueue();
      expect(synth.spoken, <String>['صباح الخير يا أمير.']);
    });

    test('with spoken alerts turned off, nothing is said', () async {
      await build(AlertPermission.granted);
      container
          .read(alertPrefsProvider)
          .setEnabled(AlertPrefs.voiceSpokenAlerts, enabled: false);
      await pumpEventQueue();
      await container.read(alertsControllerProvider.notifier).start();
      platform.alerted!(moment);
      await pumpEventQueue();
      expect(synth.spoken, isEmpty);
    });
  });
}
