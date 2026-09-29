/// The phone's alerts: permission, the device token, and what an alert does
/// when it arrives or is tapped.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/alerts/data/alert_prefs.dart';
import 'package:zad/features/alerts/data/notification_permission.dart';
import 'package:zad/features/alerts/domain/push_alert.dart';
import 'package:zad/features/insights/application/insights_controller.dart';
import 'package:zad/features/notifications/application/notifications_controller.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/features/pharmacy/domain/dose_slot.dart';
import 'package:zad/features/proposals/application/proposals_controller.dart';
import 'package:zad/features/proposals/domain/transaction_proposal.dart';
import 'package:zad/features/voice/application/voice_output_controller.dart';

/// What the settings row shows.
class AlertsView {
  /// Creates a view.
  const new({this.permission = AlertPermission.unknown});

  /// Whether alerts can be shown.
  final AlertPermission permission;
}

/// Holds the alerts.
class AlertsController extends Notifier<AlertsView> {
  StreamSubscription<String>? _refreshes;

  /// The device flag for "the system prompt has been shown once". Asked once,
  /// right after sign-in; after that, only from settings — never nagged.
  static const String askedKey = 'asked_notification_permission';

  @override
  AlertsView build() {
    ref.onDispose(() => _refreshes?.cancel());
    return const AlertsView();
  }

  /// Starts alerts for the signed-in account. Called by the shell, which only
  /// exists while somebody is signed in. Safe to call more than once.
  Future<void> start() async {
    final platform = ref.read(pushPlatformProvider);
    await platform.start(
      onAlert: _arrived,
      onOpened: _opened,
      onAnswer: _answered,
      onDose: _doseAnswered,
      onSpeak: _speak,
    );

    final registrar = ref.read(pushRegistrarProvider);
    _refreshes ??= platform.tokenRefreshes.listen(
      (t) => unawaited(registrar.register(t)),
    );
    try {
      // Every start, not only when the token changed: the server drops a row
      // on its own (zad-brain deletes a token FCM refuses), and the phone
      // cannot see that. 2026-09-29 the owner's token was registered at 19:06
      // and gone by 21:48 while this device still held it, so nothing was
      // ever sent again. The RPC is an upsert and the outbox holds one entry.
      final token = await platform.token();
      if (token != null) await registrar.register(token);
    } on Object {
      // No token without Play services or a network; the next start asks
      // again, and a rotation arrives through the stream above.
    }
    await refreshPermission();
  }

  /// Reads where the permission stands.
  Future<void> refreshPermission() async {
    final status = await ref.read(notificationPermissionProvider).status();
    if (ref.mounted) state = AlertsView(permission: status);
  }

  /// Shows the system prompt once per device, the first time it could help.
  Future<void> askOnce() async {
    final device = ref.read(localStoreProvider).device;
    if (device.get(askedKey) != null) return;
    final permission = ref.read(notificationPermissionProvider);
    if (await permission.status() != AlertPermission.denied) return;
    await device.put(askedKey, DateTime.now().toUtc().toIso8601String());
    final after = await permission.request();
    if (ref.mounted) state = AlertsView(permission: after);
  }

  /// The settings row's button: the prompt when Android will still show it,
  /// the system settings when it will not.
  Future<void> enable() async {
    final permission = ref.read(notificationPermissionProvider);
    final now = await permission.status();
    if (now == AlertPermission.blocked) {
      await permission.openSettings();
      return;
    }
    final after = await permission.request();
    if (ref.mounted) state = AlertsView(permission: after);
  }

  /// A voice moment — a dose, an appointment, the morning greeting — said
  /// in زاد's voice, unless «النطق الصوتي للإشعارات والجرعات» is off. Kotlin's
  /// VoiceMomentSpeaker: on by default (the owner's «تتكلم لوحدها»).
  void _speak(String speech) {
    if (!ref
        .read(alertPrefsProvider)
        .isEnabledUnlessOff(AlertPrefs.voiceSpokenAlerts)) {
      return;
    }
    unawaited(ref.read(voiceOutputControllerProvider.notifier).speak(speech));
  }

  /// The device flag for the last morning the greeting was asked for.
  static const String morningKey = 'morning_greeting_asked';

  /// Kotlin's wake greeting: the first open of the morning asks zad-brain for
  /// «صباح الخير» (`moment_event`), which composes it from the day's doses,
  /// appointments and budget and pushes it back — spoken by [_arrived] while
  /// the app is open. Best effort; never throws.
  Future<void> greetMorning() async {
    try {
      final zone = tz.getLocation(ref.read(accountTimeZoneProvider));
      final local = tz.TZDateTime.from(ref.read(nowProvider)(), zone);
      final device = ref.read(localStoreProvider).device;
      if (!shouldAskMorningGreeting(
        local: local,
        lastAskedDate: device.get(morningKey),
      )) {
        return;
      }
      await device.put(morningKey, morningDateKey(local));
      await ref
          .read(supabaseClientProvider)
          .functions
          .invoke(
            'zad-brain',
            body: const <String, dynamic>{
              'action': 'moment_event',
              'moment': 'morning_greeting',
            },
          );
    } on Object {
      // No network or no session: tomorrow morning asks again.
    }
  }

  void _arrived(PushAlert alert) {
    // Open in front of the customer: say it now, as Kotlin did with the
    // screen on. In the background the notification carries «اسمع زاد».
    if (alert.speech case final speech?) _speak(speech);
    // What arrived is also on the server; the lists that show it look again.
    unawaited(
      ref
          .read(notificationsControllerProvider.notifier)
          .refresh(force: true)
          .then((_) {}, onError: (Object _) {}),
    );
    unawaited(
      ref
          .read(insightsControllerProvider.notifier)
          .refresh(force: true)
          .then((_) {}, onError: (Object _) {}),
    );
    if (alert.destination == AlertDestination.proposals) {
      ref.invalidate(proposalsControllerProvider);
    }
  }

  void _opened(AlertDestination? destination) {
    switch (destination) {
      case AlertDestination.proposals:
        ref.invalidate(proposalsControllerProvider);
        ref.read(shellNavigationProvider.notifier).open(ShellTab.proposals);
      case AlertDestination.pharmacy:
        ref.read(shellNavigationProvider.notifier).open(ShellTab.household);
      case AlertDestination.home:
        ref.read(shellNavigationProvider.notifier).open(ShellTab.home);
      case AlertDestination.family:
        ref.read(shellNavigationProvider.notifier).open(ShellTab.family);
      case null:
        break;
    }
  }

  /// «أخدتها» / «أجّل» pressed on a dose reminder. The pharmacy opens too,
  /// so the customer sees the dose ticked (or put off) and anything else due.
  Future<void> _doseAnswered(
    String medicineId,
    String time, {
    required bool taken,
  }) async {
    ref.read(shellNavigationProvider.notifier).open(ShellTab.household);
    final pharmacy = ref.read(pharmacyControllerProvider.notifier);
    // A press may have started the app: today's slots are not read yet.
    if (ref.read(pharmacyControllerProvider).today.isEmpty) {
      await pharmacy.refresh();
    }
    if (!ref.mounted) return;
    final slot = slotForDoseAnswer(
      ref.read(pharmacyControllerProvider).today,
      medicineId: medicineId,
      time: time,
      now: ref.read(nowProvider)(),
    );
    if (slot == null) return;
    await (taken ? pharmacy.take(slot) : pharmacy.snooze(slot));
  }

  /// «أيوه، أنا» / «مش أنا» pressed on a bank question in the notification.
  ///
  /// The confirmations tab opens as well: the server may ask back (a
  /// suspected duplicate, a direction it needs), and that follow-up is a card
  /// on that tab — answering from the shade must never swallow it.
  Future<void> _answered(String proposalId, {required bool confirmed}) async {
    ref.read(shellNavigationProvider.notifier).open(ShellTab.proposals);
    await ref
        .read(proposalsControllerProvider.notifier)
        .decide(
          proposalId,
          confirmed ? ProposalDecision.confirm : ProposalDecision.reject,
        );
  }
}

/// The alerts.
final alertsControllerProvider = NotifierProvider<AlertsController, AlertsView>(
  AlertsController.new,
);
