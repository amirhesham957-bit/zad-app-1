/// The companion's big moments, shown once each where the customer already
/// is (Home's header):
///
/// * found asleep after two days away — «صحّيه», it wakes, «وحشتني!» and the
///   seeds it saved;
/// * a level — confetti, the new level, its seeds;
/// * an evolution — the old stage shrinks, a flash, the new stage pops in
///   with a bounce, and what changed is said plainly;
/// * XP that arrived since the last look — «+15 ⭐» floats up from the orb.
///
/// The server decides every one of these (`zad_companion_status`); this file
/// only stages them, then tells the server they were seen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/companion/domain/companion_status.dart';
import 'package:zad/shared/orb/application/pet_sound.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// Watches the companion and stages its moments over [child]. Also re-reads
/// it when the app comes back to the foreground.
class CompanionMoments extends ConsumerStatefulWidget {
  /// Wraps [child].
  const new({required this.child, super.key});

  /// What the moments float over.
  final Widget child;

  @override
  ConsumerState<CompanionMoments> createState() => _CompanionMomentsState();
}

class _CompanionMomentsState extends ConsumerState<CompanionMoments> {
  late final AppLifecycleListener _life;
  bool _showing = false;
  String? _celebrated;
  int? _lastXp;
  final List<_Gain> _gains = <_Gain>[];
  int _gainSeq = 0;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onResume: () {
        unawaited(ref.read(companionProvider.notifier).refresh());
        // Back in the app: «نام مستنيك» moves two days on again.
        unawaited(ref.read(localRemindersProvider).syncCompanionNap());
      },
    );
    ref.listenManual<AsyncValue<CompanionStatus?>>(
      companionProvider,
      (_, next) => _onStatus(next.value),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  void _onStatus(CompanionStatus? s) {
    if (s == null || !mounted) return;
    final last = _lastXp;
    _lastXp = s.xp;
    if (last != null && s.xp > last) {
      final id = ++_gainSeq;
      setState(() => _gains.add(_Gain(id, s.xp - last)));
      Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _gains.removeWhere((g) => g.id == id));
      });
    }
    if (_showing) return;
    final asleep = ref.read(companionProvider.notifier).asleep;
    if (asleep) {
      unawaited(_stage(() => showCompanionWelcome(context, status: s)));
    } else {
      _celebrate(s);
    }
  }

  /// Each level or evolution once per run, even before the server has
  /// recorded the acknowledgement.
  void _celebrate(CompanionStatus s) {
    final moment = s.celebrate;
    if (moment == null) return;
    final key = '${moment.toLevel}:${moment.toStage.index}';
    if (key == _celebrated) return;
    _celebrated = key;
    unawaited(
      _stage(
        () => showCompanionCelebration(context, status: s, moment: moment),
      ),
    );
  }

  Future<void> _stage(Future<void> Function() show) async {
    _showing = true;
    // After the frame: never open a dialog in the middle of a build.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    try {
      await show();
    } finally {
      _showing = false;
    }
    // A welcome may hide a celebration behind it; show that next.
    final s = ref.read(companionProvider).value;
    if (mounted && s != null && !ref.read(companionProvider.notifier).asleep) {
      _celebrate(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        widget.child,
        for (final g in _gains)
          PositionedDirectional(
            key: ValueKey<int>(g.id),
            top: -8,
            start: 24,
            child: IgnorePointer(child: _FloatingGain(xp: g.xp)),
          ),
      ],
    );
  }
}

class _Gain {
  new(this.id, this.xp);
  final int id;
  final int xp;
}

class _FloatingGain extends StatelessWidget {
  const new({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1400),
    curve: ZadCurves.standard,
    builder: (context, t, child) => Opacity(
      opacity: t < 0.15 ? t / 0.15 : (1 - t).clamp(0.0, 1.0) * 1.2,
      child: Transform.translate(offset: Offset(0, -40 * t), child: child),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: ZadColors.mustardOchre,
        borderRadius: BorderRadius.circular(ZadRadii.pill),
      ),
      child: Text(
        '+$xp ⭐',
        style: ZadType.labelLarge.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

// ── the dialogs ───────────────────────────────────────────────────────────

/// Found asleep: wake it, and it says it missed you.
Future<void> showCompanionWelcome(
  BuildContext context, {
  required CompanionStatus status,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _WelcomeDialog(status: status),
);

class _WelcomeDialog extends ConsumerStatefulWidget {
  const new({required this.status});

  final CompanionStatus status;

  @override
  ConsumerState<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends ConsumerState<_WelcomeDialog> {
  bool _awake = false;

  void _wake() {
    playPetSound(PetSound.happyChirp);
    setState(() => _awake = true);
  }

  void _close() {
    ref.read(companionProvider.notifier).wakeUp();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final name = s.persona.name;
    final days = (s.awayHours / 24).floor();
    return _MomentCard(
      confetti: _awake,
      orb: CompanionOrb(
        key: ValueKey<bool>(_awake),
        state: _awake ? CompanionState.celebrating : CompanionState.idle,
        look: s.look.copyWith(asleep: !_awake),
        size: 150,
        onTap: _awake ? null : _wake,
      ),
      title: _awake ? 'وحشتني! 💚' : '$name كان نايم مستنيك…',
      body: _awake
          ? (s.welcomeBack > 0
                ? 'جبت لك ${s.welcomeBack} 🌱 هدية رجوعك. يلا نكمّل سوا!'
                : 'يلا نكمّل سوا!')
          : days >= 2
          ? 'بقالك $days أيام مش هنا، فنام تحت البطانية. دوس عليه يصحى.'
          : 'دوس عليه يصحى.',
      action: _awake ? 'يلا بينا' : 'صحّيه 👋',
      onAction: _awake ? _close : _wake,
    );
  }
}

/// A level, or an evolution.
Future<void> showCompanionCelebration(
  BuildContext context, {
  required CompanionStatus status,
  required CompanionCelebration moment,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _CelebrationDialog(status: status, moment: moment),
    ).whenComplete(() {
      if (context.mounted) {
        unawaited(
          ProviderScope.containerOf(context)
              .read(companionProvider.notifier)
              .acknowledge(),
        );
      }
    });

class _CelebrationDialog extends StatefulWidget {
  const new({required this.status, required this.moment});

  final CompanionStatus status;
  final CompanionCelebration moment;

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog> {
  late bool _grown = !widget.moment.evolved;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    playPetSound(PetSound.celebrationTrill);
    if (!_grown) {
      _timer = Timer(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _grown = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.moment;
    final s = widget.status;
    final stage = _grown ? m.toStage : m.fromStage;
    final orb = AnimatedSwitcher(
      duration: ZadDuration.settle,
      switchInCurve: ZadCurves.springy,
      switchOutCurve: ZadCurves.exit,
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: CompanionOrb(
        key: ValueKey<CompanionStage>(stage),
        state: _grown ? CompanionState.celebrating : CompanionState.focused,
        look: s.look.copyWith(stage: stage),
        size: 150,
      ),
    );
    return _MomentCard(
      confetti: _grown,
      orb: orb,
      title: m.evolved
          ? (_grown
                ? '${s.persona.name} كبر! بقى ${m.toStage.label} ✨'
                : '${s.persona.name} بيتحوّل…')
          : 'لفل ${m.toLevel}! 🎉',
      body: m.evolved
          ? (_grown ? m.toStage.description : 'استنى… فيه حاجة بتحصل!')
          : 'كل حاجة سجّلتها كبّرت ${s.persona.name}.',
      seeds: _grown && m.seeds > 0 ? m.seeds : null,
      action: 'يا سلام!',
      onAction: _grown ? () => Navigator.of(context).pop() : null,
    );
  }
}

class _MomentCard extends StatelessWidget {
  const new({
    required this.orb,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    required this.confetti,
    this.seeds,
  });

  final Widget orb;
  final String title;
  final String body;
  final String action;
  final VoidCallback? onAction;
  final bool confetti;
  final int? seeds;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZadRadii.sheet),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  orb,
                  if (confetti && !still)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Lottie.asset(
                          'assets/lottie/lottie_confetti_burst.json',
                          repeat: false,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            Text(title, textAlign: TextAlign.center, style: ZadType.titleLarge),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: ZadType.bodyMedium.copyWith(color: ZadColors.slate),
            ),
            if (seeds != null) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZadSpacing.md,
                  vertical: ZadSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: ZadColors.mint50,
                  borderRadius: BorderRadius.circular(ZadRadii.pill),
                ),
                child: Text(
                  '+$seeds 🌱',
                  style: ZadType.titleMedium.copyWith(
                    color: ZadColors.green700,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: ZadSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(onPressed: onAction, child: Text(action)),
            ),
          ],
        ),
      ),
    );
  }
}
