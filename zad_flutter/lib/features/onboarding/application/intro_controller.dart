/// Whether this phone has been shown the introduction.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';

/// True once the introduction has been seen on this phone.
///
/// Kept in the `device` box, which a sign-out does not clear: the Kotlin app
/// forgot it on every sign-out and walked a returning customer through the
/// carousel again before they could reach the login form.
class IntroController extends Notifier<bool> {
  static const String _key = 'intro_seen';

  @override
  bool build() => ref.read(localStoreProvider).device.get(_key) == 'true';

  /// Marks it seen. The screen moves on at once; the write follows.
  void markSeen() {
    if (state) return;
    state = true;
    unawaited(ref.read(localStoreProvider).device.put(_key, 'true'));
  }
}

/// Whether the introduction has been seen.
final introSeenProvider = NotifierProvider<IntroController, bool>(
  IntroController.new,
);
