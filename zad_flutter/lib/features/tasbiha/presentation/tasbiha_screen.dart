/// Kotlin's `TasbihaScreen`: the garden splash, then three tabs — بستاني
/// (the counting tree with its ring, particles, level-up burst and falling
/// leaves; quick dhikr chips; stats; the member's trees), أشجار العائلة (the
/// leaderboard, shareable as an image) and التحديات (with a new-challenge
/// dialog for the admin).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/tasbiha/application/tasbiha_controller.dart';
import 'package:zad/features/tasbiha/domain/tasbiha.dart';
import 'package:zad/features/tasbiha/presentation/leaderboard_share.dart';

/// Opens the garden.
Future<void> showTasbihaScreen(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const TasbihaScreen()));

const Color _green = Color(0xFF2E7D32);
const Color _gold = Color(0xFFFFD700);
const Color _lilac = Color(0xFF9C27B0);
Color get _coral => ZadColors.terracottaRust;
const Color _primary = ZadColors.green700;

/// The garden.
class TasbihaScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<TasbihaScreen> createState() => _TasbihaScreenState();
}

class _TasbihaScreenState extends ConsumerState<TasbihaScreen> {
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => mounted
            ? ref.read(tasbihaControllerProvider.notifier).load()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Opened before the family finished loading: read the garden once it has.
    ref.listen(familyControllerProvider.select((v) => v.family?.id), (
      previous,
      next,
    ) {
      if (next != null && next != previous) {
        unawaited(ref.read(tasbihaControllerProvider.notifier).load());
      }
    });
    return _body();
  }

  Widget _body() => AnimatedSwitcher(
    duration: ZadDuration.enter,
    child: _entered
        ? const _Main()
        : _Splash(onEnter: () => setState(() => _entered = true)),
  );
}

// ── Splash ──────────────────────────────────────────────────────────────────

class _Splash extends StatefulWidget {
  const new({required this.onEnter});

  final VoidCallback onEnter;

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with TickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();
  final List<double> _seeds = <double>[
    for (var i = 0; i < 20; i++) math.Random(i * 7919).nextDouble(),
  ];
  bool _pressed = false;

  @override
  void dispose() {
    _breathe.dispose();
    _spin.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xFF1B5E20),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1B5E20), _green, Color(0xFF43A047)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Floating particles.
            AnimatedBuilder(
              animation: _drift,
              builder: (context, _) => Stack(
                children: <Widget>[
                  for (final (i, seed) in _seeds.indexed)
                    () {
                      final period = 4 + i * 0.3;
                      final t = (_drift.value * 10 / period + seed) % 1;
                      final sway =
                          30 * math.sin(i + _drift.value * 2 * math.pi);
                      return Positioned(
                        left: seed * box.maxWidth + sway,
                        top: -20 + t * (box.maxHeight + 40),
                        child: Container(
                          width: 4.0 + i % 4,
                          height: 4.0 + i % 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(
                              alpha: 0.15 + (i % 3) * 0.05,
                            ),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            ),
            AnimatedScale(
              scale: _pressed ? 0.9 : 1,
              duration: const Duration(milliseconds: 150),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[_breathe, _spin]),
                  builder: (context, _) {
                    final b = Curves.fastOutSlowIn.transform(_breathe.value);
                    final glow = 0.2 + 0.4 * b;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox.square(
                          dimension: 200,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Transform.rotate(
                                angle: _spin.value * 2 * math.pi,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: <Color>[
                                        _gold.withValues(alpha: 0.4),
                                        Colors.transparent,
                                        const Color(0xFF4CAF50)
                                            .withValues(alpha: 0.3),
                                        Colors.transparent,
                                        _gold.withValues(alpha: 0.4),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: <Color>[
                                      _gold.withValues(alpha: glow),
                                      const Color(0xFF4CAF50)
                                          .withValues(alpha: glow * 0.5),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              Transform.scale(
                                scale: 0.85 + 0.3 * b,
                                child: const Icon(
                                  ZadIcons.tree,
                                  size: 80,
                                  color: _green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: ZadSpacing.xxl),
                        Opacity(
                          opacity: 0.4 + glow,
                          child: Text(
                            'بستان التسبيحة',
                            style: ZadType.headlineLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: ZadSpacing.sm),
                        Text(
                          'نمِّ شجرتك بالتسبيحة',
                          style: ZadType.bodyLarge.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: 220,
                          height: 56,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _green,
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            onPressed: () {
                              setState(() => _pressed = true);
                              widget.onEnter();
                            },
                            icon: const Icon(Icons.play_arrow, size: 28),
                            label: const Text(
                              'ادخل البستان',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Main ────────────────────────────────────────────────────────────────────

class _Main extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_Main> createState() => _MainState();
}

class _MainState extends ConsumerState<_Main> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(tasbihaControllerProvider);
    final total = view.myTrees.fold<int>(0, (s, t) => s + t.score);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('تسبيحة')),
        body:
            Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: ZadSpacing.md,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: ZadColors.hero,
                          borderRadius: BorderRadius.circular(ZadRadii.card),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                ZadIcons.tree,
                                size: 24,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'بستان التسبيحة',
                                    style: ZadType.titleMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: ZadSpacing.xs),
                                  Text(
                                    '${view.myTrees.length} أشجار | '
                                    '$total تسبيحة',
                                    style: ZadType.labelMedium.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const <ButtonSegment<int>>[
                          ButtonSegment<int>(value: 0, label: Text('بستاني')),
                          ButtonSegment<int>(
                            value: 1,
                            label: Text('أشجار العائلة'),
                          ),
                          ButtonSegment<int>(value: 2, label: Text('التحديات')),
                        ],
                        selected: <int>{_tab},
                        onSelectionChanged: (s) =>
                            setState(() => _tab = s.first),
                      ),
                    ),
                    Expanded(
                      child: view.isLoading && view.myTrees.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : switch (_tab) {
                              0 => const _MyGardenTab(),
                              1 => const _FamilyGardenTab(),
                              _ => const _ChallengesTab(),
                            },
                    ),
                  ],
                )
                .animate(delay: 100.ms)
                .fadeIn(duration: 400.ms)
                .moveY(
                  begin: 40,
                  duration: 500.ms,
                  curve: Curves.fastOutSlowIn,
                ),
      ),
    );
  }
}

// ── My garden ───────────────────────────────────────────────────────────────

class _MyGardenTab extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(tasbihaControllerProvider);
    final tree = view.selected;
    final garden = ref.read(tasbihaControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(ZadSpacing.lg, 0, ZadSpacing.lg, 120),
      children: <Widget>[
        const SizedBox(height: ZadSpacing.sm),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            itemCount: kQuickDhikrs.length,
            separatorBuilder: (_, _) => const SizedBox(width: ZadSpacing.sm),
            itemBuilder: (context, i) {
              final dhikr = kQuickDhikrs[i];
              final on = tree?.treeName == dhikr;
              return FilterChip(
                selected: on,
                showCheckmark: false,
                onSelected: (_) => unawaited(garden.rename(dhikr)),
                selectedColor: _primary,
                backgroundColor: ZadColors.surface,
                side: BorderSide(
                  color: on
                      ? _primary
                      : ZadColors.outline.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                label: Text(
                  dhikr,
                  style: ZadType.bodySmall.copyWith(
                    color: on ? Colors.white : ZadColors.ink,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: ZadSpacing.sm),
        if (tree != null) ...<Widget>[
          _TreeDisplay(
            tree: tree,
            onTap: garden.tap,
            onReset: garden.reset,
            onRename: () => unawaited(_renameDialog(context, garden, tree)),
          ),
          const SizedBox(height: ZadSpacing.lg),
          _Stats(tree: tree),
          const SizedBox(height: ZadSpacing.lg),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'أشجاري (${view.myTrees.length})',
                style: ZadType.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => unawaited(_createTreeDialog(context, garden)),
              icon: const Icon(ZadIcons.add, size: 18),
              label: const Text('شجرة جديدة'),
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.sm),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: ZadSpacing.sm,
          crossAxisSpacing: ZadSpacing.sm,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            for (final t in view.myTrees)
              _TreeMiniCard(
                tree: t,
                selected: t.id == tree?.id,
                onTap: () => garden.select(t),
              ),
          ],
        ),
      ],
    );
  }
}

class _Particle {
  new(this.id, this.angle, this.distance, this.size, this.color);

  final int id;
  final double angle;
  final double distance;
  final double size;
  final Color color;
}

class _TreeDisplay extends StatefulWidget {
  const new({
    required this.tree,
    required this.onTap,
    required this.onReset,
    required this.onRename,
  });

  final GardenTree tree;
  final VoidCallback onTap;
  final VoidCallback onReset;
  final VoidCallback onRename;

  @override
  State<_TreeDisplay> createState() => _TreeDisplayState();
}

class _TreeDisplayState extends State<_TreeDisplay>
    with TickerProviderStateMixin {
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  late final AnimationController _leaves = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  final List<_Particle> _particles = <_Particle>[];
  final math.Random _rand = math.Random();
  int _particleId = 0;
  int _tapCount = 0;
  int _target = 33;
  double _glow = 0.3;
  bool _levelUp = false;
  Timer? _levelTimer;

  @override
  void didUpdateWidget(_TreeDisplay old) {
    super.didUpdateWidget(old);
    if (old.tree.id == widget.tree.id && widget.tree.level > old.tree.level) {
      unawaited(HapticFeedback.heavyImpact());
      setState(() => _levelUp = true);
      _levelTimer?.cancel();
      _levelTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _levelUp = false);
      });
    }
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    _sway.dispose();
    _loop.dispose();
    _leaves.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _tap() {
    _tapCount++;
    final count = _tapCount % 50 == 0 ? 8 : 4;
    const colors = <Color>[
      _gold,
      Color(0xFF4CAF50),
      Color(0xFF81C784),
      Color(0xFFFF9800),
    ];
    setState(() {
      _glow = 0.8;
      for (var i = 0; i < count; i++) {
        _particles.add(
          _Particle(
            ++_particleId,
            i * (360 / count) + _rand.nextDouble() * 20,
            40 + _rand.nextDouble() * 50,
            14 + _rand.nextDouble() * 10,
            colors[_rand.nextInt(4)],
          ),
        );
      }
      while (_particles.length > 20) {
        _particles.removeAt(0);
      }
    });
    _bounce.forward(from: 0);
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _glow = 0.3);
    });
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted && _particles.isNotEmpty) {
        setState(
          () => _particles.removeRange(0, math.min(count, _particles.length)),
        );
      }
    });
    unawaited(HapticFeedback.lightImpact());
    widget.onTap();
  }

  List<Color> get _levelBg {
    final l = widget.tree.level;
    if (l >= 5) {
      return <Color>[
        const Color(0xFFE8F5E9).withValues(alpha: 0.6),
        const Color(0xFFC8E6C9).withValues(alpha: 0.3),
      ];
    }
    if (l >= 4) {
      return <Color>[
        const Color(0xFFF1F8E9).withValues(alpha: 0.6),
        const Color(0xFFDCEDC8).withValues(alpha: 0.3),
      ];
    }
    if (l >= 3) {
      return <Color>[
        const Color(0xFFE8F5E9).withValues(alpha: 0.4),
        const Color(0xFFE0F2F1).withValues(alpha: 0.2),
      ];
    }
    if (l >= 2) {
      return <Color>[
        const Color(0xFFE0F2F1).withValues(alpha: 0.3),
        const Color(0xFFE8EAF6).withValues(alpha: 0.2),
      ];
    }
    return <Color>[
      ZadColors.mint100.withValues(alpha: 0.2),
      Colors.transparent,
    ];
  }

  Color get _accent => switch (widget.tree.treeType) {
    'golden' => _gold,
    'special' => _lilac,
    _ => _primary,
  };

  @override
  Widget build(BuildContext context) {
    final tree = widget.tree;
    final cycle = _target <= 0
        ? (tree.score % 100) / 100
        : (tree.score % _target) / _target;
    final leafCount = (tree.level - 1).clamp(0, 4);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: switch (tree.treeType) {
          'golden' => const Color(0xFFFFF8E1),
          'special' => const Color(0xFFF3E5F5),
          _ => ZadColors.surface,
        },
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: ZadColors.shadowSpot,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _levelBg,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              InkWell(
                onTap: widget.onRename,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(ZadSpacing.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (tree.treeType != 'normal') ...<Widget>[
                        Text(
                          tree.typeEmoji(),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: ZadSpacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          tree.treeName,
                          textAlign: TextAlign.center,
                          style: ZadType.titleLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(ZadIcons.edit, size: 18, color: _primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: ZadSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    tree.stageName(),
                    style: ZadType.bodyMedium.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                  if (tree.streakDays > 0) ...<Widget>[
                    const SizedBox(width: ZadSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _coral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${tree.streakDays} أيام',
                        style: ZadType.labelSmall.copyWith(
                          color: _coral,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              SizedBox.square(
                dimension: 240,
                child: AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[
                    _sway,
                    _loop,
                    _leaves,
                    _bounce,
                  ]),
                  builder: (context, _) => Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      // Pulsing glow ring.
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: _glow),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, g, _) => Container(
                          width: 180 + g * 40,
                          height: 180 + g * 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                _accent.withValues(alpha: g),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Falling leaves — more as the tree grows.
                      for (var i = 0; i < leafCount; i++)
                        () {
                          final phase = (_leaves.value + i / leafCount) % 1;
                          return Transform.translate(
                            offset: Offset(-50.0 + i * 34, -100 + phase * 190),
                            child: Opacity(
                              opacity: (1 - phase) * 0.7,
                              child: Transform.rotate(
                                angle: phase * math.pi,
                                child: const Text(
                                  '🍃',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          );
                        }(),
                      // Level-up burst.
                      if (_levelUp)
                        for (var i = 0; i < 8; i++)
                          () {
                            final a =
                                i * math.pi / 4 + _loop.value * 2 * math.pi;
                            return Transform.translate(
                              offset: Offset(
                                100 * math.cos(a),
                                100 * math.sin(a),
                              ),
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const <Color>[
                                    _gold,
                                    Color(0xFF4CAF50),
                                    Color(0xFFFF9800),
                                  ][i % 3],
                                ),
                              ),
                            );
                          }(),
                      // Tap particles.
                      for (final p in _particles)
                        _ParticleDot(key: ValueKey<int>(p.id), particle: p),
                      // Cycle ring.
                      SizedBox.square(
                        dimension: 220,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: cycle),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.fastOutSlowIn,
                          builder: (context, v, _) =>
                              CustomPaint(painter: _RingPainter(v)),
                        ),
                      ),
                      // The tree.
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _tap,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: <Color>[
                                  _primary.withValues(alpha: 0.1),
                                  ZadColors.mint100,
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    end: 0.82 + tree.progressToNext() * 0.35,
                                  ),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.fastOutSlowIn,
                                  builder: (context, growth, _) {
                                    final bounce =
                                        1 +
                                        0.4 *
                                            Curves.elasticOut.transform(
                                              1 - _bounce.value,
                                            ) *
                                            (_bounce.isAnimating ? 1 : 0);
                                    final sway =
                                        -3 +
                                        6 *
                                            Curves.fastOutSlowIn.transform(
                                              _sway.value,
                                            );
                                    final kick =
                                        8 *
                                        (1 - _bounce.value) *
                                        (_bounce.isAnimating ? 1 : 0);
                                    return Transform.rotate(
                                      angle: (sway + kick) * math.pi / 180,
                                      child: Transform.scale(
                                        scale:
                                            (_levelUp ? 1.4 : bounce) * growth,
                                        child: Text(
                                          tree.stageEmoji(),
                                          style: TextStyle(
                                            fontSize: _levelUp ? 56 : 40,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: ZadSpacing.xs),
                                Text(
                                  '${tree.score}',
                                  style: ZadType.headlineMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                                Text(
                                  'تسبيحة',
                                  style: ZadType.labelSmall.copyWith(
                                    color: ZadColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: ZadSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: tree.progressToNext(),
                  minHeight: 8,
                  color: _accent,
                  backgroundColor: ZadColors.ink.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                tree.level < 5
                    ? '${tree.score} / ${tree.nextLevelAt()} للمرحلة التالية'
                    : 'اكتملت!',
                style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.5, end: 1).animate(a),
                    child: child,
                  ),
                ),
                child: _levelUp
                    ? Padding(
                        key: const ValueKey<String>('up'),
                        padding: const EdgeInsets.only(top: ZadSpacing.sm),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.celebration,
                              size: 20,
                              color: _primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'مبروك! شجرتك كبرت!',
                              style: ZadType.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey<String>('none')),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _coral,
                        side: BorderSide(color: _coral.withValues(alpha: 0.7)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        unawaited(HapticFeedback.heavyImpact());
                        widget.onReset();
                      },
                      icon: const Icon(ZadIcons.retry, size: 18),
                      label: const Text(
                        'تصفير',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 68,
                    child: IconButton.filled(
                      tooltip: 'تسبيح',
                      style: IconButton.styleFrom(
                        backgroundColor: _primary,
                        elevation: 6,
                      ),
                      onPressed: _tap,
                      icon: const Icon(
                        ZadIcons.add,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Column(
                    children: <Widget>[
                      Text(
                        'المستوى',
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.xs),
                      Row(
                        children: <Widget>[
                          for (final (target, label) in const <(int, String)>[
                            (33, '٣٣'),
                            (100, '١٠٠'),
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: _CycleChip(
                                label: label,
                                selected: _target == target,
                                onTap: () => setState(() => _target = target),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleChip extends StatelessWidget {
  const new({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _primary : ZadColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected ? _primary : ZadColors.outline.withValues(alpha: 0.3),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          widthFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.sm),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? Colors.white : ZadColors.ink,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ParticleDot extends StatelessWidget {
  const new({required this.particle, super.key});

  final _Particle particle;

  @override
  Widget build(BuildContext context) {
    final rad = particle.angle * math.pi / 180;
    return Container(
          width: particle.size,
          height: particle.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: particle.color,
          ),
        )
        .animate()
        .move(
          end: Offset(
            particle.distance * math.cos(rad),
            particle.distance * math.sin(rad),
          ),
          duration: 600.ms,
          curve: Curves.easeOut,
        )
        .fadeOut(delay: 300.ms, duration: 300.ms);
  }
}

class _RingPainter extends CustomPainter {
  new(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = _primary.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    if (progress <= 0) return;
    final sweep = (progress * 2 * math.pi).clamp(0.01, 2 * math.pi);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          colors: <Color>[
            _primary,
            ZadColors.green600,
            ZadColors.mustardOchre,
            _primary,
          ],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _Stats extends StatelessWidget {
  const new({required this.tree});

  final GardenTree tree;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: <Widget>[
      _StatCard(
        label: 'المستوى',
        value: '${tree.level}/5',
        icon: const Icon(ZadIcons.tree, size: 20, color: _green),
      ),
      _StatCard(
        label: 'النقاط',
        value: '${tree.score}',
        icon: const Icon(ZadIcons.assistant, size: 20),
      ),
      _StatCard(
        label: 'إجمالي',
        value: '${tree.totalClicks}',
        icon: const Icon(Icons.touch_app, size: 20),
      ),
      _StatCard(
        label: 'السلسلة',
        value: '${tree.streakDays}',
        icon: const Icon(
          Icons.local_fire_department,
          size: 20,
          color: Color(0xFFFF5722),
        ),
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  const new({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final Widget icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZadColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: ZadColors.shadowSpot,
          blurRadius: 12,
          offset: Offset(0, 3),
        ),
        BoxShadow(color: ZadColors.shadowAmbient, blurRadius: 2),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: Column(
        children: <Widget>[
          icon,
          const SizedBox(height: ZadSpacing.xs),
          Text(
            value,
            style: ZadType.bodyLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
          ),
        ],
      ),
    ),
  );
}

class _TreeMiniCard extends StatelessWidget {
  const new({required this.tree, required this.selected, required this.onTap});

  final GardenTree tree;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ZadColors.surface,
    elevation: 2,
    shadowColor: ZadColors.shadowSpot,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: selected
          ? const BorderSide(color: _primary, width: 2)
          : BorderSide.none,
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(tree.stageEmoji(), style: const TextStyle(fontSize: 22)),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              tree.treeName.length > 8
                  ? tree.treeName.substring(0, 8)
                  : tree.treeName,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10),
            ),
            Text(
              '${tree.score}',
              style: const TextStyle(
                fontSize: 10,
                color: _primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Family garden ───────────────────────────────────────────────────────────

class _FamilyGardenTab extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyControllerProvider).family;
    final trees = ref.watch(
      tasbihaControllerProvider.select((v) => v.familyTrees),
    );
    final gardens = family == null
        ? const <MemberGarden>[]
        : memberGardens(family, trees);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZadSpacing.lg,
        ZadSpacing.lg,
        ZadSpacing.lg,
        120,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(ZadIcons.leaderboard, size: 28, color: _gold),
            const SizedBox(width: ZadSpacing.sm),
            Expanded(
              child: Text(
                'لوحة المتصدرين',
                style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (gardens.isNotEmpty)
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => unawaited(shareLeaderboard(gardens)),
                icon: const Icon(ZadIcons.share, size: 18),
                label: const Text('شارك الترتيب'),
              ),
          ],
        ),
        const SizedBox(height: ZadSpacing.lg),
        if (gardens.isEmpty)
          const ZadEmptyState(
            icon: ZadIcons.tree,
            title: 'لا توجد أشجار بعد',
            message: 'أول ما حد من العيلة يسبّح، شجرته هتظهر هنا.',
          )
        else
          for (final (i, g) in gardens.indexed) ...<Widget>[
            _MemberCard(garden: g, rank: i + 1),
            const SizedBox(height: ZadSpacing.sm),
          ],
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const new({required this.garden, required this.rank});

  final MemberGarden garden;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final alias = garden.member.alias;
    final streak = longestStreak(garden.trees);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZadColors.surface,
        borderRadius: BorderRadius.circular(ZadRadii.card),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: ZadColors.shadowSpot,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary.withValues(alpha: 0.2),
                  ),
                  child: Text(
                    alias.isEmpty ? '؟' : alias.characters.first,
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        rank <= 3 ? '${medal(rank)} $alias' : alias,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${garden.trees.length} أشجار | '
                        '${garden.matureTrees} مثمرة',
                        style: ZadType.bodySmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                      if (streak > 0)
                        Text(
                          '🔥 $streak يوم ورا بعض',
                          style: ZadType.bodySmall.copyWith(color: _primary),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${garden.totalScore}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _primary,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'تسبيحة',
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (garden.trees.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    for (final t in garden.trees.take(5))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: ZadSpacing.sm,
                        ),
                        child: _MiniTree(tree: t),
                      ),
                    if (garden.trees.length > 5)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ZadSpacing.md,
                            vertical: ZadSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${garden.trees.length - 5}',
                            style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniTree extends StatelessWidget {
  const new({required this.tree});

  final GardenTree tree;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZadColors.surfaceLow,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.all(ZadSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(tree.stageEmoji(), style: const TextStyle(fontSize: 18)),
          Text(
            tree.treeName.length > 6
                ? tree.treeName.substring(0, 6)
                : tree.treeName,
            maxLines: 1,
            style: const TextStyle(fontSize: 8),
          ),
          Text(
            '${tree.score}',
            style: const TextStyle(
              fontSize: 8,
              color: _primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Challenges ──────────────────────────────────────────────────────────────

class _ChallengesTab extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(familyControllerProvider).isAdmin;
    final view = ref.watch(tasbihaControllerProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZadSpacing.lg,
        ZadSpacing.lg,
        ZadSpacing.lg,
        120,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.track_changes, size: 24, color: _primary),
            const SizedBox(width: ZadSpacing.sm),
            Expanded(
              child: Text(
                'التحديات العائلية',
                style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (isAdmin)
              IconButton(
                tooltip: 'تحدي جديد',
                onPressed: () =>
                    unawaited(_createChallengeDialog(context, ref)),
                icon: const Icon(ZadIcons.add, color: _primary),
              ),
          ],
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          'تحدَ أفراد عائلتك في التسبيحة!',
          style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.lg),
        if (view.challenges.isEmpty)
          ZadEmptyState(
            icon: Icons.track_changes,
            title: 'لا توجد تحديات حالياً',
            message: isAdmin
                ? 'اضغط + وابدأ أول تحدي للعيلة.'
                : 'اطلب من المدير إنشاء تحدي جديد!',
          )
        else
          for (final c in view.challenges) ...<Widget>[
            _ChallengeCard(challenge: c, clicks: view.progress[c.id] ?? 0),
            const SizedBox(height: ZadSpacing.sm),
          ],
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const new({required this.challenge, required this.clicks});

  final TasbihaChallenge challenge;
  final int clicks;

  @override
  Widget build(BuildContext context) {
    final target = challenge.targetClicks < 1 ? 1 : challenge.targetClicks;
    final fraction = (clicks / target).clamp(0.0, 1.0);
    final end = challenge.endDate;
    final until = end == null
        ? 'مستمر'
        : end.substring(0, math.min(10, end.length));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZadColors.surface,
        borderRadius: BorderRadius.circular(ZadRadii.card),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: ZadColors.shadowSpot,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    challenge.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    challenge.challengeType,
                    style: ZadType.labelSmall.copyWith(
                      color: _primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (challenge.description case final d?) ...<Widget>[
              const SizedBox(height: ZadSpacing.sm),
              Text(
                d,
                style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
              ),
            ],
            const SizedBox(height: ZadSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                color: fraction >= 1 ? ZadColors.green600 : _primary,
                backgroundColor: _primary.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$clicks من ${challenge.targetClicks} تسبيحة',
                    style: ZadType.labelMedium.copyWith(color: _primary),
                  ),
                ),
                Text(
                  '⏰ $until',
                  style: ZadType.labelMedium.copyWith(
                    color: ZadColors.inkMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialogs ─────────────────────────────────────────────────────────────────

Future<void> _renameDialog(
  BuildContext context,
  TasbihaController garden,
  GardenTree tree,
) async {
  final name = TextEditingController(text: tree.treeName);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تسمية الشجرة'),
      content: TextField(
        controller: name,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'اسم الشجرة',
          border: OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () {
            final v = name.text.trim();
            if (v.isNotEmpty) Navigator.of(dialogContext).pop(v);
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  name.dispose();
  if (result != null) await garden.rename(result);
}

Future<void> _createTreeDialog(
  BuildContext context,
  TasbihaController garden,
) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => const _CreateTreeDialog(),
  );
  if (result != null) await garden.createTree(result);
}

class _CreateTreeDialog extends StatefulWidget {
  const new();

  @override
  State<_CreateTreeDialog> createState() => _CreateTreeDialogState();
}

class _CreateTreeDialogState extends State<_CreateTreeDialog> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('شجرة جديدة'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'أضف شجرة جديدة لبستانك!',
          style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.md),
        TextField(
          controller: _name,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'اسم الشجرة',
            hintText: 'مثال: شجرة التفاح',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      TextButton(
        onPressed: _name.text.trim().isEmpty
            ? null
            : () => Navigator.of(context).pop(_name.text.trim()),
        child: const Text('إضافة'),
      ),
    ],
  );
}

Future<void> _createChallengeDialog(BuildContext context, WidgetRef ref) async {
  final result = await showDialog<(String, String?, String, int)>(
    context: context,
    builder: (_) => const _CreateChallengeDialog(),
  );
  if (result == null) return;
  await ref
      .read(tasbihaControllerProvider.notifier)
      .createChallenge(
        title: result.$1,
        description: result.$2,
        challengeType: result.$3,
        targetClicks: result.$4,
      );
}

class _CreateChallengeDialog extends StatefulWidget {
  const new();

  @override
  State<_CreateChallengeDialog> createState() => _CreateChallengeDialogState();
}

class _CreateChallengeDialogState extends State<_CreateChallengeDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _target = TextEditingController(text: '100');
  String _type = 'weekly';

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'تحدي جديد',
      style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'عنوان التحدي',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'الوصف (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'الهدف (عدد التسبيحات)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          Row(
            children: <Widget>[
              for (final t in const <String>['weekly', 'monthly'])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: ZadSpacing.sm),
                  child: FilterChip(
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                    label: Text(t),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: _title.text.trim().isEmpty
            ? null
            : () {
                final d = _description.text.trim();
                Navigator.of(context).pop((
                  _title.text.trim(),
                  d.isEmpty ? null : d,
                  _type,
                  int.tryParse(_target.text) ?? 100,
                ));
              },
        child: const Text('حفظ'),
      ),
    ],
  );
}
