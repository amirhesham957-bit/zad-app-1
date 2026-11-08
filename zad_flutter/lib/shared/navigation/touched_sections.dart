/// The sections this customer has opened, so the drawer can show those and
/// keep the rest under «كل المزايا» (ZAD_PLAN 6.5).
///
/// Per account and on the phone only: this is a convenience for one person's
/// menu, and hiding by the whole app's usage would hide nearly everything at
/// today's numbers (measured 2026-11-08: 17 customers, 0–3 opens a section).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/auth/application/session_controller.dart';

/// Which sections have been opened.
class TouchedSections extends Notifier<Set<String>> {
  String? get _key {
    final user = ref.read(sessionControllerProvider);
    return user == null ? null : 'drawer_touched_$user';
  }

  @override
  Set<String> build() {
    ref.watch(sessionControllerProvider);
    final key = _key;
    if (key == null) return const <String>{};
    try {
      final raw = ref.read(localStoreProvider).device.get(key);
      if (raw == null) return const <String>{};
      return <String>{...(jsonDecode(raw) as List<dynamic>).cast<String>()};
    } on Object {
      // A menu preference is never worth failing the shell for.
      return const <String>{};
    }
  }

  /// Remembers that section [id] was opened.
  void touch(String id) {
    if (state.contains(id)) return;
    state = <String>{...state, id};
    final key = _key;
    if (key == null) return;
    try {
      unawaited(
        ref
            .read(localStoreProvider)
            .device
            .put(key, jsonEncode(state.toList())),
      );
    } on Object {
      // Forgotten next launch at worst.
    }
  }
}

/// The sections opened on this account.
final touchedSectionsProvider = NotifierProvider<TouchedSections, Set<String>>(
  TouchedSections.new,
);
