/// Links that open the app from outside (`telegram.ts` `appLinkRedirect`):
/// where the link asks to go, from MainActivity's `zad/link` channel.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The places a link can open. Any app can send `zad://open`, so anything
/// outside this list is ignored.
enum AppLinkTarget {
  /// The pet's care sheet.
  pet,

  /// The deals page.
  deals,

  /// The page with the rewarded ad.
  rewards,

  /// The join-family dialog, with the invite's code.
  invite,
}

/// One link.
class AppLink {
  /// Creates a link.
  const new(this.target, {this.code});

  /// Where it goes.
  final AppLinkTarget target;

  /// The family invite's code; set only for [AppLinkTarget.invite].
  final String? code;
}

final RegExp _inviteCode = RegExp(r'^[A-Za-z0-9-]{4,32}$');

/// Reads the channel's map; null for anything outside the list.
AppLink? appLinkFrom(Object? raw) {
  if (raw is! Map) return null;
  final code = raw['code'];
  return switch (raw['to']) {
    'pet' => const AppLink(AppLinkTarget.pet),
    'deals' => const AppLink(AppLinkTarget.deals),
    'rewards' => const AppLink(AppLinkTarget.rewards),
    'invite' when code is String && _inviteCode.hasMatch(code) => AppLink(
      AppLinkTarget.invite,
      code: code,
    ),
    _ => null,
  };
}

/// MainActivity's link channel.
class AppLinkIntake {
  /// Creates the intake over [channel].
  new([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('zad/link');

  final MethodChannel _channel;

  /// Calls [onLink] with the link that opened the app and each one after.
  Future<void> listen(void Function(AppLink link) onLink) async {
    Future<void> take() async {
      final Object? raw;
      try {
        raw = await _channel.invokeMethod<Object?>('take');
      } on Object {
        // No channel (tests, another platform): no link.
        return;
      }
      final link = appLinkFrom(raw);
      if (link != null) onLink(link);
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'link') await take();
    });
    await take();
  }

  /// Stops listening.
  void close() => _channel.setMethodCallHandler(null);
}

/// The app's link intake.
final appLinkIntakeProvider = Provider<AppLinkIntake>((ref) => AppLinkIntake());
