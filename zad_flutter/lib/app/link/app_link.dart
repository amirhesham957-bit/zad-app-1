/// Telegram's «افتح زاد» buttons (`telegram.ts` `petCallKeyboard`): where the
/// link asks to go, from MainActivity's `zad/link` channel.
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
}

/// The target named [raw]; null for anything else.
AppLinkTarget? appLinkTargetFrom(Object? raw) => switch (raw) {
  'pet' => AppLinkTarget.pet,
  'deals' => AppLinkTarget.deals,
  _ => null,
};

/// MainActivity's link channel.
class AppLinkIntake {
  /// Creates the intake over [channel].
  new([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('zad/link');

  final MethodChannel _channel;

  /// Calls [onLink] with the link that opened the app and each one after.
  Future<void> listen(void Function(AppLinkTarget target) onLink) async {
    Future<void> take() async {
      final Object? raw;
      try {
        raw = await _channel.invokeMethod<Object?>('take');
      } on Object {
        // No channel (tests, another platform): no link.
        return;
      }
      final target = appLinkTargetFrom(raw);
      if (target != null) onLink(target);
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
