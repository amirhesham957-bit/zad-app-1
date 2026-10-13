/// رفيق زاد as a virtual pet on Home (owner, 2026-10-13): it sits on the
/// header's rule, wears its need on its face and colour (`pet_care.dart`),
/// says so in a small bubble now and then, and a tap opens its care sheet —
/// it talks, and the customer feeds it, gives it water and pets it.
///
/// It sits in the header, not over the list: the floating orb was taken off
/// Home on 2026-10-13 because it covered the transactions.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_pulses.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/companion/domain/pet_care.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/orb/application/companion_mood.dart';
import 'package:zad/shared/orb/application/pet_sound.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

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
  const new({this.size = 56, super.key});

  /// Its box.
  final double size;

  @override
  ConsumerState<CompanionHeaderPet> createState() => _CompanionHeaderPetState();
}

class _CompanionHeaderPetState extends ConsumerState<CompanionHeaderPet> {
  /// One unprompted bubble per half hour, across tab switches and rebuilds.
  static DateTime? _lastNudge;

  final OverlayPortalController _bubble = OverlayPortalController();
  final LayerLink _link = LayerLink();
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
    _life = AppLifecycleListener(onResume: _onShown);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onShown());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _hide?.cancel();
    _life.dispose();
    super.dispose();
  }

  void _onShown() {
    if (!mounted) return;
    final care = ref.read(petCareProvider);
    // Back in the app: the reminder moves to the next real need.
    unawaited(ref.read(localRemindersProvider).syncCompanionCare(care));
    if (care == null) return;
    final mood = ref.read(petCareProvider.notifier).moodNow();
    // Quietly: no sound unless tapped, and nothing at night.
    if (!mood.isNeed || mood == CompanionState.sleepy) return;
    final now = DateTime.now();
    final last = _lastNudge;
    if (last != null && now.difference(last) < const Duration(minutes: 30)) {
      return;
    }
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
    setState(() => _line = line);
    _bubble.show();
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted) _bubble.hide();
    });
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
            targetAnchor: rtl ? Alignment.bottomLeft : Alignment.bottomRight,
            followerAnchor: rtl ? Alignment.topLeft : Alignment.topRight,
            offset: const Offset(0, ZadSpacing.xs),
            child: _HeaderBubble(
              text: _line,
              rtl: rtl,
              onTap: () => _open(mood),
            ),
          ),
        ),
        child: Semantics(
          button: true,
          label: '$name — ${mood.description}. اضغط علشان تأكّله وتسقيه',
          excludeSemantics: true,
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                CompanionOrb(
                  state: mood,
                  size: widget.size,
                  onTap: () => _open(mood),
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
        ),
      ),
    );
  }
}

/// The small bubble under the header pet; a tap opens the care sheet.
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
      child: Padding(
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
