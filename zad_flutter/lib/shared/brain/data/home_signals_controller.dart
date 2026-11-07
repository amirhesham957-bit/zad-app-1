/// The account's «حالة البيت» row, for the brief (ZAD_PLAN ٦.٤).
///
/// Offline first: the last row read is kept on the device under the
/// account's id and shown at once; the server is asked on the first read of
/// a run and on a pull to refresh, never more often than every five
/// minutes. One select of one row — no model call (CLAUDE.md).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/brain/domain/home_signals.dart';

/// Reads the signed-in account's row; null when there is none or it fails.
typedef HomeStateRead = Future<Map<String, dynamic>?> Function(String uid);

/// The read against Supabase (RLS: own row only).
final homeStateReadProvider = Provider<HomeStateRead>((ref) {
  return (uid) async {
    final row = await ref
        .read(supabaseClientProvider)
        .from('zad_home_state')
        .select('state')
        .eq('user_id', uid)
        .maybeSingle();
    final state = row?['state'];
    return state is Map ? Map<String, dynamic>.from(state) : null;
  };
});

/// The signals, or null before anything was ever read.
class HomeSignalsController extends Notifier<HomeSignals?> {
  static const Duration _every = Duration(minutes: 5);
  static String _key(String uid) => 'home_state:$uid';

  DateTime? _askedAt;

  @override
  HomeSignals? build() {
    final uid = ref.watch(sessionControllerProvider);
    if (uid == null) return null;
    _askedAt = null;
    unawaited(Future<void>.microtask(refresh));
    try {
      final raw = ref.read(localStoreProvider).device.get(_key(uid));
      if (raw == null) return null;
      return HomeSignals.fromState(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      return null;
    }
  }

  /// Asks the server, unless it was asked less than five minutes ago.
  Future<void> refresh({bool force = false}) async {
    final uid = ref.read(sessionControllerProvider);
    if (uid == null) return;
    final now = ref.read(nowProvider)();
    if (!force && _askedAt != null && now.difference(_askedAt!) < _every) {
      return;
    }
    _askedAt = now;
    try {
      final state = await ref.read(homeStateReadProvider)(uid);
      if (!ref.mounted || state == null) return;
      this.state = HomeSignals.fromState(state);
      unawaited(
        ref.read(localStoreProvider).device.put(_key(uid), jsonEncode(state)),
      );
    } on Object catch (e) {
      // Offline or refused: the cached row stays.
      debugPrint('home state read failed: $e');
    }
  }
}

/// The controller.
final homeSignalsControllerProvider =
    NotifierProvider<HomeSignalsController, HomeSignals?>(
      HomeSignalsController.new,
    );
