/// بستان التسبيحة — Kotlin's `TasbihaTree`, `TasbihaChallenge`,
/// `TasbihaChallengeProgress`, `FamilyMemberWithTasbiha` and
/// `TasbihaLeaderboard`, with the same stage thresholds, names and emoji.
library;

import 'package:zad/features/family/domain/family.dart';

/// One tree, a full `family_tasbiha` row.
class GardenTree {
  /// Creates a tree.
  const new({
    required this.id,
    required this.familyId,
    required this.userId,
    this.treeName = 'بذرة',
    this.treeType = 'normal',
    this.level = 1,
    this.score = 0,
    this.totalClicks = 0,
    this.lastTasbihAt,
    this.gardenName = 'بستاني',
    this.isMature = false,
    this.maturedAt,
    this.streakDays = 0,
    this.lastStreakDate,
  });

  /// Reads a row.
  factory fromJson(Map<String, dynamic> j) => GardenTree(
    id: '${j['id']}',
    familyId: '${j['family_id'] ?? ''}',
    userId: '${j['user_id'] ?? ''}',
    treeName: (j['tree_name'] as String?) ?? 'بذرة',
    treeType: (j['tree_type'] as String?) ?? 'normal',
    level: (j['level'] as num?)?.toInt() ?? 1,
    score: (j['score'] as num?)?.toInt() ?? 0,
    totalClicks: (j['total_clicks'] as num?)?.toInt() ?? 0,
    lastTasbihAt: j['last_tasbih_at'] as String?,
    gardenName: (j['garden_name'] as String?) ?? 'بستاني',
    isMature: (j['is_mature'] as bool?) ?? false,
    maturedAt: j['matured_at'] as String?,
    streakDays: (j['streak_days'] as num?)?.toInt() ?? 0,
    lastStreakDate: j['last_streak_date'] as String?,
  );

  /// Row id.
  final String id;

  /// Family.
  final String familyId;

  /// Owner (auth user id).
  final String userId;

  /// The dhikr it counts.
  final String treeName;

  /// `normal`, `special` or `golden`.
  final String treeType;

  /// 1..5.
  final int level;

  /// Taps since the last reset.
  final int score;

  /// Every tap ever.
  final int totalClicks;

  /// Last tap, ISO.
  final String? lastTasbihAt;

  /// Garden label.
  final String gardenName;

  /// Reached level 5.
  final bool isMature;

  /// When it did.
  final String? maturedAt;

  /// Consecutive days.
  final int streakDays;

  /// `yyyy-MM-dd` of the streak's last day.
  final String? lastStreakDate;

  /// A copy with fields replaced.
  GardenTree copyWith({
    String? treeName,
    int? level,
    int? score,
    int? totalClicks,
    String? lastTasbihAt,
    bool? isMature,
    String? maturedAt,
    int? streakDays,
    String? lastStreakDate,
  }) => GardenTree(
    id: id,
    familyId: familyId,
    userId: userId,
    treeName: treeName ?? this.treeName,
    treeType: treeType,
    level: level ?? this.level,
    score: score ?? this.score,
    totalClicks: totalClicks ?? this.totalClicks,
    lastTasbihAt: lastTasbihAt ?? this.lastTasbihAt,
    gardenName: gardenName,
    isMature: isMature ?? this.isMature,
    maturedAt: maturedAt ?? this.maturedAt,
    streakDays: streakDays ?? this.streakDays,
    lastStreakDate: lastStreakDate ?? this.lastStreakDate,
  );

  /// Score for the next stage.
  int nextLevelAt() => switch (level) {
    1 => 99,
    2 => 198,
    3 => 297,
    4 => 396,
    _ => 1 << 31,
  };

  /// 0..1 towards the next stage.
  double progressToNext() =>
      level >= 5 ? 1 : (score / nextLevelAt()).clamp(0.0, 1.0);

  /// The stage's emoji.
  String stageEmoji() {
    if (level >= 5 && treeType == 'golden') return '🌟🌳🌸';
    if (level >= 5 && treeType == 'special') return '💎🌳🌸';
    if (level >= 5) return '🌳🌸';
    if (level == 4 && treeType == 'golden') return '🌟🌳';
    if (level == 4 && treeType == 'special') return '💎🌳';
    if (level == 4) return '🌳';
    if (level == 3) return '🌿';
    if (level == 2) return '🌱';
    return '🌰';
  }

  /// The stage's name.
  String stageName() => switch (level) {
    >= 5 => 'مثمرة 🍎',
    4 => 'شجرة 🌳',
    3 => 'شتلة 🌿',
    2 => 'بذرة نبتت 🌱',
    _ => 'بذرة 🌰',
  };

  /// The type's badge.
  String typeEmoji() => switch (treeType) {
    'golden' => '⭐',
    'special' => '💎',
    _ => '',
  };
}

/// A family challenge.
typedef TasbihaChallenge = ({
  String id,
  String title,
  String? description,
  String challengeType,
  int targetClicks,
  String? endDate,
});

/// Reads a `family_tasbiha_challenges` row.
TasbihaChallenge challengeFromJson(Map<String, dynamic> j) => (
  id: '${j['id']}',
  title: (j['title'] as String?) ?? '',
  description: j['description'] as String?,
  challengeType: (j['challenge_type'] as String?) ?? 'weekly',
  targetClicks: (j['target_clicks'] as num?)?.toInt() ?? 100,
  endDate: j['end_date'] as String?,
);

/// One member's garden.
typedef MemberGarden = ({
  FamilyMember member,
  List<GardenTree> trees,
  int totalScore,
  int matureTrees,
});

/// Kotlin's `getFamilyMembersWithTrees`: every member with their trees,
/// highest total first.
List<MemberGarden> memberGardens(Family family, List<GardenTree> trees) {
  final out = <MemberGarden>[
    for (final m in family.members)
      () {
        final mine = trees.where((t) => t.userId == m.userId).toList();
        return (
          member: m,
          trees: mine,
          totalScore: mine.fold<int>(0, (s, t) => s + t.score),
          matureTrees: mine.where((t) => t.isMature).length,
        );
      }(),
  ]..sort((a, b) => b.totalScore.compareTo(a.totalScore));
  return out;
}

/// The longest streak on any of [trees].
int longestStreak(List<GardenTree> trees) =>
    trees.fold<int>(0, (m, t) => t.streakDays > m ? t.streakDays : m);

/// `TasbihaLeaderboard.medal`.
String medal(int rank) => switch (rank) {
  1 => '🥇',
  2 => '🥈',
  3 => '🥉',
  _ => '$rank',
};

/// The seven quick dhikr chips.
const List<String> kQuickDhikrs = <String>[
  'سبحان الله',
  'الحمد لله',
  'لا إله إلا الله',
  'الله أكبر',
  'أستغفر الله',
  'لا حول ولا قوة إلا بالله',
  'اللهم صل وسلم على نبينا محمد',
];
