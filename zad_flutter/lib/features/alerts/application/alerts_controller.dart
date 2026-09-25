/// The phone's alerts: permission, the device token, and what an alert does
/// when it arrives or is tapped.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/alerts/data/notification_permission.dart';
import 'package:zad/features/alerts/domain/push_alert.dart';
import 'package:zad/features/insights/application/insights_controller.dart';
import 'package:zad/features/notifications/application/notifications_controller.dart';
import 'package:zad/features/proposals/application/proposals_controller.dart';

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
    await platform.start(onAlert: _arrived, onOpened: _opened);

    final registrar = ref.read(pushRegistrarProvider);
    _refreshes ??= platform.tokenRefreshes.listen(
      (t) => unawaited(registrar.register(t)),
    );
    try {
      final token = await platform.token();
      if (token != null && token != registrar.lastToken) {
        await registrar.register(token);
      }
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

  void _arrived(PushAlert alert) {
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
      case null:
        break;
    }
  }
}

/// The alerts.
final alertsControllerProvider = NotifierProvider<AlertsController, AlertsView>(
  AlertsController.new,
);
