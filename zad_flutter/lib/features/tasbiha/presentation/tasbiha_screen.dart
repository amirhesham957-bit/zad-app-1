/// بستان التسبيح (owner, 15/11): green, a painted garden under the day or
/// night sky of the account's own time zone. Every 33 counts a flower blooms
/// on the ground and every 99 the tree grows a stage. The big bead is docked
/// in the thumb zone; the family's trees (shareable as an image) and the
/// challenges are the other two tabs.
///
/// Every finished wird of 33 reports to the server's `zad_game_reward` for
/// seeds — the server owns the ledger and the daily allowance.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/tasbiha/presentation/tasbiha_dialogs.dart';
import 'package:zad/features/tasbiha/presentation/tasbiha_dock.dart';
import 'package:zad/features/tasbiha/presentation/tasbiha_family_tabs.dart';
import 'package:zad/features/tasbiha/presentation/tasbiha_garden_scene.dart';
import 'package:zad/features/tasbiha/presentation/tasbiha_my_garden.dart';
import 'package:zad/shared/companion/data/game_reward_remote.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/sound/ui_sounds.dart';
import 'package:zad/shared/tasbiha/application/tasbiha_controller.dart';
import 'package:zad/shared/tasbiha/domain/tasbiha.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// The server's id for this game in `zad_game_reward` (divisor 33).
const String kTasbihaGameId = 'tasbih_garden';

/// Counts that make one wird, and so one flower.
const int kWird = 33;

/// Opens the garden.
Future<void> showTasbihaScreen(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const TasbihaScreen()));

/// Whether it is night where the account lives (18:00 to 05:00).
bool tasbihaIsNight(DateTime now, String zone) {
  try {
    final h = tz.TZDateTime.from(now.toUtc(), tz.getLocation(zone)).hour;
    return h >= 18 || h < 5;
  } on Object {
    return now.hour >= 18 || now.hour < 5;
  }
}

/// The garden.
class TasbihaScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<TasbihaScreen> createState() => _TasbihaScreenState();
}

class _TasbihaScreenState extends ConsumerState<TasbihaScreen>
    with TickerProviderStateMixin {
  /// The newest flower opening / the tap's hop: 0..1, resting at 1.
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  int _tab = 0;
  int _cycle = 33;
  int _session = 0;
  int _unreported = 0;
  String? _message;
  Timer? _messageTimer;

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
  void dispose() {
    _messageTimer?.cancel();
    _bloom.dispose();
    _pulse.dispose();
    super.dispose();
  }

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _say(String text) {
    setState(() => _message = text);
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _message = null);
    });
  }

  void _tap() {
    final garden = ref.read(tasbihaControllerProvider.notifier);
    final before = ref.read(tasbihaControllerProvider).selected;
    garden.tap();
    final after = ref.read(tasbihaControllerProvider).selected;
    if (before == null || after == null) return;
    unawaited(HapticFeedback.lightImpact());
    if (!_still) _pulse.forward(from: 0);
    _session++;
    _unreported++;
    final l = context.l10n;
    if (before.id == after.id && after.level > before.level) {
      ref.read(uiSoundsProvider.notifier).play(UiSound.achieve);
      unawaited(HapticFeedback.heavyImpact());
      if (!_still) _bloom.forward(from: 0);
      _say(l.tasLevelUp);
    } else if (flowersOf(after.score) > flowersOf(before.score)) {
      unawaited(HapticFeedback.mediumImpact());
      if (!_still) _bloom.forward(from: 0);
      _say(l.tasBloom);
    }
    if (_unreported >= kWird) unawaited(_grantSeeds());
  }

  /// A finished wird goes to the server, which grants the seeds. Whole
  /// wirds only; the remainder waits for the next one. Offline or refused,
  /// nothing is queued and nothing is shown.
  Future<void> _grantSeeds() async {
    final score = (_unreported ~/ kWird) * kWird;
    _unreported -= score;
    try {
      final grant = await ref
          .read(gameRewardRepositoryProvider)
          .report(kTasbihaGameId, score);
      if (!mounted || grant == null || grant.granted <= 0) return;
      _say(context.l10n.tasSeedsGranted(grant.granted));
    } on Object catch (e) {
      debugPrint('Tasbiha seeds failed: $e');
    }
  }

  void _reset() {
    unawaited(HapticFeedback.heavyImpact());
    ref.read(tasbihaControllerProvider.notifier).reset();
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
    final l = context.l10n;
    final view = ref.watch(tasbihaControllerProvider);
    final garden = ref.read(tasbihaControllerProvider.notifier);
    final tree = view.selected;
    final zone = ref.watch(accountTimeZoneProvider);
    final night = tasbihaIsNight(ref.read(nowProvider)(), zone);
    final score = tree?.score ?? 0;
    final flowers = flowersOf(score);
    final counting = _tab == 0 && tree != null;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final celebrating = _message != null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ZadWorldScaffold(
        world: ZadWorld.tas,
        eyebrow: l.tasEyebrow,
        title: l.tasbihaGarden,
        stateLine: tree == null || score == 0
            ? l.tasStateEmpty
            : l.tasStateLine(score, flowers),
        zado: ZadWorldZado(
          left: 24,
          top: 44,
          size: 140,
          state: celebrating
              ? CompanionState.celebrating
              : night
              ? CompanionState.sleepy
              : CompanionState.happy,
        ),
        scene: (loop) => TasbihaGardenScene(
          loop,
          level: tree?.level ?? 1,
          flowers: flowers,
          night: night,
          bloom: _bloom,
          pulse: _pulse,
          accent: switch (tree?.treeType) {
            'golden' => const Color(0xFFFFD700),
            'special' => const Color(0xFF9C27B0),
            _ => const Color(0xFFE53935),
          },
        ),
        dockHeight: counting ? kTasbihaDockHeight + inset : 0,
        overlay: counting
            ? TasbihaDock(
                score: score,
                cycle: _cycle,
                message: _message,
                onTap: _tap,
                onReset: _reset,
                onCycle: (c) => setState(() => _cycle = c),
              )
            : null,
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.gutter,
              ZadSpacing.lg,
              ZadSpacing.gutter,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 0, label: Text(l.tasTabMine)),
                    ButtonSegment<int>(value: 1, label: Text(l.tasTabFamily)),
                    ButtonSegment<int>(
                      value: 2,
                      label: Text(l.tasTabChallenges),
                    ),
                  ],
                  selected: <int>{_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
                const SizedBox(height: ZadSpacing.lg),
                if (view.isLoading && view.myTrees.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(ZadSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  ..._body(context, view, garden, tree),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    TasbihaView view,
    TasbihaController garden,
    GardenTree? tree,
  ) {
    final l = context.l10n;
    return switch (_tab) {
      0 => <Widget>[
        if (tree == null)
          ZadWorldCard(
            child: ZadEmptyState(
              icon: ZadIcons.tree,
              title: l.tasNoTreeTitle,
              message: l.tasNoTreeMsg,
              action: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ZadWorldColors.tasbih,
                  minimumSize: const Size(44, 44),
                ),
                onPressed: () =>
                    unawaited(showCreateTreeDialog(context, garden)),
                child: Text(l.tasNewTree),
              ),
            ),
          )
        else ...<Widget>[
          TasbihaDhikrChips(
            current: tree.treeName,
            onPick: (d) => unawaited(garden.rename(d)),
          ),
          const SizedBox(height: ZadSpacing.md),
          TasbihaTreeCard(
            tree: tree,
            sessionTaps: _session,
            onRename: () =>
                unawaited(showRenameTreeDialog(context, garden, tree)),
          ),
          const SizedBox(height: ZadSpacing.md),
          TasbihaMyTrees(
            trees: view.myTrees,
            selectedId: tree.id,
            onSelect: garden.select,
            onNew: () => unawaited(showCreateTreeDialog(context, garden)),
          ),
        ],
      ],
      1 => const <Widget>[TasbihaFamilyTab()],
      _ => const <Widget>[TasbihaChallengesTab()],
    };
  }
}
