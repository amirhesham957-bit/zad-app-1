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
  /// app is open; [onOpened] gets where a tapped alert should land.
  Future<void> start({
    required void Function(PushAlert alert) onAlert,
    required void Function(AlertDestination? destination) onOpened,
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
      ),
    ),
    payload: payloadFor(alert.destination),
  );
}

/// Runs in a background isolate for messages that arrive while the app is not
/// in front. Registered in `bootstrap()`; must be top level.
///
/// A message with a notification block has already been shown by FCM; only a
/// data-only one (a voice moment) needs putting on screen here. It is shown as
/// text — speaking it in زاد's voice is not ported.
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
  }) async {
    if (_started) return;
    _started = true;
    final messaging = await _messaging();

    await _initLocal(
      onTap: (response) => onOpened(destinationFor(response.payload)),
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
        onOpened(destinationFor(launch?.notificationResponse?.payload));
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
