/// Kotlin's `KidsModeContent` (HomeScreen.kt): a playful home for a child —
/// avatar greeting, the candy-gradient allowance card with the savings goal
/// and today's limit, «محتاج مصروف زيادة؟» (a purchase request a parent
/// approves), my chores, three badges, and the last family messages.
///
/// Kids mode's gradients and emoji are deliberate (CLAUDE.md) — this screen
/// keeps its own colours and does not share them.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/application/family_life_controller.dart';
import 'package:zad/features/family/domain/family.dart';
import 'package:zad/features/family/domain/family_life.dart';
import 'package:zad/features/family/presentation/family_dialogs.dart';
import 'package:zad/features/tasbiha/application/tasbiha_controller.dart';
import 'package:zad/features/tasbiha/presentation/tasbiha_screen.dart';

const Color _kidsPrimary = Color(0xFF6B46C1);
const Color _kidsPrimaryDark = Color(0xFF442B82);
const Color _kidsPrimaryLight = Color(0xFFB794F4);
const Color _kidsPink = Color(0xFFED64A6);

const List<String> _avatarEmojis = <String>[
  '🦁', '🐼', '🦊', '🐨', '🐯', '🐰', '🐸', '🦉', '🐵', '🐻', '🦄', '🐳', //
];
const List<Color> _avatarColors = <Color>[
  Color(0xFFFDE68A), Color(0xFFBFDBFE), Color(0xFFFBCFE8), Color(0xFFBBF7D0), //
  Color(0xFFDDD6FE), Color(0xFFFED7AA), Color(0xFFA7F3D0), Color(0xFFC7D2FE),
];

/// Kotlin's `KidAvatar`: a steady emoji and colour picked from [seed].
class KidAvatar extends StatelessWidget {
  /// Creates the avatar.
  const new({required this.seed, this.size = 40, super.key});

  /// Usually the member id.
  final String seed;

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    // A stable hash of the text, so the same child keeps the same animal
    // across launches (Dart's String.hashCode is not stable across runs).
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _avatarColors[h % _avatarColors.length],
      ),
      child: Text(
        _avatarEmojis[h % _avatarEmojis.length],
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }
}

/// The kids home.
class KidsHome extends ConsumerWidget {
  /// Creates the screen.
  const new({required this.onOpenFamily, super.key});

  /// «فتح الشات».
  final VoidCallback onOpenFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyView = ref.watch(familyControllerProvider);
    final family = familyView.family;
    final me = family?.me(familyView.userId);
    if (family == null || me == null) {
      return Center(
        child: Text(
          'جار تحميل بيانات العائلة...',
          style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
        ),
      );
    }
    final life = ref.watch(familyLifeControllerProvider);
    final currency = familyCurrency(ref);
    final chores = life.chores.where((c) => c.assignedTo == me.id).toList();
    final recent = life.messages.length > 3
        ? life.messages.sublist(life.messages.length - 3)
        : life.messages;
    final alias = me.alias.trim().isEmpty ? 'بطل' : me.alias;
    final goal = me.savingsGoal;
    final savings = goal > 0 ? (me.balance / goal).clamp(0.0, 1.0) : 0.0;

    return RefreshIndicator(
      onRefresh: ref.read(familyLifeControllerProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: <Widget>[
          Row(
            children: <Widget>[
              KidAvatar(seed: me.id.isEmpty ? alias : me.id, size: 52),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'أهلاً يا $alias! 👋',
                      style: ZadType.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'يوم حلو وميزانية أحلى ✨',
                      style: ZadType.labelMedium.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _BalanceCard(member: me, messages: life.messages, currency: currency),
          const SizedBox(height: 22),
          const _SectionTitle(emoji: '⭐', title: 'مهامي'),
          const SizedBox(height: 10),
          if (chores.isEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(ZadSpacing.lg),
                child: Row(
                  children: <Widget>[
                    const Text('🎉', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'مفيش مهام دلوقتي — استمتع بيومك!',
                        style: ZadType.bodyMedium.copyWith(
                          color: const Color(0xFF15803D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final (i, chore) in chores.indexed)
              _ChoreRow(chore: chore, currency: currency)
                  .animate(delay: (i * 60).clamp(0, 400).ms)
                  .fadeIn(duration: ZadDuration.enter)
                  .moveY(begin: 8, curve: ZadCurves.standard),
          const SizedBox(height: 22),
          _BadgeRow(
            completedChores: chores.where((c) => c.isCompleted).length,
            tasbihaStreakDays:
                ref
                    .watch(tasbihaControllerProvider)
                    .myTrees
                    .firstOrNull
                    ?.streakDays ??
                0,
            savingsProgress: savings,
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              const _SectionTitle(emoji: '💬', title: 'آخر رسائل العائلة'),
              const Spacer(),
              TextButton.icon(
                onPressed: onOpenFamily,
                iconAlignment: IconAlignment.end,
                icon: const Icon(ZadIcons.back, size: 16),
                label: const Text('فتح الشات', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          if (recent.isEmpty)
            const ZadEmptyState(
              icon: ZadIcons.ask,
              title: 'لا توجد رسائل بعد',
              message: 'أول رسالة في شات العيلة هتظهر هنا.',
            )
          else
            for (final m in recent) _MessageRow(message: m, family: family),
          const SizedBox(height: 22),
          const _TasbihaCard(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const new({required this.emoji, required this.title});

  final String emoji;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 6),
      Text(
        title,
        style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _BalanceCard extends ConsumerWidget {
  const new({
    required this.member,
    required this.messages,
    required this.currency,
  });

  final FamilyMember member;
  final List<FamilyMessage> messages;
  final String currency;

  Future<void> _wish(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final amount = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('طلب مصروف أو مشتريات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'ماذا تريد أن تشتري؟',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: ZadSpacing.sm),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'المبلغ المطلوب ($currency)',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
            onPressed: () {
              final value = double.tryParse(amount.text.trim()) ?? 0;
              final what = title.text.trim();
              if (what.isEmpty || value <= 0) return;
              Navigator.of(dialogContext).pop();
              unawaited(
                ref
                    .read(familyLifeControllerProvider.notifier)
                    .requestMoney(what, value),
              );
            },
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
    title.dispose();
    amount.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = member.savingsGoal;
    final limit = member.dailyLimit;
    final spentToday = approvedSpendSince(
      messages,
      member.id,
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final limitRatio = (limit ?? 0) > 0
        ? (spentToday / limit!).clamp(0.0, 1.0)
        : 0.0;
    final white90 = Colors.white.withValues(alpha: 0.9);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[_kidsPrimary, _kidsPink, ZadColors.mustardOchre],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kidsPrimary.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('🪙', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(
                  'مصروفك المتاح',
                  style: ZadType.labelLarge.copyWith(
                    color: white90,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: member.balance),
              duration: ZadDuration.count,
              curve: ZadCurves.standard,
              builder: (context, v, _) => Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: familyMoney(v, '').trim(),
                      style: ZadType.displayLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: ' $currency',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (goal > 0) ...<Widget>[
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '🎯 هدف التوفير: ${familyMoney(goal, currency)}',
                      style: ZadType.labelMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Text('🚀', style: TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 6),
              _Bar(value: (member.balance / goal).clamp(0.0, 1.0)),
            ],
            if ((limit ?? 0) > 0) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                '💸 مصروف اليوم: ${familyMoney(spentToday, currency)} من '
                '${familyMoney(limit!, currency)}',
                style: ZadType.labelMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _Bar(
                value: limitRatio,
                color: limitRatio >= 1 ? const Color(0xFFFECACA) : Colors.white,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _kidsPrimaryDark,
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 44),
              ),
              onPressed: () => unawaited(_wish(context, ref)),
              icon: const Text('✋', style: TextStyle(fontSize: 14)),
              label: const Text(
                'محتاج مصروف زيادة؟',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const new({required this.value, this.color = Colors.white});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(5),
    child: TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.fastOutSlowIn,
      builder: (context, v, _) => LinearProgressIndicator(
        value: v,
        minHeight: 10,
        color: color,
        backgroundColor: Colors.white.withValues(alpha: 0.3),
      ),
    ),
  );
}

class _ChoreRow extends StatelessWidget {
  const new({required this.chore, required this.currency});

  final Chore chore;
  final String currency;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: chore.isCompleted ? const Color(0xFFECFDF5) : ZadColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kidsPrimary.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chore.isCompleted
                    ? const Color(0xFF22C55E)
                    : _kidsPrimaryLight.withValues(alpha: 0.25),
              ),
              child: Text(
                chore.isCompleted ? '✅' : '📋',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    chore.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (chore.rewardAmount > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '🪙 +${familyMoney(chore.rewardAmount, currency)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Kotlin's `buildKidBadges` + `KidBadgeRow`: three thresholds from data that
/// already exists — three done chores, a seven-day tasbiha streak, half the
/// savings goal.
class _BadgeRow extends StatelessWidget {
  const new({
    required this.completedChores,
    required this.tasbihaStreakDays,
    required this.savingsProgress,
  });

  final int completedChores;
  final int tasbihaStreakDays;
  final double savingsProgress;

  @override
  Widget build(BuildContext context) {
    final badges = <(String, String, bool)>[
      ('🏅', '3 مهام', completedChores >= 3),
      ('🔥', 'أسبوع كامل', tasbihaStreakDays >= 7),
      ('💰', 'نص الهدف', savingsProgress >= 0.5),
    ];
    const colors = <Color>[
      _kidsPrimary,
      _kidsPrimaryLight,
      Color(0xFFFDE68A),
      Color(0xFFBFDBFE),
    ];
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final (i, (emoji, label, achieved)) in badges.indexed)
            SizedBox(
              width: 72,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: ZadSpacing.md),
                child: Column(
                  children: <Widget>[
                    _BadgeCircle(
                      emoji: emoji,
                      color: colors[i % colors.length],
                      achieved: achieved,
                    ),
                    const SizedBox(height: ZadSpacing.xs),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: achieved
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: achieved
                            ? colors[i % colors.length]
                            : ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ).animate(delay: (i * 80).ms).fadeIn(duration: ZadDuration.enter),
            ),
        ],
      ),
    );
  }
}

class _BadgeCircle extends StatelessWidget {
  const new({required this.emoji, required this.color, required this.achieved});

  final String emoji;
  final Color color;
  final bool achieved;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: achieved ? color : color.withValues(alpha: 0.15),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 26)),
    );
    if (!achieved) return circle;
    // Kotlin's pulseGlow(maxScale = 1.08).
    return circle
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(end: 1.08, duration: 900.ms, curve: Curves.easeInOut);
  }
}

class _MessageRow extends StatelessWidget {
  const new({required this.message, required this.family});

  final FamilyMessage message;
  final Family family;

  @override
  Widget build(BuildContext context) {
    final sender = family.members
        .where((m) => m.id == message.senderId)
        .firstOrNull;
    final alias = (sender?.alias.trim().isEmpty ?? true) ? '؟' : sender!.alias;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ZadColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.md),
          child: Row(
            children: <Widget>[
              KidAvatar(
                seed: message.senderId.isEmpty ? alias : message.senderId,
                size: 28,
              ),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      alias,
                      style: const TextStyle(
                        fontSize: 10,
                        color: _kidsPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      message.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotlin's kids tasbiha widget: the child's tree score, opening the garden.
class _TasbihaCard extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_TasbihaCard> createState() => _TasbihaCardState();
}

class _TasbihaCardState extends ConsumerState<_TasbihaCard> {
  @override
  void initState() {
    super.initState();
    // Read once on open, not on every return: the garden screen reloads
    // itself, and the controller keeps what it read for the session.
    unawaited(
      Future<void>.microtask(() {
        if (!mounted) return;
        final view = ref.read(tasbihaControllerProvider);
        if (view.myTrees.isEmpty) {
          unawaited(ref.read(tasbihaControllerProvider.notifier).load());
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(tasbihaControllerProvider).myTrees.firstOrNull;
    return Material(
      color: const Color(0xFFF1F8E9),
      elevation: 4,
      shadowColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(showTasbihaScreen(context)),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: Row(
            children: <Widget>[
              const Text('🌳', style: TextStyle(fontSize: 30)),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'بستان التسبيحة',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    Text(
                      tree != null
                          ? 'شجرتك: ${tree.score} تسبيحة'
                          : 'ازرع شجرتك!',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF558B2F),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(ZadIcons.back, color: Color(0xFF2E7D32)),
            ],
          ),
        ),
      ),
    );
  }
}
