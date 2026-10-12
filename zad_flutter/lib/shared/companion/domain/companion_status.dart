/// Everything `zad_companion_status()` answers, as the app reads it. The
/// phone computes none of it: XP, levels, seeds and what is owned live on the
/// server, which earns them from the rows the customer writes.
library;

import 'package:flutter/foundation.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';

/// A level-up or an evolution the app has not shown yet.
@immutable
class CompanionCelebration {
  /// Creates one.
  const new({
    required this.fromLevel,
    required this.toLevel,
    required this.fromStage,
    required this.toStage,
    required this.seeds,
  });

  /// Reads the server's `celebrate` object.
  factory fromJson(Map<String, dynamic> j) => CompanionCelebration(
    fromLevel: _int(j['from_level'], 1),
    toLevel: _int(j['to_level'], 1),
    fromStage: CompanionStage.at(_int(j['from_stage'], 0)),
    toStage: CompanionStage.at(_int(j['to_stage'], 0)),
    seeds: _int(j['seeds'], 0),
  );

  /// The level last shown.
  final int fromLevel;

  /// The level now.
  final int toLevel;

  /// The stage last shown.
  final CompanionStage fromStage;

  /// The stage now.
  final CompanionStage toStage;

  /// Seeds the new levels paid.
  final int seeds;

  /// It grew into a new stage — the big moment.
  bool get evolved => toStage.index > fromStage.index;
}

/// The day's three missions.
@immutable
class CompanionMissions {
  /// Creates them.
  const new({
    required this.logged,
    required this.home,
    required this.scanned,
    required this.xpToday,
  });

  /// An expense or income recorded today.
  final bool logged;

  /// The pantry or the shopping list touched today.
  final bool home;

  /// A receipt scanned today.
  final bool scanned;

  /// XP earned today.
  final int xpToday;

  /// How many of the three are done.
  int get done => (logged ? 1 : 0) + (home ? 1 : 0) + (scanned ? 1 : 0);
}

/// This week's challenge: something logged on five days of seven.
@immutable
class CompanionWeek {
  /// Creates it.
  const new({required this.days, required this.goal, required this.done});

  /// Reads the server's `week` object; null without one (an older server).
  static CompanionWeek? fromJson(Object? j) {
    if (j is! Map) return null;
    return CompanionWeek(
      days: _int(j['days'], 0),
      goal: _int(j['goal'], 5),
      done: j['done'] == true,
    );
  }

  /// Days with something logged so far this week.
  final int days;

  /// Days it takes.
  final int goal;

  /// Paid this week.
  final bool done;
}

/// The companion as the server holds it.
@immutable
class CompanionStatus {
  /// Creates a status.
  const new({
    required this.persona,
    required this.outfit,
    required this.background,
    required this.xp,
    required this.level,
    required this.levelXp,
    required this.levelNeed,
    required this.stage,
    required this.ageDays,
    required this.seeds,
    required this.streak,
    required this.bestStreak,
    required this.missions,
    required this.owned,
    required this.inviteCode,
    required this.invites,
    required this.invitesPending,
    required this.canClaimInvite,
    this.nextStageLevel,
    this.nextStageDays,
    this.celebrate,
    this.welcomeBack = 0,
    this.awayHours = 0,
    this.week,
  });

  /// Reads `zad_companion_status()`.
  factory fromJson(Map<String, dynamic> j) {
    final today =
        (j['today'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final next = (j['next_stage'] as Map?)?.cast<String, dynamic>();
    final celebrate = (j['celebrate'] as Map?)?.cast<String, dynamic>();
    return CompanionStatus(
      persona: CompanionPersona.byId(j['persona'] as String?),
      outfit: CompanionOutfit.byId(j['outfit'] as String?),
      background: CompanionBackground.byId(j['background'] as String?),
      xp: _int(j['xp'], 0),
      level: _int(j['level'], 1),
      levelXp: _int(j['level_xp'], 0),
      levelNeed: _int(j['level_need'], 100),
      stage: CompanionStage.at(_int(j['stage'], 0)),
      ageDays: _int(j['age_days'], 0),
      seeds: _int(j['seeds'], 0),
      streak: _int(j['streak'], 0),
      bestStreak: _int(j['best_streak'], 0),
      missions: CompanionMissions(
        logged: today['log'] == true,
        home: today['pantry'] == true,
        scanned: today['scan'] == true,
        xpToday: _int(today['xp'], 0),
      ),
      owned: <String>{
        for (final o in (j['owned'] as List?) ?? const <Object?>[]) '$o',
      },
      inviteCode: (j['invite_code'] as String?) ?? '',
      invites: _int(j['invites'], 0),
      invitesPending: _int(j['invites_pending'], 0),
      canClaimInvite: j['can_claim_invite'] == true,
      nextStageLevel: next == null ? null : _int(next['level'], 0),
      nextStageDays: next == null ? null : _int(next['days'], 0),
      celebrate: celebrate == null
          ? null
          : CompanionCelebration.fromJson(celebrate),
      welcomeBack: _int(j['welcome_back'], 0),
      awayHours: _int(j['away_hours'], 0),
      week: CompanionWeek.fromJson(j['week']),
    );
  }

  /// Who it is.
  final CompanionPersona persona;

  /// What it wears.
  final CompanionOutfit outfit;

  /// Its studio's background.
  final CompanionBackground background;

  /// All the XP it ever earned.
  final int xp;

  /// Its level.
  final int level;

  /// XP into this level.
  final int levelXp;

  /// XP this level takes.
  final int levelNeed;

  /// How grown.
  final CompanionStage stage;

  /// Days since it was born, on the account's clock.
  final int ageDays;

  /// 🌱
  final int seeds;

  /// Days in a row with something logged.
  final int streak;

  /// The longest run.
  final int bestStreak;

  /// Today's missions.
  final CompanionMissions missions;

  /// Item ids owned.
  final Set<String> owned;

  /// This account's code for friends.
  final String inviteCode;

  /// Friends who joined and started.
  final int invites;

  /// Friends who joined and have not logged yet.
  final int invitesPending;

  /// This account may still enter a friend's code.
  final bool canClaimInvite;

  /// The next stage's level, or null at حكيم.
  final int? nextStageLevel;

  /// The next stage's age in days.
  final int? nextStageDays;

  /// Something to celebrate, once.
  final CompanionCelebration? celebrate;

  /// Seeds for coming back after two days or more; 0 when not.
  final int welcomeBack;

  /// Hours since it was last seen, before this read.
  final int awayHours;

  /// This week's challenge; null from an older server.
  final CompanionWeek? week;

  /// What the orb draws.
  CompanionLook get look =>
      CompanionLook(persona: persona, stage: stage, outfit: outfit);

  /// 0..1 through this level.
  double get levelProgress =>
      levelNeed <= 0 ? 0 : (levelXp / levelNeed).clamp(0.0, 1.0);

  /// Whether [id] is owned.
  bool owns(String id) => owned.contains(id);
}

int _int(Object? v, int fallback) => switch (v) {
  final int i => i,
  final num n => n.toInt(),
  final String s => int.tryParse(s) ?? fallback,
  _ => fallback,
};
