/// رفيق زاد as a virtual pet on Home (owner, 2026-10-13): it sits on the
/// header's rule, wears its need on its face and colour (`pet_care.dart`),
/// says so in a small bubble now and then, and a tap opens its care sheet —
/// it talks, and the customer feeds it, gives it water and pets it.
///
/// It floats over Home (owner, 2026-10-13: «عاوزو فلوتنج فوق البار»), above
/// the bottom bar by default, and the customer drags it wherever they like.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_pulses.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/companion/domain/fourth_wall.dart';
import 'package:zad/shared/companion/domain/pet_care.dart';
import 'package:zad/shared/companion/domain/pet_meal.dart';
import 'package:zad/shared/companion/domain/pet_stories.dart';
import 'package:zad/shared/companion/presentation/pet_ball_game.dart';
import 'package:zad/shared/companion/presentation/pet_price_games.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/orb/application/companion_mood.dart';
import 'package:zad/shared/orb/application/pet_sound.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';

/// The mood a pet shows: the voice's while it runs (the customer started it
/// just now), else its own need.
CompanionState petMood(WidgetRef ref, PetCare care, DateTime now) {
  final voice = ref.watch(companionMoodProvider);
  if (voice == CompanionState.listening ||
      voice == CompanionState.focused ||
      voice == CompanionState.speaking) {
    return voice;
  }
  final zone = ref.watch(accountTimeZoneProvider);
  return care.mood(now, hour: petWallClock(zone, now).hour);
}

String _petName(WidgetRef ref) =>
    ref.watch(companionProvider).value?.persona.name ?? 'زادو';

/// The badge a need wears over the head; null without one (sleepy has Zs).
String? _needBadge(CompanionState mood) => switch (mood) {
  CompanionState.hungry => '🍎',
  CompanionState.thirsty => '💧',
  CompanionState.sad => '💔',
  _ => null,
};

/// The pet on the header. Nothing when signed out.
class CompanionHeaderPet extends ConsumerStatefulWidget {
  /// Creates it.
  const new({this.size = 56, this.bubbleAbove = false, super.key});

  /// Its box.
  final double size;

  /// The bubble opens above it (floating over the bar) instead of below.
  final bool bubbleAbove;

  /// When the pet last saw the customer (ZAD_PLAN ٥.٢), in the device box.
  static const String lastSeenKey = 'pet_last_seen';

  /// The account-clock day the morning's dream was told.
  static const String dreamDayKey = 'pet_dream_day';

  /// When the weekly word was said.
  static const String weeklyAtKey = 'pet_weekly_at';

  /// Forgets the last unprompted bubble, so a test starts fresh.
  @visibleForTesting
  static void resetNudge() => _CompanionHeaderPetState._lastNudge = null;

  @override
  ConsumerState<CompanionHeaderPet> createState() => _CompanionHeaderPetState();
}

class _CompanionHeaderPetState extends ConsumerState<CompanionHeaderPet>
    with SingleTickerProviderStateMixin {
  /// One unprompted bubble per half hour, across tab switches and rebuilds.
  static DateTime? _lastNudge;

  /// Taps in the current burst (ZAD_PLAN ٥.٢); a pause of
  /// [tapBurstWindow] starts over. Timers, not clocks, so tests drive them.
  int _burst = 0;
  Timer? _burstEnd;

  /// The bubble has been up long enough for a second tap to mean «open».
  bool _bubbleRead = false;
  Timer? _bubbleReadTimer;

  final OverlayPortalController _bubble = OverlayPortalController();
  final LayerLink _link = LayerLink();

  /// A tap's hop: up and back with a small stretch (ZAD_PLAN ٥.١).
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: ZadDuration.settle,
  );
  late final AppLifecycleListener _life;
  Timer? _tick;
  Timer? _hide;
  String _line = '';

  @override
  void initState() {
    super.initState();
    // Hunger and thirst move by the minute; the face follows.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _life = AppLifecycleListener(onResume: _onShown, onPause: _markSeen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onShown());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _hide?.cancel();
    _burstEnd?.cancel();
    _bubbleReadTimer?.cancel();
    _life.dispose();
    _hop.dispose();
    super.dispose();
  }

  /// The last time the pet saw the customer, then now.
  Duration? _awayAndMark(DateTime now) {
    try {
      final box = ref.read(localStoreProvider).device;
      final last = DateTime.tryParse(
        box.get(CompanionHeaderPet.lastSeenKey) ?? '',
      );
      unawaited(
        box.put(CompanionHeaderPet.lastSeenKey, now.toUtc().toIso8601String()),
      );
      return last == null ? null : now.difference(last);
    } on Object {
      return null; // No store (a test host).
    }
  }

  /// ZAD_PLAN ٥.٣: the morning's dream, once a day, else the weekly word,
  /// once in seven days — each from real data, or nothing.
  String? _story(DateTime now) {
    try {
      final box = ref.read(localStoreProvider).device;
      final zone = ref.read(accountTimeZoneProvider);
      final wall = petWallClock(zone, now);
      final stage =
          ref.read(companionProvider).value?.stage ?? CompanionStage.seed;
      final today =
          '${wall.year}-${wall.month.toString().padLeft(2, '0')}-'
          '${wall.day.toString().padLeft(2, '0')}';
      if (isDreamHour(wall.hour) &&
          box.get(CompanionHeaderPet.dreamDayKey) != today) {
        final y = wall.subtract(const Duration(days: 1));
        final yesterday = ref.read(transactionsControllerProvider).rows.where((
          t,
        ) {
          final d = petWallClock(zone, t.createdAt);
          return d.year == y.year && d.month == y.month && d.day == y.day;
        }).toList();
        final dream = PetStories.dream(yesterday: yesterday, stage: stage);
        if (dream != null) {
          unawaited(box.put(CompanionHeaderPet.dreamDayKey, today));
          return dream;
        }
      }
      final week = ref.read(companionProvider).value?.week;
      final last = DateTime.tryParse(
        box.get(CompanionHeaderPet.weeklyAtKey) ?? '',
      );
      if (week != null &&
          (last == null || now.difference(last) >= const Duration(days: 7))) {
        unawaited(
          box.put(
            CompanionHeaderPet.weeklyAtKey,
            now.toUtc().toIso8601String(),
          ),
        );
        return PetStories.weekly(
          days: week.days,
          goal: week.goal,
          stage: stage,
        );
      }
    } on Object catch (e) {
      debugPrint('[pet] no story: $e');
    }
    return null;
  }

  void _markSeen() {
    if (mounted) _awayAndMark(ref.read(petClockProvider)());
  }

  void _onShown() {
    if (!mounted) return;
    final care = ref.read(petCareProvider);
    // Back in the app: the reminder moves to the next real need.
    unawaited(ref.read(localRemindersProvider).syncCompanionCare(care));
    if (care == null) return;
    final now = ref.read(petClockProvider)();
    final away = _awayAndMark(now);
    final last = _lastNudge;
    if (last != null && now.difference(last) < const Duration(minutes: 30)) {
      return;
    }
    // ZAD_PLAN ٥.٢: time away, then the clock — quietly, no sound.
    final hour = petWallClock(ref.read(accountTimeZoneProvider), now).hour;
    final aside =
        (away == null ? null : FourthWall.back(away)) ?? FourthWall.clock(hour);
    final story = aside ?? _story(now);
    if (story != null) {
      _lastNudge = now;
      _say(story);
      return;
    }
    final mood = ref.read(petCareProvider.notifier).moodNow();
    // Quietly: no sound unless tapped, and nothing at night.
    if (!mood.isNeed || mood == CompanionState.sleepy) return;
    _lastNudge = now;
    _say(
      PetLines.forMood(
        mood,
        name: ref.read(companionProvider).value?.persona.name ?? 'زادو',
        loggedToday: true,
      ),
    );
  }

  void _say(String line) {
    _bubbleRead = false;
    _bubbleReadTimer?.cancel();
    _bubbleReadTimer = Timer(
      const Duration(milliseconds: 600),
      () => _bubbleRead = true,
    );
    setState(() => _line = line);
    _bubble.show();
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted) _bubble.hide();
    });
  }

  /// A tap (ZAD_PLAN ٥.١): the pet hops and says how it is, from its real
  /// state. While it is talking, a second tap — or one on the bubble — opens
  /// the care sheet, so feeding stays one tap away.
  void _poke(CompanionState mood) {
    _burst++;
    _burstEnd?.cancel();
    _burstEnd = Timer(tapBurstWindow, () => _burst = 0);
    final poked = FourthWall.poked(
      _burst,
      name: ref.read(companionProvider).value?.persona.name ?? 'زادو',
    );
    if (poked != null) {
      // A burst: it says so instead of opening the sheet (ZAD_PLAN ٥.٢).
      unawaited(HapticFeedback.mediumImpact());
      playPetSound(PetSound.cuteSqueak);
      _hop.forward(from: 0);
      _say(poked);
      return;
    }
    if (_bubble.isShowing) {
      if (_bubbleRead) {
        _open(mood);
        return;
      }
      // Tapping fast is poking, not asking for the sheet: it just hops.
      unawaited(HapticFeedback.selectionClick());
      _hop.forward(from: 0);
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    playPetSound(
      mood == CompanionState.sad ? PetSound.whimper : PetSound.babble,
    );
    _hop.forward(from: 0);
    _say(
      PetLines.forMood(
        mood,
        name: ref.read(companionProvider).value?.persona.name ?? 'زادو',
        loggedToday: true,
      ),
    );
  }

  void _open(CompanionState mood) {
    _hide?.cancel();
    _bubble.hide();
    unawaited(HapticFeedback.selectionClick());
    playPetSound(
      mood == CompanionState.sad ? PetSound.whimper : PetSound.babble,
    );
    unawaited(showCompanionCareSheet(context));
  }

  @override
  Widget build(BuildContext context) {
    final care = ref.watch(petCareProvider);
    if (care == null) return const SizedBox.shrink();
    final mood = petMood(ref, care, ref.watch(petClockProvider)());
    final badge = _needBadge(mood);
    final name = _petName(ref);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _bubble,
        overlayChildBuilder: (_) => Align(
          alignment: AlignmentDirectional.topStart,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: widget.bubbleAbove
                ? (rtl ? Alignment.topLeft : Alignment.topRight)
                : (rtl ? Alignment.bottomLeft : Alignment.bottomRight),
            followerAnchor: widget.bubbleAbove
                ? (rtl ? Alignment.bottomLeft : Alignment.bottomRight)
                : (rtl ? Alignment.topLeft : Alignment.topRight),
            offset: Offset(
              0,
              widget.bubbleAbove ? -ZadSpacing.xs : ZadSpacing.xs,
            ),
            child: _HeaderBubble(
              text: _line,
              rtl: rtl,
              onTap: () => _open(mood),
            ),
          ),
        ),
        child: DragTarget<PetMeal>(
          onAcceptWithDetails: (d) => _eat(d.data),
          builder: (_, waiting, _) => AnimatedScale(
            scale: waiting.isEmpty ? 1 : 1.18,
            duration: ZadDuration.quick,
            curve: ZadCurves.springy,
            child: _body(mood, badge, name),
          ),
        ),
      ),
    );
  }

  /// An expense dropped on it (ZAD_PLAN ٥.٣): logged, and a meal.
  void _eat(PetMeal meal) {
    meal.log();
    final outcome = ref.read(petCareProvider.notifier).feed();
    unawaited(HapticFeedback.mediumImpact());
    playPetSound(PetSound.munch);
    _hop.forward(from: 0);
    _say(
      outcome == PetCareOutcome.full
          ? 'اتسجّل ✓ بس أنا شبعان خلاص 🤭'
          : 'اتسجّل ✓ يمّ يمّ! 😋',
    );
  }

  Widget _body(CompanionState mood, String? badge, String name) => Semantics(
    button: true,
    label: '$name — ${mood.description}. اضغط علشان تأكّله وتسقيه',
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          AnimatedBuilder(
            animation: _hop,
            builder: (_, child) {
              final up = math.sin(_hop.value * math.pi);
              return Transform.translate(
                offset: Offset(0, -widget.size * 0.25 * up),
                child: Transform.scale(
                  scaleX: 1 - 0.05 * up,
                  scaleY: 1 + 0.07 * up,
                  child: child,
                ),
              );
            },
            child: CompanionOrb(
              state: mood,
              size: widget.size,
              onTap: () => _poke(mood),
            ),
          ),
          if (badge != null)
            PositionedDirectional(
              top: -2,
              end: -4,
              child: IgnorePointer(
                child: ZadDotPulse(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: ZadColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: ZadColors.outline),
                    ),
                    child: Text(
                      badge,
                      style: ZadType.labelSmall.copyWith(height: 1),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// The colour of the glow under the pet: its need, or its joy.
Color _moodGlow(CompanionState mood) => switch (mood) {
  CompanionState.hungry => const Color(0xFFFF9F43),
  CompanionState.thirsty => const Color(0xFF4FC3F7),
  CompanionState.sad => const Color(0xFF9E9E9E),
  CompanionState.sleepy => const Color(0xFF9575CD),
  CompanionState.happy || CompanionState.celebrating => const Color(0xFFFFD54F),
  _ => ZadColors.forestEmerald,
};

/// The pet over Home, floating above the bottom bar (owner, 2026-10-13:
/// «اكبر شوية واقدر احركو… يبقى اكتف»). It fills the box it is given and
/// lives anywhere in it: dragged with a finger, it leans into the move and
/// lands with a hop, and stays where it was left — next launch too. A glow
/// in its mood's colour breathes under it, and it bobs while it waits.
class CompanionFloatingPet extends ConsumerStatefulWidget {
  /// Creates it.
  const new({this.size = 92, super.key});

  /// Its box.
  final double size;

  /// Where it was left, as fractions of the box (device box key).
  static const String positionKey = 'pet_float_position';

  @override
  ConsumerState<CompanionFloatingPet> createState() =>
      _CompanionFloatingPetState();
}

class _CompanionFloatingPetState extends ConsumerState<CompanionFloatingPet>
    with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: ZadDuration.settle,
  );

  /// Fractions of the free room: (1, 1) is the bottom-right corner.
  Offset _at = const Offset(0.04, 1);
  double _lean = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    try {
      final raw = ref
          .read(localStoreProvider)
          .device
          .get(CompanionFloatingPet.positionKey);
      final parts = raw?.split(',');
      if (parts != null && parts.length == 2) {
        final x = double.tryParse(parts[0]);
        final y = double.tryParse(parts[1]);
        if (x != null && y != null) {
          _at = Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
        }
      }
    } on Object catch (e) {
      debugPrint('[pet] no stored spot: $e');
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    _hop.dispose();
    super.dispose();
  }

  void _move(DragUpdateDetails d, Size room) {
    if (room.width <= 0 || room.height <= 0) return;
    setState(() {
      _dragging = true;
      _at = Offset(
        (_at.dx + d.delta.dx / room.width).clamp(0.0, 1.0),
        (_at.dy + d.delta.dy / room.height).clamp(0.0, 1.0),
      );
      _lean = (d.delta.dx / 40).clamp(-0.25, 0.25);
    });
  }

  void _drop() {
    setState(() {
      _dragging = false;
      _lean = 0;
    });
    unawaited(HapticFeedback.lightImpact());
    _hop.forward(from: 0);
    try {
      unawaited(
        ref
            .read(localStoreProvider)
            .device
            .put(
              CompanionFloatingPet.positionKey,
              '${_at.dx.toStringAsFixed(3)},${_at.dy.toStringAsFixed(3)}',
            ),
      );
    } on Object catch (e) {
      debugPrint('[pet] spot not saved: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final care = ref.watch(petCareProvider);
    if (care == null) return const SizedBox.shrink();
    final glow = _moodGlow(petMood(ref, care, ref.watch(petClockProvider)()));
    final box = widget.size + ZadSpacing.lg;
    return LayoutBuilder(
      builder: (context, c) {
        final room = Size(
          (c.maxWidth - box).clamp(0.0, double.infinity),
          (c.maxHeight - box).clamp(0.0, double.infinity),
        );
        return Stack(
          children: <Widget>[
            Positioned(
              left: _at.dx * room.width,
              top: _at.dy * room.height,
              width: box,
              height: box,
              child: GestureDetector(
                key: const ValueKey<String>('pet-floating-drag'),
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (d) => _move(d, room),
                onPanEnd: (_) => _drop(),
                onPanCancel: _drop,
                child: AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[_bob, _hop]),
                  builder: (_, child) {
                    final bob = _dragging
                        ? 0.0
                        : -4 + 8 * Curves.easeInOut.transform(_bob.value);
                    // A hop on landing: up and back, a small squash at the end.
                    final hop = math.sin(_hop.value * math.pi);
                    final breathe = 0.85 + 0.15 * _bob.value;
                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        // The glow on the floor, in the mood's colour.
                        Positioned(
                          bottom: 0,
                          child: IgnorePointer(
                            child: Container(
                              width: widget.size * 0.8 * breathe,
                              height: ZadSpacing.md,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  ZadRadii.card,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: glow.withValues(alpha: 0.55),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, bob - 18 * hop),
                          child: Transform.rotate(
                            angle: _lean,
                            child: Transform.scale(
                              scale: _dragging ? 1.12 : 1 + 0.06 * hop,
                              child: child,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  child: CompanionHeaderPet(
                    size: widget.size,
                    bubbleAbove: true,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The small bubble beside the pet; a tap opens the care sheet.
class _HeaderBubble extends StatelessWidget {
  const new({required this.text, required this.rtl, required this.onTap});

  final String text;
  final bool rtl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0.85, end: 1),
    duration: ZadDuration.enter,
    curve: ZadCurves.springy,
    builder: (_, s, child) => Transform.scale(
      scale: s,
      alignment: rtl ? Alignment.topLeft : Alignment.topRight,
      child: child,
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Material(
        color: ZadColors.surface,
        elevation: 3,
        shadowColor: ZadColors.shadowSpot,
        borderRadius: BorderRadius.circular(ZadRadii.card),
        child: InkWell(
          key: const ValueKey<String>('pet-header-bubble'),
          borderRadius: BorderRadius.circular(ZadRadii.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ZadSpacing.md,
              vertical: ZadSpacing.sm,
            ),
            child: Text(
              text,
              style: ZadType.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: ZadColors.ink,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ── the care sheet ───────────────────────────────────────────────────────────

/// Opens the pet's care sheet: it talks, and three needs with their
/// buttons — food, water, and a pat on the pet itself.
Future<void> showCompanionCareSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZadColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ZadRadii.sheet),
        ),
      ),
      builder: (_) => const CompanionCareSheet(),
    );

/// The care sheet's content.
class CompanionCareSheet extends ConsumerStatefulWidget {
  /// Creates it.
  const new({super.key});

  @override
  ConsumerState<CompanionCareSheet> createState() => _CompanionCareSheetState();
}

class _CompanionCareSheetState extends ConsumerState<CompanionCareSheet> {
  String? _line;
  CompanionState? _reaction;
  Timer? _reactionEnd;
  int _glow = 0;
  int _blink = 0;
  final List<_Float> _floats = <_Float>[];
  final List<Timer> _floatTimers = <Timer>[];
  int _floatSeq = 0;

  @override
  void dispose() {
    _reactionEnd?.cancel();
    for (final t in _floatTimers) {
      t.cancel();
    }
    super.dispose();
  }

  void _react(CompanionState mood, String line, String emoji, PetSound sound) {
    playPetSound(sound);
    setState(() {
      _line = line;
      _reaction = mood;
      _glow++;
      _blink++;
    });
    _reactionEnd?.cancel();
    _reactionEnd = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _reaction = null);
    });
    if (MediaQuery.disableAnimationsOf(context)) return;
    for (var i = 0; i < 3; i++) {
      final id = ++_floatSeq;
      setState(() => _floats.add(_Float(id, emoji, (i - 1) * 34.0, i * 90)));
      _floatTimers.add(
        Timer(Duration(milliseconds: 1100 + i * 90), () {
          if (mounted) setState(() => _floats.removeWhere((f) => f.id == id));
        }),
      );
    }
  }

  void _feed() {
    final notifier = ref.read(petCareProvider.notifier);
    final outcome = notifier.feed();
    if (outcome == PetCareOutcome.done) {
      unawaited(HapticFeedback.mediumImpact());
      _react(
        CompanionState.celebrating,
        PetLines.fed(outcome),
        '🍎',
        PetSound.munch,
      );
    } else {
      _react(
        CompanionState.happy,
        PetLines.fed(outcome),
        '😋',
        PetSound.cuteSqueak,
      );
    }
  }

  void _water() {
    final outcome = ref.read(petCareProvider.notifier).water();
    if (outcome == PetCareOutcome.done) {
      unawaited(HapticFeedback.mediumImpact());
      _react(
        CompanionState.celebrating,
        PetLines.watered(outcome),
        '💧',
        PetSound.gulp,
      );
    } else {
      _react(
        CompanionState.happy,
        PetLines.watered(outcome),
        '🙈',
        PetSound.cuteSqueak,
      );
    }
  }

  void _pat() {
    ref.read(petCareProvider.notifier).pet();
    unawaited(HapticFeedback.lightImpact());
    _react(CompanionState.happy, PetLines.petted(), '💚', PetSound.purr);
  }

  @override
  Widget build(BuildContext context) {
    final care = ref.watch(petCareProvider);
    if (care == null) return const SizedBox.shrink();
    final now = ref.watch(petClockProvider)();
    final mood = petMood(ref, care, now);
    final name = _petName(ref);
    final logged = ref.watch(companionProvider).value?.missions.logged ?? true;
    final line = _line ??= PetLines.forMood(
      mood,
      name: name,
      loggedToday: logged,
    );
    return SafeArea(
      top: false,
      // Scrolls on a short screen: the sheet grew a play button.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.xl,
          ZadSpacing.md,
          ZadSpacing.xl,
          ZadSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ZadColors.outline,
                  borderRadius: BorderRadius.circular(ZadRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: ZadSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    name,
                    style: ZadType.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ZadColors.ink,
                    ),
                  ),
                ),
                if (care.careStreak > 0)
                  Text(
                    '🔥 ${care.careStreak} يوم رعاية',
                    key: const ValueKey<String>('pet-care-streak'),
                    style: ZadType.labelLarge.copyWith(
                      color: ZadColors.mustardOchre,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.md),
            _SheetBubble(text: line),
            SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: <Widget>[
                  Semantics(
                    button: true,
                    label: 'دلّع $name',
                    child: CompanionOrb(
                      key: const ValueKey<String>('pet-care-orb'),
                      state: _reaction ?? mood,
                      size: 150,
                      glowTrigger: _glow,
                      blinkTrigger: _blink,
                      onTap: _pat,
                    ),
                  ),
                  for (final f in _floats)
                    IgnorePointer(
                      key: ValueKey<int>(f.id),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: Duration(milliseconds: 1000 + f.delayMs),
                        curve: ZadCurves.standard,
                        builder: (_, t, child) {
                          final p =
                              ((t * (1000 + f.delayMs) - f.delayMs) / 1000)
                                  .clamp(0.0, 1.0);
                          return Opacity(
                            opacity: (1 - p) * (p > 0 ? 1 : 0),
                            child: Transform.translate(
                              offset: Offset(f.dx, -20 - 70 * p),
                              child: Transform.scale(
                                scale: 0.8 + 0.5 * p,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: Text(f.emoji, style: ZadType.headlineMedium),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            _Meter(
              emoji: '🍎',
              label: 'الشبع',
              value: care.fullness(now),
              color: CompanionState.hungry.deep,
            ),
            const SizedBox(height: ZadSpacing.sm),
            _Meter(
              emoji: '💧',
              label: 'الريّ',
              value: care.hydration(now),
              color: CompanionState.thirsty.deep,
            ),
            const SizedBox(height: ZadSpacing.sm),
            _Meter(
              emoji: '💚',
              label: 'السعادة',
              value: care.joy(now),
              color: ZadColors.forestEmerald,
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              'اضغط على $name علشان تدلّعه',
              textAlign: TextAlign.center,
              style: ZadType.labelSmall.copyWith(color: ZadColors.textTertiary),
            ),
            const SizedBox(height: ZadSpacing.xl),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    key: const ValueKey<String>('pet-feed'),
                    onPressed: _feed,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: CompanionState.hungry.deep,
                    ),
                    child: const Text('🍎 أكّله'),
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey<String>('pet-water'),
                    onPressed: _water,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: CompanionState.thirsty.deep,
                    ),
                    child: const Text('💧 اسقيه'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            OutlinedButton(
              key: const ValueKey<String>('pet-play'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                final score = await showPetBallGame(context, name: name);
                if (!mounted || score == null) return;
                _react(
                  CompanionState.celebrating,
                  'لعبنا وجبت $score! 🏆',
                  '⚽',
                  PetSound.purr,
                );
              },
              child: const Text('⚽ العب معاه'),
            ),
            const SizedBox(height: ZadSpacing.sm),
            // ZAD_PLAN ٥.٤: two price games on real prices.
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey<String>('pet-guess'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () async {
                      final right = await showPetGuessGame(context, name: name);
                      if (!mounted || right == null) return;
                      _react(
                        CompanionState.celebrating,
                        'خمّنت $right صح! 💰',
                        '💰',
                        PetSound.purr,
                      );
                    },
                    child: const Text('💰 خمّن السعر'),
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey<String>('pet-memory'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () async {
                      final moves = await showPetMemoryGame(
                        context,
                        name: name,
                      );
                      if (!mounted || moves == null) return;
                      _react(
                        CompanionState.celebrating,
                        'خلصنا الذاكرة في $moves محاولات! 🧠',
                        '🧠',
                        PetSound.purr,
                      );
                    },
                    child: const Text('🧠 ذاكرة الأسعار'),
                  ),
                ),
              ],
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () {
                final nav = Navigator.of(context);
                final host = nav.context;
                nav.pop();
                unawaited(ZadScreens.showCompanionStudio(host));
              },
              child: const Text('👗 استوديو الرفيق'),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _Float {
  const new(this.id, this.emoji, this.dx, this.delayMs);

  final int id;
  final String emoji;
  final double dx;
  final int delayMs;
}

/// The bubble over the pet in the sheet, its tail pointing down at it.
class _SheetBubble extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      AnimatedSwitcher(
        duration: ZadDuration.quick,
        transitionBuilder: (child, a) => ScaleTransition(
          scale: Tween<double>(
            begin: 0.9,
            end: 1,
          ).animate(CurvedAnimation(parent: a, curve: ZadCurves.springy)),
          child: FadeTransition(opacity: a, child: child),
        ),
        child: Container(
          key: ValueKey<String>(text),
          padding: const EdgeInsets.symmetric(
            horizontal: ZadSpacing.lg,
            vertical: ZadSpacing.md,
          ),
          decoration: BoxDecoration(
            color: ZadColors.mint50,
            borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
          ),
          child: Text(
            text,
            key: const ValueKey<String>('pet-line'),
            textAlign: TextAlign.center,
            style: ZadType.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: ZadColors.ink,
            ),
          ),
        ),
      ),
      const CustomPaint(
        size: Size(18, 9),
        painter: _TailPainter(ZadColors.mint50),
      ),
    ],
  );
}

class _TailPainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close(),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

/// One need: its emoji, its name, a bar that fills as it is met.
class _Meter extends StatelessWidget {
  const new({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  final String emoji;
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final low = value < PetCare.needBelow;
    final bar = low ? ZadColors.terracottaRust : color;
    return Semantics(
      label: '$label ${(value * 100).round()}٪',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          SizedBox(width: 28, child: Text(emoji, style: ZadType.titleMedium)),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: ZadType.labelLarge.copyWith(color: ZadColors.slate),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ZadRadii.pill),
              child: Container(
                height: 10,
                color: bar.withValues(alpha: 0.12),
                alignment: AlignmentDirectional.centerStart,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: value),
                  duration: ZadDuration.settle,
                  curve: ZadCurves.standard,
                  builder: (_, v, _) => FractionallySizedBox(
                    widthFactor: v.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: ColoredBox(color: bar),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: ZadSpacing.sm),
          SizedBox(
            width: 40,
            child: Text(
              '${(value * 100).round()}٪',
              textAlign: TextAlign.end,
              style: ZadType.labelMedium.copyWith(
                color: low ? ZadColors.terracottaRust : ZadColors.slate,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
