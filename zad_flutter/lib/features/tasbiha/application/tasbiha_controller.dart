/// The garden's state and every action Kotlin's `FamilyViewModel` runs for
/// it: load (creating a first tree if the member has none), select, tap,
/// reset, rename, new tree, new challenge.
///
/// Taps are local first and batched: each one updates the screen at once and
/// adds to a pending delta, and 1.5s after the last tap the delta goes up in
/// one atomic `increment_tasbiha_clicks`. A failed flush keeps the delta for
/// the next one, and leaving the app's provider scope flushes what is left.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/alerts/application/local_reminders.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/application/family_life_controller.dart';
import 'package:zad/features/tasbiha/data/tasbiha_remote.dart';
import 'package:zad/features/tasbiha/domain/tasbiha.dart';

/// What the garden screen shows.
@immutable
class TasbihaView {
  /// Creates a view.
  const new({
    this.myTrees = const <GardenTree>[],
    this.familyTrees = const <GardenTree>[],
    this.challenges = const <TasbihaChallenge>[],
    this.progress = const <String, int>{},
    this.selectedId,
    this.isLoading = true,
  });

  /// The member's own trees, highest score first.
  final List<GardenTree> myTrees;

  /// Every tree in the family.
  final List<GardenTree> familyTrees;

  /// Active challenges.
  final List<TasbihaChallenge> challenges;

  /// The member's clicks per challenge id.
  final Map<String, int> progress;

  /// The tree being counted on.
  final String? selectedId;

  /// Whether the first load is out.
  final bool isLoading;

  /// The selected tree, else the first.
  GardenTree? get selected =>
      myTrees.where((t) => t.id == selectedId).firstOrNull ??
      myTrees.firstOrNull;

  /// A copy with fields replaced.
  TasbihaView copyWith({
    List<GardenTree>? myTrees,
    List<GardenTree>? familyTrees,
    List<TasbihaChallenge>? challenges,
    Map<String, int>? progress,
    String? selectedId,
    bool? isLoading,
  }) => TasbihaView(
    myTrees: myTrees ?? this.myTrees,
    familyTrees: familyTrees ?? this.familyTrees,
    challenges: challenges ?? this.challenges,
    progress: progress ?? this.progress,
    selectedId: selectedId ?? this.selectedId,
    isLoading: isLoading ?? this.isLoading,
  );
}

/// The garden.
class TasbihaController extends Notifier<TasbihaView> {
  Timer? _flush;
  String? _reminderMovedFor;
  int _pendingDelta = 0;
  GardenTree? _pendingTree;

  late TasbihaRemote _remote;

  @override
  TasbihaView build() {
    // Captured here: a disposed notifier may not read providers, and the
    // last flush below runs exactly then.
    final remote = _remote = TasbihaRemote(ref.read(supabaseClientProvider));
    ref.onDispose(() {
      _flush?.cancel();
      final tree = _pendingTree;
      final delta = _pendingDelta;
      if (delta > 0 && tree != null) {
        unawaited(remote.increment(tree, delta).then((_) {}, onError: (_) {}));
      }
    });
    return const TasbihaView();
  }

  // Straight to the chat table: reading the family-life notifier from here
  // would build it (and its realtime subscription) just to send one line.
  Future<void> _announce(String text) async {
    final view = ref.read(familyControllerProvider);
    final family = view.family;
    final me = family?.me(view.userId);
    if (family == null || me == null) return;
    try {
      await ref
          .read(familyLifeRemoteProvider)
          .sendMessage(
            familyId: family.id,
            senderId: me.id,
            message: text,
            type: 'TEXT',
          );
    } on Object catch (e) {
      debugPrint('Tasbiha milestone message failed: $e');
    }
  }

  String? get _familyId => ref.read(familyControllerProvider).family?.id;
  String get _userId => ref.read(familyControllerProvider).userId;

  /// Kotlin's `loadTasbiha`.
  Future<void> load() async {
    final familyId = _familyId;
    if (familyId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    try {
      final remote = _remote;
      final family = await remote.familyTrees(familyId);
      var mine = family.where((t) => t.userId == _userId).toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      if (mine.isEmpty) {
        // A tree from the first open, so the first tap counts.
        final first = await remote.createTree(
          familyId: familyId,
          userId: _userId,
          gardenName: 'بستاني',
          treeName: 'بذرة',
        );
        mine = <GardenTree>[first];
        family.add(first);
      }
      final challenges = await remote.activeChallenges(familyId);
      final progress = await remote.myProgress(<String>[
        for (final c in challenges) c.id,
      ], _userId);
      state = state.copyWith(
        myTrees: _mergePending(mine),
        familyTrees: family,
        challenges: challenges,
        progress: progress,
        selectedId: state.selectedId ?? mine.first.id,
        isLoading: false,
      );
    } on Object catch (e) {
      debugPrint('Tasbiha load failed: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // Taps not yet flushed stay on screen through a reload.
  List<GardenTree> _mergePending(List<GardenTree> server) {
    final p = _pendingTree;
    if (p == null || _pendingDelta == 0) return server;
    return <GardenTree>[
      for (final t in server)
        if (t.id == p.id) p else t,
    ];
  }

  /// Selects a tree.
  void select(GardenTree tree) => state = state.copyWith(selectedId: tree.id);

  String _today() {
    final local = tz.TZDateTime.from(
      ref.read(nowProvider)().toUtc(),
      tz.getLocation(ref.read(accountTimeZoneProvider)),
    );
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  String _yesterday(String today) {
    final d = DateTime.parse(today).subtract(const Duration(days: 1));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// Kotlin's `tasbihaClick`.
  void tap() {
    final tree = state.selected;
    if (tree == null) {
      unawaited(load());
      return;
    }
    final score = tree.score + 1;
    final level = (score ~/ 99 + 1).clamp(1, 5);
    final today = _today();
    final last = tree.lastStreakDate;
    final streak = last == null
        ? 1
        : last == today
        ? (tree.streakDays < 1 ? 1 : tree.streakDays)
        : last == _yesterday(today)
        ? tree.streakDays + 1
        : 1;
    final nowIso = ref.read(nowProvider)().toUtc().toIso8601String();
    final matureNow = level >= 5;
    final updated = tree.copyWith(
      score: score,
      level: level,
      totalClicks: tree.totalClicks + 1,
      lastTasbihAt: nowIso,
      streakDays: streak,
      lastStreakDate: today,
      isMature: matureNow,
      maturedAt: matureNow && !tree.isMature ? nowIso : tree.maturedAt,
    );
    _replace(updated);

    _pendingDelta += 1;
    _pendingTree = updated;
    // Said tasbih today: today's 17:00 reminder moves to tomorrow.
    if (_reminderMovedFor != today) {
      _reminderMovedFor = today;
      unawaited(
        ref
            .read(localRemindersProvider)
            .syncTasbih(doneToday: true)
            .then((_) {}, onError: (Object _) {}),
      );
    }
    _flush?.cancel();
    _flush = Timer(const Duration(milliseconds: 1500), () {
      unawaited(_flushNow());
    });

    // Kotlin's milestone messages to the family chat.
    if (level > tree.level) {
      unawaited(
        _announce(
          '🌳 تسبيحة: ${updated.treeName} وصلت لمرحلة '
          '${updated.stageName()}! 🎉',
        ),
      );
    }
    if (score % 100 == 0) {
      unawaited(
        _announce(
          '🌳 ${updated.treeName} وصلت $score تسبيحة! ${updated.stageEmoji()}',
        ),
      );
    }
    if (!tree.isMature && matureNow) {
      unawaited(
        _announce("🎉 مبروك! شجرة '${updated.treeName}' أثمرت لأول مرة! 🍎"),
      );
    }
    if (streak > 0 && streak % 7 == 0 && streak != tree.streakDays) {
      unawaited(
        _announce(
          '🔥 ${updated.treeName} نشطة لمدة $streak أيام متتالية! استمروا!',
        ),
      );
    }
  }

  Future<void> _flushNow() async {
    final tree = _pendingTree;
    final delta = _pendingDelta;
    if (tree == null || delta <= 0) return;
    _pendingDelta = 0;
    try {
      await _remote.increment(tree, delta);
      final familyId = _familyId;
      if (familyId != null) {
        final family = await _remote.familyTrees(familyId);
        state = state.copyWith(familyTrees: family);
      }
    } on Object catch (e) {
      // Put the taps back so the next flush still carries them.
      _pendingDelta += delta;
      debugPrint('Tasbiha flush failed: $e');
    }
  }

  void _replace(GardenTree updated) {
    state = state.copyWith(
      myTrees: <GardenTree>[
        for (final t in state.myTrees)
          if (t.id == updated.id) updated else t,
      ],
      familyTrees: <GardenTree>[
        for (final t in state.familyTrees)
          if (t.id == updated.id) updated else t,
      ],
    );
  }

  /// Kotlin's `resetTasbiha`: the counter back to zero on this screen only —
  /// as in Kotlin, nothing is written, so the next load shows the server's.
  void reset() {
    final tree = state.selected;
    if (tree == null) return;
    _replace(tree.copyWith(score: 0, level: 1));
  }

  /// Renames the selected tree (a quick dhikr chip does this too).
  Future<void> rename(String name) async {
    final tree = state.selected;
    if (tree == null) return;
    _replace(tree.copyWith(treeName: name));
    if (_pendingTree?.id == tree.id) {
      _pendingTree = _pendingTree!.copyWith(treeName: name);
    }
    try {
      await _remote.rename(tree.id, name);
    } on Object catch (e) {
      debugPrint('Tasbiha rename failed: $e');
    }
  }

  /// Kotlin's `createNewTree`.
  Future<void> createTree(String gardenName) async {
    final familyId = _familyId;
    if (familyId == null) return;
    try {
      final tree = await _remote.createTree(
        familyId: familyId,
        userId: _userId,
        gardenName: gardenName,
      );
      state = state.copyWith(
        myTrees: <GardenTree>[...state.myTrees, tree]
          ..sort((a, b) => b.score.compareTo(a.score)),
        familyTrees: <GardenTree>[...state.familyTrees, tree],
        selectedId: tree.id,
      );
    } on Object catch (e) {
      debugPrint('Tasbiha create failed: $e');
    }
  }

  /// Kotlin's `createTasbihaChallenge`.
  Future<void> createChallenge({
    required String title,
    required String? description,
    required String challengeType,
    required int targetClicks,
  }) async {
    final familyId = _familyId;
    if (familyId == null) return;
    try {
      await _remote.createChallenge(
        familyId: familyId,
        title: title,
        description: description,
        challengeType: challengeType,
        targetClicks: targetClicks,
      );
      state = state.copyWith(
        challenges: await _remote.activeChallenges(familyId),
      );
    } on Object catch (e) {
      debugPrint('Tasbiha challenge failed: $e');
    }
  }
}

/// The garden, kept for the session so a tap burst survives leaving the
/// screen and the kids home can show the tree.
final tasbihaControllerProvider =
    NotifierProvider<TasbihaController, TasbihaView>(TasbihaController.new);
