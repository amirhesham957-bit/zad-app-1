/// The rows a screen showed last time, so the next open draws them at once.
///
/// The core screens (budget, transactions, pantry, pharmacy, subscriptions,
/// shopping, chat) each have their own cache and outbox. The smaller screens
/// — appointments, أماكني, recommendations, maintenance, loans — asked the
/// server on every open and showed a spinner until it answered, which is the
/// "every screen loads from scratch" the owner saw (2026-09-30). They now
/// draw what they had, then refresh in place; the server's answer replaces
/// it.
///
/// Stored in the documents box, which is a cache: sign-out clears it, and
/// losing it costs one round trip. Keys carry the user id anyway, so one
/// account never draws another's rows on a shared phone.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// Last-seen rows per screen.
class ScreenCache {
  /// Creates the cache over a box; null (a test with no store) keeps nothing.
  const new(this._box);

  final Box<String>? _box;

  static String _key(String screen, String userId) => 'screen:$screen:$userId';

  /// The rows [screen] last showed for [userId], or null when there are none.
  List<Map<String, dynamic>>? read(String screen, String? userId) {
    final box = _box;
    if (box == null || userId == null) return null;
    try {
      final raw = box.get(_key(screen, userId));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return <Map<String, dynamic>>[
        for (final r in decoded)
          if (r is Map) Map<String, dynamic>.from(r),
      ];
    } on Object catch (e) {
      debugPrint('[screen_cache] $screen unreadable: $e');
      return null;
    }
  }

  /// Keeps [rows] as what [screen] shows for [userId].
  Future<void> write(
    String screen,
    String? userId,
    List<Map<String, dynamic>> rows,
  ) async {
    final box = _box;
    if (box == null || userId == null) return;
    try {
      await box.put(_key(screen, userId), jsonEncode(rows));
    } on Object catch (e) {
      debugPrint('[screen_cache] $screen not kept: $e');
    }
  }
}

/// The cache; empty where no local store was opened (widget tests).
final screenCacheProvider = Provider<ScreenCache>((ref) {
  try {
    return ScreenCache(ref.watch(localStoreProvider).documents);
  } on Object {
    return const ScreenCache(null);
  }
});
