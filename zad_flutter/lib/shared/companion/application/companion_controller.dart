/// The companion as the app holds it: the server's status, re-read after every
/// change, and the one bit only the phone knows — that it is still asleep
/// because the customer has not said hello yet after being away.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/campaigns/application/market_season.dart';
import 'package:zad/shared/companion/data/companion_remote.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/companion/domain/companion_status.dart';

/// The companion, or null when there is none to show (signed out, offline,
/// or a server without the companion yet). Null draws the classic orb.
class CompanionController extends AsyncNotifier<CompanionStatus?> {
  /// Away this long and it is found asleep.
  static const int sleepAfterHours = 48;

  bool _asleep = false;

  /// Asleep until greeted.
  bool get asleep => _asleep;

  /// The cache's key for the last status the server gave.
  static const String cacheKey = 'companion_status';

  @override
  Future<CompanionStatus?> build() async {
    final userId = ref.watch(sessionControllerProvider);
    if (userId == null) return null;
    // The companion as it was last time, drawn at once; the server's read
    // follows. Without it every open drew the classic orb until the server
    // answered — and for good when it did not — then jumped to the
    // character: «بيهنج ويظهر شكل تاني» (owner, 2026-10-19).
    final cached = ref.read(screenCacheProvider).read(cacheKey, userId);
    if (cached != null && cached.isNotEmpty) {
      unawaited(Future<void>.microtask(() => _firstRead(userId)));
      return CompanionStatus.fromJson(cached.first);
    }
    final s = await _read(userId);
    _asleep = s != null && s.awayHours >= sleepAfterHours;
    return s;
  }

  /// The server's first answer after a cached draw: its celebration and the
  /// time away (which puts it to sleep) are only in this one.
  Future<void> _firstRead(String userId) async {
    final s = await _read(userId);
    if (s == null || !ref.mounted) return;
    _asleep = s.awayHours >= sleepAfterHours;
    state = AsyncData<CompanionStatus?>(s);
  }

  Future<CompanionStatus?> _read([String? userId]) async {
    try {
      final s = await ref.read(companionRemoteProvider).status();
      if (!ref.mounted) return s;
      final id = userId ?? ref.read(sessionControllerProvider);
      if (s != null) {
        unawaited(
          ref.read(screenCacheProvider).write(
            cacheKey,
            id,
            <Map<String, dynamic>>[s.toCacheJson()],
          ),
        );
      }
      return s;
    } on Object catch (e) {
      debugPrint('[companion] status failed: $e');
      return null;
    }
  }

  /// Reads the server again — after a log, a scan, or coming back to the app.
  Future<void> refresh() async {
    final s = await _read();
    if (s != null) state = AsyncData<CompanionStatus?>(s);
  }

  /// The customer said hello.
  void wakeUp() {
    if (!_asleep) return;
    _asleep = false;
    ref.notifyListeners();
  }

  /// The celebration was shown; it will not be shown again.
  Future<void> acknowledge() async {
    try {
      await ref.read(companionRemoteProvider).ack();
    } on Object catch (e) {
      debugPrint('[companion] ack failed: $e');
    }
    final s = state.value;
    if (s != null) {
      state = AsyncData<CompanionStatus?>(
        CompanionStatus(
          persona: s.persona,
          outfit: s.outfit,
          background: s.background,
          xp: s.xp,
          level: s.level,
          levelXp: s.levelXp,
          levelNeed: s.levelNeed,
          stage: s.stage,
          ageDays: s.ageDays,
          seeds: s.seeds,
          streak: s.streak,
          bestStreak: s.bestStreak,
          missions: s.missions,
          owned: s.owned,
          inviteCode: s.inviteCode,
          invites: s.invites,
          invitesPending: s.invitesPending,
          canClaimInvite: s.canClaimInvite,
          nextStageLevel: s.nextStageLevel,
          nextStageDays: s.nextStageDays,
          week: s.week,
        ),
      );
    }
  }

  /// Wears [item]; 'none' takes the outfit off.
  Future<CompanionResult> equip(String item) =>
      _act(() => ref.read(companionRemoteProvider).equip(item));

  /// Buys [item] with seeds, in its season when it has one.
  Future<CompanionResult> buy(String item) => _act(
    () => ref
        .read(companionRemoteProvider)
        .buy(item, season: ref.read(companionSeasonProvider)),
  );

  /// Enters a friend's code.
  Future<CompanionResult> claimInvite(String code) =>
      _act(() => ref.read(companionRemoteProvider).claimInvite(code));

  Future<CompanionResult> _act(Future<CompanionResult> Function() call) async {
    CompanionResult r;
    try {
      r = await call();
    } on Object catch (e) {
      debugPrint('[companion] action failed: $e');
      return (ok: false, reason: 'offline', missing: null);
    }
    if (r.ok) await refresh();
    return r;
  }
}

/// The companion.
final companionProvider =
    AsyncNotifierProvider<CompanionController, CompanionStatus?>(
      CompanionController.new,
    );

/// What every orb draws, or null for the classic orb (no companion yet).
final companionLookProvider = Provider<CompanionLook?>((ref) {
  final s = ref.watch(companionProvider).value;
  if (s == null) return null;
  return s.look.copyWith(asleep: ref.read(companionProvider.notifier).asleep);
});

/// `ramadan` or `eid` while one is on in the account's market, else null.
final companionSeasonProvider = Provider<String?>((ref) {
  final key = ref.watch(marketSeasonProvider)?.campaign.eventKey;
  return switch (key) {
    'ramadan' => 'ramadan',
    'eid_al_fitr' || 'eid_al_adha' => 'eid',
    _ => null,
  };
});
