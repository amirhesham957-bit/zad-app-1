/// What the customer does in the app, by name and time only (ZAD_PLAN ١.١١).
///
/// Every gate in the plan that speaks of coming back — the customer returns
/// the next day, after a week, uses a feature at all — had no number, because
/// nothing recorded that the app was opened. This records it: a short event
/// name, and the server stamps the account and the time. Never content: no
/// amounts, no text, nothing from a screen.
///
/// Best effort by design. An event that cannot be sent is dropped, not queued:
/// the outbox is for the customer's data, and a missed «app_open» costs a
/// statistic, never a feature.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/auth/application/session_controller.dart';

/// The names the server accepts (the table's check constraint, mirrored).
final RegExp _name = RegExp(r'^[a-z][a-z0-9_.-]{1,47}$');

/// Records product events for the signed-in account.
class ProductEvents {
  /// Creates one. [send] writes one row; [signedIn] says whether an account
  /// is there to own it.
  new({
    required Future<void> Function(String name) send,
    required bool Function() signedIn,
    DateTime Function()? now,
  }) : _send = send,
       _signedIn = signedIn,
       _now = now ?? DateTime.now;

  final Future<void> Function(String name) _send;
  final bool Function() _signedIn;
  final DateTime Function() _now;
  final Map<String, DateTime> _last = <String, DateTime>{};

  /// Records [name], unless the same name was recorded less than [every] ago
  /// (so an app that flips between foreground and background counts as one
  /// open). Returns whether it was sent.
  Future<bool> log(String name, {Duration every = Duration.zero}) async {
    if (!_name.hasMatch(name) || !_signedIn()) return false;
    final now = _now();
    final last = _last[name];
    if (last != null && now.difference(last) < every) return false;
    _last[name] = now;
    try {
      await _send(name);
      return true;
    } on Object catch (e) {
      debugPrint('[events] $name not sent: $e');
      return false;
    }
  }

  /// Forgets what was sent, so a new account starts counting afresh.
  void reset() => _last.clear();
}

/// The app-wide recorder.
final productEventsProvider = Provider<ProductEvents>((ref) {
  final events = ProductEvents(
    send: (name) async {
      await ref.read(supabaseClientProvider).from('zad_product_events').insert(
        <String, Object>{'name': name},
      );
    },
    signedIn: () => ref.read(sessionControllerProvider) != null,
  );
  ref.listen(sessionControllerProvider, (_, _) => events.reset());
  return events;
});

/// How long the app may sit in the background and still be the same open.
const Duration kAppOpenWindow = Duration(minutes: 30);

/// Records one «app_open», at most every [kAppOpenWindow]. Fire and forget.
void logAppOpen(ProductEvents events) =>
    unawaited(events.log('app_open', every: kAppOpenWindow));
