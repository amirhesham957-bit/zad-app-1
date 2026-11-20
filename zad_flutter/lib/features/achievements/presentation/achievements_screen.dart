/// Kotlin's `AchievementsRoute`/`AchievementsScreen` as a world: the trophy
/// shelf, the level and its points, the next achievement, and the catalogue
/// — earned in colour with their date, the rest as grey silhouettes. Two
/// direct reads, no model call — the same as Kotlin.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lottie/lottie.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/achievements/domain/achievements.dart';
import 'package:zad/features/achievements/presentation/achievements_world_scene.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the achievements.
Future<void> showAchievementsScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AchievementsScreen()),
    );

/// The achievements.
class AchievementsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key, this.loadForTest});

  /// A test supplies the data instead of the two reads.
  @visibleForTesting
  final Future<(AchievementStats, List<AchievementView>)> Function()?
  loadForTest;

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsState();
}

class _AchievementsState extends ConsumerState<AchievementsScreen> {
  late Future<(AchievementStats, List<AchievementView>)> _load = _fetch();

  Future<(AchievementStats, List<AchievementView>)> _fetch() async {
    if (widget.loadForTest case final test?) return await test();
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return buildAchievements(
        unlocked: const <UnlockedRow>[],
        contributions: 0,
        streak: 0,
      );
    }
    final rows = await client
        .from('user_achievements')
        .select('achievement_id, points_earned, unlocked_at')
        .eq('user_id', userId);
    final stamps = await client
        .from('price_index')
        .select('timestamp')
        .eq('user_id', userId)
        .eq('source', 'crowdsource')
        .order('timestamp', ascending: false);
    final last = stamps.isEmpty
        ? null
        : DateTime.tryParse('${stamps.first['timestamp']}');
    return buildAchievements(
      unlocked: <UnlockedRow>[
        for (final r in rows)
          (
            achievementId: '${r['achievement_id']}',
            points: (r['points_earned'] as num?)?.toInt() ?? 0,
          ),
      ],
      unlockedAt: <String, DateTime>{
        for (final r in rows)
          '${r['achievement_id']}': ?DateTime.tryParse('${r['unlocked_at']}'),
      },
      contributions: stamps.length,
      streak: contributionStreak(last, ref.read(nowProvider)()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: ZadColors.canvasMid,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<(AchievementStats, List<AchievementView>)>(
          future: _load,
          builder: (context, snap) {
            final data = snap.data;
            final done = snap.connectionState == ConnectionState.done;
            final failed = done && (snap.hasError || data == null);
            final ready = done && !failed;
            return ZadWorldScaffold(
              world: ZadWorld.ach,
              title: l.worldLabelAch,
              stateLine: ready
                  ? l.achWorldState(
                      data!.$1.unlocked,
                      kAchievementCatalog.length,
                    )
                  : null,
              scene: (loop) => AchievementsWorldScene(
                loop,
                unlocked: ready ? data!.$1.unlocked : 0,
                total: kAchievementCatalog.length,
              ),
              zado: ZadWorldZado(
                state: ready && data!.$1.unlocked > 0
                    ? CompanionState.happy
                    : CompanionState.idle,
              ),
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZadSpacing.gutter,
                  ),
                  sliver: SliverList.list(
                    children: <Widget>[
                      if (!done)
                        const Padding(
                          padding: EdgeInsets.all(ZadSpacing.xl),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (failed)
                        ZadEmptyState(
                          icon: Icons.cloud_off,
                          title: l.achLoadFailed,
                          message: l.achLoadFailedHint,
                          action: FilledButton(
                            onPressed: () => setState(() {
                              _load = _fetch();
                            }),
                            child: Text(l.achRetry),
                          ),
                        )
                      else
                        ..._body(context, data!.$1, data.$2),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    AchievementStats stats,
    List<AchievementView> items,
  ) {
    final l = context.l10n;
    final gold = ZadWorld.ach.color;
    final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    final lang = Localizations.localeOf(context).languageCode;
    String dateOf(DateTime at) => DateFormat(
      'd MMMM y',
      lang,
    ).format(tz.TZDateTime.from(at.toUtc(), zone));
    return <Widget>[
      ZadWorldCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ZadWorldRow(
              leading: ZadWorldTile(
                color: gold,
                child: ZadArt.icon(ZadIconArt.star, size: 28),
              ),
              title: l.achLevel(stats.level),
              subtitle: l.achLevelPoints(stats.totalPoints, stats.level * 100),
              stateColor: gold,
              progress: (stats.totalPoints % 100) / 100,
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              l.achOnTrack,
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ),
      ),
      const SizedBox(height: ZadSpacing.md),
      ZadWorldCard(
        child: Row(
          children: <Widget>[
            _Stat(l.achContributions, '${stats.contributions}'),
            _Stat(l.achStreak, '${stats.streak}'),
            _Stat(l.achShelf, '${stats.unlocked}'),
          ],
        ),
      ),
      if (stats.nextName != null && stats.nextProgress != null) ...<Widget>[
        const SizedBox(height: ZadSpacing.md),
        ZadWorldCard(
          child: ZadWorldRow(
            leading: ZadWorldTile(
              color: gold,
              child: ZadArt.icon(ZadIconArt.star, size: 28),
            ),
            title: stats.nextName!,
            subtitle: '${l.achNext} · ${stats.nextProgress!}',
            stateColor: ZadColors.inkMuted,
          ),
        ),
      ],
      const SizedBox(height: ZadSpacing.lg),
      Padding(
        padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
        child: Text(
          l.achShelf,
          style: ZadType.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: ZadColors.ink,
          ),
        ),
      ),
      ZadWorldCard(
        child: Column(
          children: <Widget>[
            for (final (i, a) in items.indexed) ...<Widget>[
              if (i > 0) const ZadWorldDivider(),
              _AchievementRow(
                item: a,
                subtitle: a.unlocked
                    ? (a.at == null ? a.def.description : dateOf(a.at!))
                    : l.achLocked,
              ),
            ],
          ],
        ),
      ),
    ];
  }
}

class _Stat extends StatelessWidget {
  const new(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: <Widget>[
        Text(value, style: ZadType.titleLarge),
        Text(
          label,
          textAlign: TextAlign.center,
          style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
        ),
      ],
    ),
  );
}

/// One catalogue entry: its badge, its name and what it says (the date when
/// earned, «مقفول» when not), and its points.
class _AchievementRow extends StatelessWidget {
  const new({required this.item, required this.subtitle});

  final AchievementView item;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final gold = ZadWorld.ach.color;
    return Tooltip(
      message: item.def.description,
      child: ZadWorldRow(
        leading: ZadWorldTile(
          color: item.unlocked ? gold : ZadColors.inkMuted,
          size: 52,
          child: AchievementBadge(def: item.def, unlocked: item.unlocked),
        ),
        title: item.def.name,
        subtitle: subtitle,
        stateColor: item.unlocked ? ZadColors.ink : ZadColors.inkMuted,
        trailing: item.unlocked
            ? Text(
                '+${item.def.points}',
                style: ZadType.labelMedium.copyWith(
                  color: ZadColors.inkMuted,
                  fontWeight: FontWeight.w800,
                ),
              )
            : null,
      ),
    );
  }
}

/// A flat grey silhouette, for a badge not yet earned.
const ColorFilter _silhouette = ColorFilter.mode(
  Color(0xFFADB5BF),
  BlendMode.srcIn,
);

/// A badge's picture: its Lottie looping once earned, held on its first frame
/// and a grey silhouette while locked, and the catalogue's emoji if the file
/// cannot load.
/// Still whenever the system asks for reduced motion.
class AchievementBadge extends StatelessWidget {
  /// Creates the badge.
  const new({required this.def, required this.unlocked, super.key});

  /// The catalogue entry drawn.
  final AchievementDef def;

  /// Whether the customer has earned it.
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final picture = Lottie.asset(
      def.lottieAsset,
      width: 44,
      height: 44,
      animate: unlocked && !MediaQuery.disableAnimationsOf(context),
      errorBuilder: (_, _, _) =>
          Text(def.icon, style: const TextStyle(fontSize: 32)),
    );
    if (unlocked) return picture;
    return ColorFiltered(colorFilter: _silhouette, child: picture);
  }
}
