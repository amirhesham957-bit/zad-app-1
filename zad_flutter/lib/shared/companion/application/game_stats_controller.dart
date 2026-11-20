/// Best score, today's best round and the day streak of one game for the
/// signed-in account, kept in the device box under `game_stats_<game>_<user>`
/// (the pattern of `pet_care_controller.dart`). Local only: nothing here is
/// sent or granted — seeds come from the server (`game_rewards.dart`).
///
/// Days are the account's market days: `accountTimeZoneProvider`, read
/// through the pet's clock so tests can move it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/companion/domain/game_stats.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

/// One game's stats, or fresh ones when signed out.
class GameStatsController extends Notifier<GameStats> {
  /// Creates the controller of the game with this server [gameId].
  new(this.gameId);

  /// `ZadGame.id`.
  final String gameId;

  String? _key;

  @override
  GameStats build() {
    final user = ref.watch(sessionControllerProvider);
    if (user == null) return const GameStats();
    final key = _key = 'game_stats_${gameId}_$user';
    try {
      return GameStats.fromJson(
        jsonDecode(ref.read(localStoreProvider).device.get(key) ?? 'null'),
      );
    } on Object catch (e) {
      debugPrint('[games] unreadable stats for $gameId, starting over: $e');
      return const GameStats();
    }
  }

  /// Today's market day.
  String today() => marketDayKey(
    petWallClock(
      ref.read(accountTimeZoneProvider),
      ref.read(petClockProvider)(),
    ),
  );

  /// Records a round that ended with [score].
  void record(int score) {
    final key = _key;
    if (key == null) return;
    final next = state.afterRound(score, today());
    state = next;
    unawaited(
      ref.read(localStoreProvider).device.put(key, jsonEncode(next.toJson())),
    );
  }
}

/// The stats of the game with this `ZadGame.id`.
// ignore: specify_nonobvious_property_types
final gameStatsProvider =
    NotifierProvider.family<GameStatsController, GameStats, String>(
      GameStatsController.new,
    );
