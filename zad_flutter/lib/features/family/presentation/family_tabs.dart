/// Kotlin's other family tabs: المهام, الأعضاء (with each member's sheet and a
/// parent's spending limits), البقالة, الأبناء and الأهداف.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/application/family_life_controller.dart';
import 'package:zad/features/family/domain/family.dart';
import 'package:zad/features/family/domain/family_life.dart';
import 'package:zad/features/family/presentation/family_dialogs.dart';

const EdgeInsets _listPadding = EdgeInsets.fromLTRB(
  ZadSpacing.gutter,
  ZadSpacing.lg,
  ZadSpacing.gutter,
  96,
);

Widget _heading(IconData icon, String title, {Widget? trailing}) => Row(
  children: <Widget>[
    Icon(icon, size: 20, color: ZadColors.green700),
    const SizedBox(width: ZadSpacing.sm),
    Expanded(child: Text(title, style: ZadType.titleLarge)),
    ?trailing,
  ],
);

Widget _subtitle(String text) => Padding(
  padding: const EdgeInsets.only(top: ZadSpacing.xs, bottom: ZadSpacing.md),
  child: Text(
    text,
    style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
  ),
);

Widget _avatar(FamilyMember m, {double size = 56}) => Container(
  width: size,
  height: size,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: m.role == FamilyRole.admin
          ? const <Color>[ZadColors.green700, ZadColors.green600]
          : <Color>[ZadColors.mustardOchre, ZadColors.mustardLight],
    ),
  ),
  child: Text(
    (m.alias.characters.firstOrNull ?? '?').toUpperCase(),
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: size * 0.4,
    ),
  ),
);

// ── Tasks ──────────────────────────────────────────────────────────────────

/// المهام العائلية, grouped by member, with Kotlin's three filters.
class FamilyTasksTab extends ConsumerStatefulWidget {
  /// Creates the tab.
  const new({
    required this.family,
    required this.isAdmin,
    required this.showFinancials,
    super.key,
  });

  /// The family.
  final Family family;

  /// Whether the customer runs it.
  final bool isAdmin;

  /// False in kids mode: no rewards shown or set.
  final bool showFinancials;

  @override
  ConsumerState<FamilyTasksTab> createState() => _FamilyTasksTabState();
}

class _FamilyTasksTabState extends ConsumerState<FamilyTasksTab> {
  String _filter = 'all';

  bool _keep(Chore c) => switch (_filter) {
    'pending' => !c.isCompleted,
    'done' => c.isCompleted,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(familyLifeControllerProvider);
    final controller = ref.read(familyLifeControllerProvider.notifier);
    final currency = familyCurrency(ref);
    final chores = view.chores;
    final byMember = <FamilyMember, List<Chore>>{
      for (final m in widget.family.members)
        m: chores.where((c) => c.assignedTo == m.id).toList(),
    };
    final anyVisible = byMember.values.any((list) => list.any(_keep));

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: _listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          _heading(
            ZadIcons.chore,
            'المهام العائلية',
            trailing: widget.isAdmin && widget.showFinancials
                ? FilledButton.tonalIcon(
                    onPressed: () => unawaited(
                      showAddChoreDialog(context, ref, widget.family.members),
                    ),
                    icon: const Icon(ZadIcons.add, size: 18),
                    label: const Text('إضافة'),
                  )
                : null,
          ),
          _subtitle(
            '${chores.where((c) => c.isCompleted).length}/${chores.length} '
            'منجزة',
          ),
          Wrap(
            spacing: ZadSpacing.sm,
            children: <Widget>[
              for (final (key, label) in <(String, String)>[
                ('all', 'الكل'),
                ('pending', 'قادمة'),
                ('done', 'منجزة'),
              ])
                FilterChip(
                  label: Text(label),
                  selected: _filter == key,
                  onSelected: (_) => setState(() => _filter = key),
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.lg),
          if (!anyVisible)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: ZadSpacing.xxl),
              child: ZadEmptyState(
                icon: ZadIcons.chore,
                title: 'لا توجد مهام',
                message: 'ضيف مهمة عشان أفراد العائلة يشاركوا فيها',
              ),
            ),
          for (final MapEntry(key: member, value: list) in byMember.entries)
            if (list.any(_keep)) ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: ZadSpacing.sm),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: ZadColors.green700.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        (member.alias.characters.firstOrNull ?? '?')
                            .toUpperCase(),
                        style: ZadType.labelLarge.copyWith(
                          color: ZadColors.green700,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    Text(member.alias, style: ZadType.titleSmall),
                    const SizedBox(width: ZadSpacing.sm),
                    Text(
                      '(${list.where((c) => c.isCompleted).length}/'
                      '${list.length})',
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              for (final chore in list.where(_keep))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ZadCard(
                    color: chore.isCompleted
                        ? ZadColors.green700.withValues(alpha: 0.08)
                        : ZadColors.surface,
                    padding: const EdgeInsets.all(14),
                    onTap: () => unawaited(controller.toggleChore(chore)),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          chore.isCompleted ? ZadIcons.selected : ZadIcons.open,
                          size: 24,
                          color: chore.isCompleted
                              ? ZadColors.green700
                              : ZadColors.outline,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                chore.title,
                                style: ZadType.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: chore.isCompleted
                                      ? ZadColors.inkMuted
                                      : ZadColors.ink,
                                  decoration: chore.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              Row(
                                children: <Widget>[
                                  if (widget.showFinancials &&
                                      chore.rewardAmount > 0)
                                    Container(
                                      margin: const EdgeInsetsDirectional.only(
                                        end: ZadSpacing.sm,
                                        top: 2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (chore.isCompleted
                                                    ? ZadColors.green700
                                                    : ZadColors.mustardOchre)
                                                .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        familyMoney(
                                          chore.rewardAmount,
                                          currency,
                                        ),
                                        style: ZadType.labelSmall.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: chore.isCompleted
                                              ? ZadColors.green700
                                              : ZadColors.mustardOchre,
                                        ),
                                      ),
                                    ),
                                  if (chore.dueDate case final due?)
                                    Text(
                                      due.length > 10
                                          ? due.substring(0, 10)
                                          : due,
                                      style: ZadType.labelSmall.copyWith(
                                        color: ZadColors.inkMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: ZadSpacing.sm),
            ],
        ],
      ),
    );
  }
}

// ── Members ────────────────────────────────────────────────────────────────

/// أفراد العائلة: a card each (tap for the member's sheet), then leave — or
/// delete, when the customer is the last one in it.
class FamilyMembersTab extends ConsumerWidget {
  /// Creates the tab.
  const new({
    required this.family,
    required this.view,
    required this.showFinancials,
    super.key,
  });

  /// The family.
  final Family family;

  /// The membership view.
  final FamilyView view;

  /// False in kids mode.
  final bool showFinancials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final life = ref.watch(familyLifeControllerProvider);
    final currency = familyCurrency(ref);
    final sole = family.members.length <= 1;
    return RefreshIndicator(
      onRefresh: ref.read(familyControllerProvider.notifier).refresh,
      child: ListView(
        padding: _listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const Text('أفراد العائلة', style: ZadType.titleLarge),
          _subtitle('اضغط على أي عضو لتفاصيل إنجازاته'),
          for (final m in family.members)
            Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.md),
              child: _MemberCard(
                member: m,
                chores: life.chores.where((c) => c.assignedTo == m.id).toList(),
                treeScore: life
                    .treesOf(m.userId)
                    .fold<int>(0, (a, t) => a + t.score),
                currency: currency,
                showFinancials: showFinancials,
                onTap: () => unawaited(
                  showMemberSheet(
                    context,
                    member: m,
                    view: view,
                    showFinancials: showFinancials,
                  ),
                ),
              ),
            ),
          const SizedBox(height: ZadSpacing.lg),
          const Divider(color: ZadColors.hairline),
          const SizedBox(height: ZadSpacing.lg),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: ZadColors.terracottaRust,
            ),
            onPressed: view.isBusy
                ? null
                : () => unawaited(_confirmLeave(context, ref, sole: sole)),
            icon: Icon(sole ? ZadIcons.delete : ZadIcons.leave, size: 18),
            label: Text(sole ? 'حذف العائلة وإعادة الإنشاء' : 'مغادرة العائلة'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref, {
    required bool sole,
  }) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(
          sole ? ZadIcons.delete : ZadIcons.leave,
          color: ZadColors.terracottaRust,
        ),
        title: Text(sole ? 'حذف العائلة نهائياً' : 'تأكيد المغادرة'),
        content: Text(
          sole
              ? 'إنت آخر فرد في العائلة دي. حذفها هيمسح الشات والمهام وكل '
                    'البيانات نهائياً ومينفعش ترجعها، وتقدر تنشئ عائلة جديدة '
                    'بعد كده.'
              : 'هتفقد الوصول لشات العائلة والمهام والأرصدة المشتركة. متأكد '
                    'إنك عايز تغادر العائلة؟',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ZadColors.terracottaRust,
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(sole ? 'حذف نهائي' : 'مغادرة'),
          ),
        ],
      ),
    );
    // The last member leaving is the delete: the server removes an emptied
    // family (20260921130000).
    if (sure ?? false) {
      await ref.read(familyControllerProvider.notifier).leave();
    }
  }
}

class _MemberCard extends StatelessWidget {
  const new({
    required this.member,
    required this.chores,
    required this.treeScore,
    required this.currency,
    required this.showFinancials,
    required this.onTap,
  });

  final FamilyMember member;
  final List<Chore> chores;
  final int treeScore;
  final String currency;
  final bool showFinancials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = chores.where((c) => c.isCompleted).length;
    final goal = member.savingsGoal;
    final progress = goal > 0
        ? (member.balance / goal).clamp(0, 1).toDouble()
        : 0.0;
    return ZadCard(
      radius: ZadRadii.cardLarge,
      onTap: onTap,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _avatar(member),
              const SizedBox(width: ZadSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            member.alias,
                            style: ZadType.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (member.role != FamilyRole.member) ...<Widget>[
                          const SizedBox(width: ZadSpacing.sm),
                          _RoleBadge(role: member.role),
                        ],
                      ],
                    ),
                    const SizedBox(height: ZadSpacing.xs),
                    Wrap(
                      spacing: ZadSpacing.sm,
                      runSpacing: ZadSpacing.xs,
                      children: <Widget>[
                        if (showFinancials)
                          _StatPill(
                            icon: ZadIcons.coins,
                            text: familyMoney(member.balance, currency),
                          ),
                        _StatPill(icon: ZadIcons.selected, text: '$done مهام'),
                        _StatPill(
                          icon: ZadIcons.tree,
                          text: '$treeScore تسبيحة',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(ZadIcons.forward, color: ZadColors.inkMuted),
            ],
          ),
          if (showFinancials && goal > 0) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            Row(
              children: <Widget>[
                Text(
                  'هدف التوفير',
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: progress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        color: ZadColors.green700,
                        backgroundColor: ZadColors.ink.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
                Text(
                  '${(progress * 100).round()}%',
                  style: ZadType.labelSmall.copyWith(
                    color: ZadColors.green700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const new({required this.role});

  final FamilyRole role;

  @override
  Widget build(BuildContext context) {
    final admin = role == FamilyRole.admin;
    final color = admin ? ZadColors.green700 : ZadColors.mustardOchre;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.15),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(admin ? ZadIcons.admin : ZadIcons.child, size: 14, color: color),
          const SizedBox(width: ZadSpacing.xs),
          Text(
            admin ? 'مدير' : 'ابن/ابنة',
            style: ZadType.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const new({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: ZadColors.ink.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: ZadColors.inkMuted),
        const SizedBox(width: ZadSpacing.xs),
        Text(
          text,
          style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
        ),
      ],
    ),
  );
}

/// Kotlin's `MemberDetailSheet`: the member, their figures, done and upcoming
/// chores, tasbiha trees, and — for a parent looking at a child — spending
/// limits. An admin also manages the member's role and membership here.
Future<void> showMemberSheet(
  BuildContext context, {
  required FamilyMember member,
  required FamilyView view,
  required bool showFinancials,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: ZadColors.surface,
  shape: zadSquircle(ZadRadii.sheet),
  builder: (_) => _MemberSheet(
    memberId: member.id,
    viewerIsAdmin: view.isAdmin,
    viewerUserId: view.userId,
    showFinancials: showFinancials,
  ),
);

class _MemberSheet extends ConsumerWidget {
  const new({
    required this.memberId,
    required this.viewerIsAdmin,
    required this.viewerUserId,
    required this.showFinancials,
  });

  final String memberId;
  final bool viewerIsAdmin;
  final String viewerUserId;
  final bool showFinancials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyControllerProvider).family;
    final member = family?.members.where((m) => m.id == memberId).firstOrNull;
    if (member == null) return const SizedBox(height: 120);
    final life = ref.watch(familyLifeControllerProvider);
    final currency = familyCurrency(ref);
    final chores = life.chores.where((c) => c.assignedTo == member.id);
    final done = chores.where((c) => c.isCompleted).toList();
    final upcoming = chores.where((c) => !c.isCompleted).toList();
    final trees = life.treesOf(member.userId);
    final isMe = member.userId == viewerUserId;
    final now = ref.read(nowProvider)();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(ZadSpacing.xl),
        children: <Widget>[
          Row(
            children: <Widget>[
              _avatar(member, size: 64),
              const SizedBox(width: ZadSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(member.alias, style: ZadType.headlineMedium),
                    Text(
                      switch (member.role) {
                        FamilyRole.admin => 'مدير العائلة',
                        FamilyRole.child => 'ابن/ابنة',
                        FamilyRole.member => 'عضو',
                      },
                      style: ZadType.bodyMedium.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              if (showFinancials) ...<Widget>[
                _StatItem(
                  label: 'الرصيد',
                  value: familyMoney(member.balance, currency),
                ),
                _StatItem(
                  label: 'الهدف',
                  value: member.savingsGoal > 0
                      ? familyMoney(member.savingsGoal, currency)
                      : '---',
                ),
              ],
              _StatItem(label: 'الأشجار', value: '${trees.length}'),
            ],
          ),
          const SizedBox(height: ZadSpacing.xl),
          _SheetSection(
            icon: ZadIcons.selected,
            color: ZadColors.green700,
            title: 'المهام المنجزة (${done.length})',
            empty: 'لا توجد مهام منجزة بعد',
            chores: done,
            currency: currency,
            showFinancials: showFinancials,
          ),
          const SizedBox(height: ZadSpacing.lg),
          _SheetSection(
            icon: ZadIcons.chore,
            color: ZadColors.mustardOchre,
            title: 'المهام القادمة (${upcoming.length})',
            empty: 'لا توجد مهام قادمة',
            chores: upcoming,
            currency: currency,
            showFinancials: showFinancials,
          ),
          if (trees.isNotEmpty) ...<Widget>[
            const SizedBox(height: ZadSpacing.lg),
            Row(
              children: <Widget>[
                const Icon(ZadIcons.tree, size: 18, color: ZadColors.green600),
                const SizedBox(width: 6),
                Text(
                  'أشجار التسبيحة (${trees.length})',
                  style: ZadType.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: trees.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: ZadSpacing.sm),
                itemBuilder: (_, i) => Container(
                  padding: const EdgeInsets.all(ZadSpacing.md),
                  decoration: BoxDecoration(
                    color: ZadColors.mint100.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        trees[i].stageEmoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                      Text(trees[i].name, style: ZadType.labelSmall),
                      Text(
                        '${trees[i].score}',
                        style: ZadType.labelLarge.copyWith(
                          color: ZadColors.green700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (showFinancials &&
              member.role == FamilyRole.child &&
              viewerIsAdmin) ...<Widget>[
            const SizedBox(height: ZadSpacing.lg),
            Row(
              children: <Widget>[
                Icon(ZadIcons.wallet, size: 18, color: ZadColors.mustardOchre),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('حد الإنفاق', style: ZadType.titleSmall),
                ),
                TextButton(
                  onPressed: () =>
                      unawaited(showSpendLimitDialog(context, ref, member)),
                  child: const Text('تعديل'),
                ),
              ],
            ),
            SpendLimitBar(
              label: 'اليومي',
              spent: approvedSpendSince(
                life.messages,
                member.id,
                now.subtract(const Duration(days: 1)),
              ),
              limit: member.dailyLimit,
              currency: currency,
            ),
            const SizedBox(height: ZadSpacing.sm),
            SpendLimitBar(
              label: 'الأسبوعي',
              spent: approvedSpendSince(
                life.messages,
                member.id,
                now.subtract(const Duration(days: 7)),
              ),
              limit: member.weeklyLimit,
              currency: currency,
            ),
          ],
          if (viewerIsAdmin && !isMe) ...<Widget>[
            const SizedBox(height: ZadSpacing.xl),
            const Divider(color: ZadColors.hairline),
            Text(
              'الدور في العيلة',
              style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Wrap(
              spacing: ZadSpacing.sm,
              children: <Widget>[
                for (final role in FamilyRole.values)
                  ChoiceChip(
                    label: Text(role.label),
                    selected: member.role == role,
                    onSelected: member.role == role
                        ? null
                        : (_) => unawaited(
                            ref
                                .read(familyControllerProvider.notifier)
                                .setRole(member, role),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.md),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ZadColors.terracottaRust,
              ),
              onPressed: () async {
                final sure = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text('تشيل ${member.alias} من العيلة؟'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(c).pop(false),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(c).pop(true),
                        child: Text(
                          'شيله',
                          style: TextStyle(color: ZadColors.terracottaRust),
                        ),
                      ),
                    ],
                  ),
                );
                if (!(sure ?? false) || !context.mounted) return;
                final navigator = Navigator.of(context);
                final removed = await ref
                    .read(familyControllerProvider.notifier)
                    .remove(member);
                if (removed && navigator.mounted) navigator.pop();
              },
              icon: const Icon(ZadIcons.delete, size: 18),
              label: const Text('شيله من العيلة'),
            ),
          ],
          const SizedBox(height: ZadSpacing.xl),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Text(value, style: ZadType.titleLarge),
      Text(
        label,
        style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
      ),
    ],
  );
}

class _SheetSection extends StatelessWidget {
  const new({
    required this.icon,
    required this.color,
    required this.title,
    required this.empty,
    required this.chores,
    required this.currency,
    required this.showFinancials,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String empty;
  final List<Chore> chores;
  final String currency;
  final bool showFinancials;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(title, style: ZadType.titleSmall),
        ],
      ),
      const SizedBox(height: ZadSpacing.sm),
      if (chores.isEmpty)
        Text(
          empty,
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        )
      else
        for (final c in chores)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(ZadSpacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 22, color: color),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(c.title, style: ZadType.titleSmall),
                      if (showFinancials && c.rewardAmount > 0)
                        Text(
                          'مكافأة: ${familyMoney(c.rewardAmount, currency)}',
                          style: ZadType.labelSmall.copyWith(color: color),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    ],
  );
}

/// Kotlin's `SpendLimitBar`: spent against a cap, amber from 80% and red at
/// 100%; "بدون حد" when there is none.
class SpendLimitBar extends StatelessWidget {
  /// Creates the bar.
  const new({
    required this.label,
    required this.spent,
    required this.limit,
    required this.currency,
    super.key,
  });

  /// Which cap.
  final String label;

  /// What was spent.
  final double spent;

  /// The cap, or null.
  final double? limit;

  /// The currency.
  final String currency;

  @override
  Widget build(BuildContext context) {
    final cap = limit;
    final muted = ZadType.labelSmall.copyWith(color: ZadColors.inkMuted);
    if (cap == null || cap <= 0) {
      return Row(
        children: <Widget>[
          Expanded(child: Text(label, style: muted)),
          Text('بدون حد', style: muted),
        ],
      );
    }
    final ratio = spent / cap;
    final color = ratio >= 1
        ? ZadColors.terracottaRust
        : ratio >= 0.8
        ? ZadColors.mustardOchre
        : ZadColors.green700;
    return Row(
      children: <Widget>[
        Text(label, style: muted),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              minHeight: 6,
              color: color,
              backgroundColor: ZadColors.ink.withValues(alpha: 0.1),
            ),
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        Text(
          '${familyMoney(spent, '')} / ${familyMoney(cap, currency)}',
          style: ZadType.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Groceries ──────────────────────────────────────────────────────────────

/// البقالة المشتركة: the family's list, each line ticked by whoever bought it.
class FamilyGroceriesTab extends ConsumerWidget {
  /// Creates the tab.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(familyLifeControllerProvider);
    final controller = ref.read(familyLifeControllerProvider.notifier);
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: _listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          _heading(
            ZadIcons.shopping,
            'البقالة المشتركة',
            trailing: IconButton(
              tooltip: 'نزّلها في التسوق',
              onPressed: () => unawaited(showQuickGroceryDialog(context, ref)),
              icon: const Icon(ZadIcons.add, color: ZadColors.green700),
            ),
          ),
          _subtitle(
            'قائمة المشتريات التي تمت إضافتها من قبل أفراد العائلة أو '
            'اقترحها زاد.',
          ),
          if (view.groceries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: ZadSpacing.xxl),
              child: ZadEmptyState(
                icon: ZadIcons.shopping,
                title: 'لا توجد طلبات بقالة حالياً.',
                message: 'اكتب في الشات "أضف حليب" أو دوس + فوق.',
              ),
            ),
          for (final item in view.groceries)
            Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.md),
              child: ZadCard(
                radius: 18,
                padding: const EdgeInsets.all(ZadSpacing.md),
                onTap: () => unawaited(controller.toggleGrocery(item)),
                child: Row(
                  children: <Widget>[
                    Checkbox(
                      value: item.isPurchased,
                      onChanged: (_) =>
                          unawaited(controller.toggleGrocery(item)),
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: Text(
                        item.itemName,
                        style: ZadType.titleSmall.copyWith(
                          color: item.isPurchased
                              ? ZadColors.inkMuted
                              : ZadColors.ink,
                          decoration: item.isPurchased
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Kids ───────────────────────────────────────────────────────────────────

/// مصاريف الأبناء — a parent's view of each child: balance, goal, chores,
/// daily cap, real monthly spending, and pending requests to decide.
class FamilyKidsTab extends ConsumerWidget {
  /// Creates the tab.
  const new({required this.family, super.key});

  /// The family.
  final Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(familyLifeControllerProvider);
    final controller = ref.read(familyLifeControllerProvider.notifier);
    final currency = familyCurrency(ref);
    final now = ref.read(nowProvider)();
    final children = family.members
        .where((m) => m.role == FamilyRole.child)
        .toList();
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: _listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          _heading(ZadIcons.wallet, 'مصاريف الأبناء'),
          _subtitle('نظرة عامة على أرصدة وطلبات الأبناء'),
          if (children.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: ZadSpacing.xxl),
              child: ZadEmptyState(
                icon: ZadIcons.child,
                title: 'لا يوجد أبناء مسجلين بعد',
                message: 'من تاب الأعضاء خلّي أي فرد "طفل".',
              ),
            ),
          for (final child in children)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _KidCard(
                child: child,
                chores: view.chores
                    .where((c) => c.assignedTo == child.id)
                    .toList(),
                requests: view.messages
                    .where(
                      (m) =>
                          m.type == FamilyMessageType.purchaseRequest &&
                          m.senderId == child.id,
                    )
                    .toList(),
                spentToday: approvedSpendSince(
                  view.messages,
                  child.id,
                  now.subtract(const Duration(days: 1)),
                ),
                spending: view.childrenSpending[child.id],
                currency: currency,
              ),
            ),
        ],
      ),
    );
  }
}

class _KidCard extends ConsumerWidget {
  const new({
    required this.child,
    required this.chores,
    required this.requests,
    required this.spentToday,
    required this.spending,
    required this.currency,
  });

  final FamilyMember child;
  final List<Chore> chores;
  final List<FamilyMessage> requests;
  final double spentToday;
  final ChildSpending? spending;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(familyLifeControllerProvider.notifier);
    final done = chores.where((c) => c.isCompleted).length;
    final pending = requests
        .where((r) => r.requestStatus == RequestStatus.pending)
        .take(3)
        .toList();
    return ZadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _avatar(child, size: 40),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(child.alias, style: ZadType.titleSmall),
                    Text(
                      <String>[
                        'الرصيد: ${familyMoney(child.balance, currency)}',
                        if (child.savingsGoal > 0)
                          'الهدف: ${familyMoney(child.savingsGoal, currency)}',
                      ].join(' | '),
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZadSpacing.sm,
                  vertical: ZadSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: ZadColors.green700.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$done/${chores.length} مهام',
                  style: ZadType.labelSmall.copyWith(color: ZadColors.green700),
                ),
              ),
            ],
          ),
          if ((child.dailyLimit ?? 0) > 0) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            SpendLimitBar(
              label: 'اليومي',
              spent: spentToday,
              limit: child.dailyLimit,
              currency: currency,
            ),
          ],
          if (spending case final s?) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            SpendLimitBar(
              label: 'المصروف الشهري',
              spent: s.monthlyTotal,
              limit: s.budgetCeiling,
              currency: currency,
            ),
          ],
          if (requests.isNotEmpty) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ZadSpacing.sm),
              decoration: BoxDecoration(
                color: ZadColors.surfaceLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'الطلبات المعلقة (${requests.length})',
                    style: ZadType.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ZadColors.inkMuted,
                    ),
                  ),
                  for (final r in pending)
                    Row(
                      children: <Widget>[
                        Icon(
                          ZadIcons.wallet,
                          size: 14,
                          color: ZadColors.mustardOchre,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            r.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ZadType.labelSmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              unawaited(controller.decide(r, approve: true)),
                          icon: const Icon(ZadIcons.selected, size: 14),
                          label: const Text('موافقة'),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: ZadColors.terracottaRust,
                          ),
                          onPressed: () =>
                              unawaited(controller.decide(r, approve: false)),
                          icon: const Icon(ZadIcons.rejected, size: 14),
                          label: const Text('رفض'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Goals ──────────────────────────────────────────────────────────────────

/// الميزانية والمكافآت: the family savings goal (or زاد's suggestion on a
/// tap), each child's balance against the others, and rewards paid.
class FamilyGoalsTab extends ConsumerWidget {
  /// Creates the tab.
  const new({required this.family, super.key});

  /// The family.
  final Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(familyLifeControllerProvider);
    final controller = ref.read(familyLifeControllerProvider.notifier);
    final currency = familyCurrency(ref);
    final kids = family.members
        .where((m) => m.role != FamilyRole.admin)
        .toList();
    final paid = view.chores
        .where((c) => c.isCompleted)
        .fold<double>(0, (a, c) => a + c.rewardAmount);
    final goals = <FamilyGoal>[...view.goals]
      ..sort((a, b) => a.monthYear.compareTo(b.monthYear));
    final goal = goals.lastOrNull;
    final maxBalance = kids.fold<double>(
      1,
      (a, k) => k.balance > a ? k.balance : a,
    );

    ref.listen<GoalSuggestion?>(
      familyLifeControllerProvider.select((v) => v.suggestion),
      (_, s) {
        if (s != null) unawaited(_showSuggestion(context, ref, s, currency));
      },
    );

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: _listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          _heading(ZadIcons.coins, 'الميزانية والمكافآت'),
          const SizedBox(height: ZadSpacing.lg),
          ZadCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(ZadIcons.savings, size: 20, color: ZadColors.green700),
                    SizedBox(width: 6),
                    Text('هدف الادخار العائلي', style: ZadType.titleSmall),
                  ],
                ),
                const SizedBox(height: ZadSpacing.md),
                if (goal != null) ...<Widget>[
                  Text(
                    '${familyMoney(goal.currentAmount, currency)} / '
                    '${familyMoney(goal.targetAmount, currency)}',
                    style: ZadType.titleSmall.copyWith(
                      color: ZadColors.green700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: goal.fraction),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 10,
                        color: ZadColors.green700,
                        backgroundColor: ZadColors.ink.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  if (goal.rewardSuggestion case final r? when r.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: ZadSpacing.sm),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            ZadIcons.gift,
                            size: 14,
                            color: ZadColors.inkMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              r,
                              style: ZadType.bodySmall.copyWith(
                                color: ZadColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ] else ...<Widget>[
                  Text(
                    'لسه مفيش هدف ادخار للشهر ده',
                    style: ZadType.bodySmall.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: view.isSuggesting
                        ? null
                        : () => unawaited(controller.suggestGoal()),
                    icon: view.isSuggesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(ZadIcons.assistant, size: 16),
                    label: const Text('اقترح هدف بالذكاء الاصطناعي'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: ZadSpacing.lg),
          if (kids.isEmpty)
            const ZadEmptyState(
              icon: ZadIcons.child,
              title: 'لا يوجد أبناء مضافين لعرض إحصائياتهم.',
              message: 'من تاب الأعضاء خلّي أي فرد "طفل".',
            )
          else ...<Widget>[
            ZadCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'إحصائيات أرصدة الأبناء',
                    style: ZadType.titleSmall,
                  ),
                  const SizedBox(height: ZadSpacing.lg),
                  for (final kid in kids)
                    Padding(
                      padding: const EdgeInsets.only(bottom: ZadSpacing.md),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  kid.alias,
                                  style: ZadType.bodyMedium,
                                ),
                              ),
                              Text(
                                familyMoney(kid.balance, currency),
                                style: ZadType.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: ZadColors.green700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: ZadSpacing.xs),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              end: (kid.balance / maxBalance)
                                  .clamp(0, 1)
                                  .toDouble(),
                            ),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: ZadColors.ink.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: AlignmentDirectional.centerStart,
                              child: FractionallySizedBox(
                                widthFactor: v,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    gradient: const LinearGradient(
                                      colors: <Color>[
                                        ZadColors.green600,
                                        ZadColors.green700,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: ZadSpacing.lg),
            ZadCard(
              child: Row(
                children: <Widget>[
                  const Icon(
                    ZadIcons.coins,
                    size: 32,
                    color: ZadColors.green700,
                  ),
                  const SizedBox(width: ZadSpacing.lg),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'إجمالي المكافآت المدفوعة',
                        style: ZadType.bodyMedium.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                      Text(
                        familyMoney(paid, currency),
                        style: ZadType.titleLarge.copyWith(
                          color: ZadColors.green700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showSuggestion(
    BuildContext context,
    WidgetRef ref,
    GoalSuggestion s,
    String currency,
  ) async {
    final controller = ref.read(familyLifeControllerProvider.notifier);
    final approve = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${s.emoji} ${s.title}'.trim()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'الهدف: ${familyMoney(s.targetAmount, currency)} خلال '
              '${s.durationDays} يوم',
            ),
            if (s.rewardSuggestion.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Icon(ZadIcons.gift, size: 14, color: ZadColors.inkMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.rewardSuggestion,
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('اعتماد الهدف'),
          ),
        ],
      ),
    );
    if (approve ?? false) {
      await controller.approveSuggestion();
    } else {
      controller.clearSuggestion();
    }
  }
}
