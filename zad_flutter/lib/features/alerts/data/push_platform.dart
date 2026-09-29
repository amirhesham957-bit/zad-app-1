/// The phone's side of alerts: FCM for what zad-brain pushes, local
/// notifications for what FCM will not show by itself.
///
/// Behind an interface because Firebase is a platform plugin that no unit or
/// widget test has. `bootstrap()` installs [FirebasePushPlatform]; everything
/// else — every test, and a build without Firebase config — gets
/// [SilentPushPlatform], which does nothing and says so.
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:zad/features/alerts/domain/push_alert.dart';

/// The channel alerts arrive on. Kotlin's id, so an alert is the same channel
/// — and the same sound and importance setting — whichever client is
/// installed.
const String kAlertChannelId = 'zad_agent_channel';

/// What the app needs from the platform.
abstract interface class PushPlatform {
  /// Starts listening. [onAlert] gets every message that arrives while the
  /// app is open; [onOpened] gets where a tapped alert should land;
  /// [onAnswer] gets a bank confirmation settled from a notification button;
  /// [onDose] a dose reminder's «أخدتها» (taken) or «أجّل» (not taken);
  /// [onSpeak] a voice moment's «اسمع زاد».
  Future<void> start({
    required void Function(PushAlert alert) onAlert,
    required void Function(AlertDestination? destination) onOpened,
    void Function(String proposalId, {required bool confirmed})? onAnswer,
    void Function(String medicineId, String time, {required bool taken})?
    onDose,
    void Function(String speech)? onSpeak,
  });

  /// This device's push token, or null when there is none to have.
  Future<String?> token();

  /// New tokens, when FCM rotates one.
  Stream<String> get tokenRefreshes;

  /// Puts [alert] on screen as a notification.
  Future<void> show(PushAlert alert);

  /// Invalidates this device's token at FCM, so nothing pushed to it arrives.
  Future<void> deleteToken();
}

/// No push at all: tests, and a build that could not start Firebase.
class SilentPushPlatform implements PushPlatform {
  /// Creates the platform.
  const new();

  @override
  Future<void> start({
    required void Function(PushAlert alert) onAlert,
    required void Function(AlertDestination? destination) onOpened,
    void Function(String proposalId, {required bool confirmed})? onAnswer,
    void Function(String medicineId, String time, {required bool taken})?
    onDose,
    void Function(String speech)? onSpeak,
  }) async {}

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream<String>.empty();

  @override
  Future<void> show(PushAlert alert) async {}

  @override
  Future<void> deleteToken() async {}
}

final FlutterLocalNotificationsPlugin _local =
    FlutterLocalNotificationsPlugin();

/// The one plugin instance — the local reminders schedule on it too, so a
/// tap on one of them is routed by the same callback as a tap on a push.
FlutterLocalNotificationsPlugin get zadLocalNotifications => _local;

const String _channelName = 'تنبيهات زاد';
const String _channelDescription = 'تنبيهات استباقية من مساعد زاد';

Future<void> _initLocal({DidReceiveNotificationResponseCallback? onTap}) async {
  await _local.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_zad'),
    ),
    onDidReceiveNotificationResponse: onTap,
  );
  await _local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          kAlertChannelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
}

Future<void> _showLocal(PushAlert alert) async {
  if (!alert.isShowable) return;
  await _local.show(
    // Unique per alert, so a second one does not replace the first.
    id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
    title: alert.title,
    body: alert.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        kAlertChannelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_zad',
        // The whole text, not one truncated line: an alert is usually a
        // sentence or two about money.
        styleInformation: BigTextStyleInformation(alert.body),
        // A bank question carries its two answers. showsUserInterface: the
        // decision needs the signed-in session, which lives in the app, so a
        // press brings the app up and settles it there (AlertsController).
        actions: alert.speech != null
            ? const <AndroidNotificationAction>[
                // Speaking needs the app's player, so the press brings the
                // app up and زاد says it there (AlertsController).
                AndroidNotificationAction(
                  kListenActionId,
                  '🔊 اسمع زاد',
                  showsUserInterface: true,
                ),
              ]
            : alert.proposalId == null
            ? null
            : const <AndroidNotificationAction>[
                AndroidNotificationAction(
                  kConfirmActionId,
                  'أيوه، أنا',
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  kRejectActionId,
                  'مش أنا',
                  showsUserInterface: true,
                ),
              ],
      ),
    ),
    payload: alert.speech != null
        ? speakPayload(alert.speech!)
        : alert.proposalId == null
        ? payloadFor(alert.destination)
        : proposalPayload(alert.proposalId!),
  );
}

/// Shows [alert] from an engine with no [PushPlatform] started — the headless
/// run street alerts use when the app is closed.
Future<void> showAlertInBackground(PushAlert alert) async {
  await _initLocal();
  await _showLocal(alert);
}

/// Routes a tapped notification: a button on a bank question, a dose reminder
/// or a voice moment answers it, any other tap opens where the notification
/// points.
void routeNotificationResponse({
  required String? actionId,
  required String? payload,
  required void Function(AlertDestination? destination) onOpened,
  void Function(String proposalId, {required bool confirmed})? onAnswer,
  void Function(String medicineId, String time, {required bool taken})? onDose,
  void Function(String speech)? onSpeak,
}) {
  final proposal = proposalIdFromPayload(payload);
  final confirmed = confirmationFromAction(actionId);
  if (proposal != null && confirmed != null && onAnswer != null) {
    onAnswer(proposal, confirmed: confirmed);
    return;
  }
  final dose = doseFromPayload(payload);
  final taken = doseAnswerFromAction(actionId);
  if (dose != null && taken != null && onDose != null) {
    onDose(dose.medicineId, dose.time, taken: taken);
    return;
  }
  final speech = speechFromPayload(payload);
  if (speech != null) {
    if (actionId == kListenActionId && onSpeak != null) onSpeak(speech);
    onOpened(AlertDestination.home);
    return;
  }
  onOpened(destinationForPayload(payload));
}

/// Runs in a background isolate for messages that arrive while the app is not
/// in front. Registered in `bootstrap()`; must be top level.
///
/// A message with a notification block has already been shown by FCM; only a
/// data-only one (a voice moment) needs putting on screen here. It carries
/// «🔊 اسمع زاد»; a press brings the app up and زاد says it.
@pragma('vm:entry-point')
Future<void> zadBackgroundMessage(RemoteMessage message) async {
  if (!shouldShowLocally(
    hasNotificationBlock: message.notification != null,
    inForeground: false,
  )) {
    return;
  }
  await Firebase.initializeApp();
  await _initLocal();
  await _showLocal(PushAlert.fromMessage(data: message.data));
}

/// The real thing.
///
/// Firebase is started on the first call rather than in `bootstrap()`: it is
/// not needed to draw the first frame, and everything here waits for it.
class FirebasePushPlatform implements PushPlatform {
  /// Creates the platform. Touches nothing until used.
  new();

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  bool _started = false;
  Future<FirebaseMessaging>? _ready;

  Future<FirebaseMessaging> _messaging() => _ready ??= () async {
    await Firebase.initializeApp();
    // Registered once Firebase is up; Android keeps the handle, so it also
    // runs for pushes that arrive while the app is not running.
    FirebaseMessaging.onBackgroundMessage(zadBackgroundMessage);
    return FirebaseMessaging.instance;
  }();

  @override
  Future<void> start({
    required void Function(PushAlert alert) onAlert,
    required void Function(AlertDestination? destination) onOpened,
    void Function(String proposalId, {required bool confirmed})? onAnswer,
    void Function(String medicineId, String time, {required bool taken})?
    onDose,
    void Function(String speech)? onSpeak,
  }) async {
    if (_started) return;
    _started = true;
    final messaging = await _messaging();

    await _initLocal(
      onTap: (response) => routeNotificationResponse(
        actionId: response.actionId,
        payload: response.payload,
        onOpened: onOpened,
        onAnswer: onAnswer,
        onDose: onDose,
        onSpeak: onSpeak,
      ),
    );

    _subscriptions
      ..add(
        FirebaseMessaging.onMessage.listen((m) {
          final alert = PushAlert.fromMessage(
            data: m.data,
            notificationTitle: m.notification?.title,
            notificationBody: m.notification?.body,
          );
          onAlert(alert);
          // FCM shows nothing while the app is open.
          unawaited(_showLocal(alert));
        }),
      )
      ..add(
        FirebaseMessaging.onMessageOpenedApp.listen(
          (m) => onOpened(destinationFor(m.data['route'] as String?)),
        ),
      );

    // Opened from a push, or from one of our own notifications, while the app
    // was not running at all.
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      onOpened(destinationFor(initial.data['route'] as String?));
    } else {
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        routeNotificationResponse(
          actionId: launch?.notificationResponse?.actionId,
          payload: launch?.notificationResponse?.payload,
          onOpened: onOpened,
          onAnswer: onAnswer,
          onDose: onDose,
          onSpeak: onSpeak,
        );
      }
    }
  }

  @override
  Future<String?> token() async => await (await _messaging()).getToken();

  @override
  Stream<String> get tokenRefreshes =>
      Stream<FirebaseMessaging>.fromFuture(_messaging())
          .asyncExpand((m) => m.onTokenRefresh);

  @override
  Future<void> show(PushAlert alert) => _showLocal(alert);

  @override
  Future<void> deleteToken() async => await (await _messaging()).deleteToken();
}
