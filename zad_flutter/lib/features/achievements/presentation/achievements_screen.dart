/// Kotlin's `AchievementsRoute`/`AchievementsScreen`: the emerald level card,
/// three mini stats, the next achievement, and the catalogue as a 3-column
/// grid. Two direct reads, no model call — the same as Kotlin.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/features/achievements/domain/achievements.dart';

/// Opens the achievements.
Future<void> showAchievementsScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AchievementsScreen()),
    );

const Color _ink = Color(0xFF0F172A);
const Color _slate = Color(0xFF475569);

/// The achievements.
class AchievementsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsState();
}

class _AchievementsState extends ConsumerState<AchievementsScreen> {
  late Future<(AchievementStats, List<AchievementView>)> _load = _fetch();

  Future<(AchievementStats, List<AchievementView>)> _fetch() async {
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
        .select('achievement_id, points_earned')
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
      contributions: stamps.length,
      streak: contributionStreak(last, ref.read(nowProvider)()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ZadColors.canvasMid,
    appBar: AppBar(
      backgroundColor: ZadColors.canvasMid,
      title: const Text('الإنجازات والرتب'),
    ),
    body: FutureBuilder<(AchievementStats, List<AchievementView>)>(
      future: _load,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data;
        if (snap.hasError || data == null) {
          return ZadEmptyState(
            icon: Icons.cloud_off,
            title: 'تعذر حفظ التغييرات',
            message: 'تحقق من الاتصال وحاول مرة أخرى',
            action: FilledButton(
              onPressed: () => setState(() => _load = _fetch()),
              child: const Text('إعادة المحاولة'),
            ),
          );
        }
        return _Body(stats: data.$1, achievements: data.$2);
      },
    ),
  );
}

class _Body extends StatelessWidget {
  const new({required this.stats, required this.achievements});

  final AchievementStats stats;
  final List<AchievementView> achievements;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      ZadSpacing.lg,
      ZadSpacing.sm,
      ZadSpacing.lg,
      96,
    ),
    children: <Widget>[
      _LevelCard(stats),
      const SizedBox(height: ZadSpacing.lg),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.sm),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _MiniStat('المساهمات', '${stats.contributions}', '📊'),
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(child: _MiniStat('التسلسل', '${stats.streak}🔥', '⚡')),
            const SizedBox(width: ZadSpacing.md),
            Expanded(child: _MiniStat('الإنجازات', '${stats.unlocked}', '🏆')),
          ],
        ),
      ),
      if (stats.nextName != null && stats.nextProgress != null) ...<Widget>[
        const SizedBox(height: ZadSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.sm),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: ZadColors.mustardOchre.withValues(alpha: 0.1),
              shape: zadSquircle(
                ZadRadii.card,
                side: BorderSide(
                  width: 0.5,
                  color: ZadColors.mustardOchre.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(ZadSpacing.md),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.emoji_events,
                    size: 24,
                    color: ZadColors.mustardOchre,
                  ),
                  const SizedBox(width: ZadSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'الإنجاز التالي',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ZadColors.mustardOchre,
                          ),
                        ),
                        Text(
                          stats.nextName!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        Text(
                          stats.nextProgress!,
                          style: const TextStyle(fontSize: 12, color: _slate),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: ZadSpacing.lg),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: ZadSpacing.sm),
        child: Text(
          'الإنجازات',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ),
      const SizedBox(height: ZadSpacing.lg),
      GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: ZadSpacing.md,
        crossAxisSpacing: ZadSpacing.md,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[for (final a in achievements) _AchievementCard(a)],
      ),
    ],
  );
}

class _LevelCard extends StatelessWidget {
  const new(this.stats);

  final AchievementStats stats;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: ZadColors.forestEmerald,
      shape: zadSquircle(ZadRadii.card),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 80,
            child: Column(
              children: <Widget>[
                Text(
                  'المستوى',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  '${stats.level}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: ZadSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'أنت على الطريق الصحيح!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: ZadSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: ((stats.totalPoints % 100) / 100).clamp(0, 1),
                    ),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(height: ZadSpacing.sm),
                Text(
                  '${stats.totalPoints} من ${stats.level * 100} نقطة',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const new(this.label, this.value, this.icon);

  final String label;
  final String value;
  final String icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 80,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: ZadColors.surface,
        shape: zadSquircle(
          ZadRadii.card,
          side: const BorderSide(width: 0.5, color: ZadColors.hairline),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ZadColors.forestEmerald,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 10, color: _slate)),
        ],
      ),
    ),
  );
}

class _AchievementCard extends StatelessWidget {
  const new(this.item);

  final AchievementView item;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: item.def.description,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: item.unlocked ? ZadColors.surface : const Color(0xFFF1F5F9),
        shape: zadSquircle(
          ZadRadii.card,
          side: item.unlocked
              ? BorderSide(width: 2, color: ZadColors.mustardOchre)
              : const BorderSide(width: 0.5, color: ZadColors.hairline),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.xs),
              child: Text(item.def.icon, style: const TextStyle(fontSize: 32)),
            ),
            Text(
              item.def.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              item.unlocked ? '+${item.def.points}' : 'مقفول',
              style: TextStyle(
                fontSize: item.unlocked ? 10 : 9,
                fontWeight: item.unlocked ? FontWeight.w600 : FontWeight.w400,
                color: item.unlocked
                    ? ZadColors.mustardOchre
                    : const Color(0xFFA1A5AB),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
