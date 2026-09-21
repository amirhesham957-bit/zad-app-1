/// The family: who is in it, how to invite someone, and the way out.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/data/family_repository.dart';
import 'package:zad/features/family/domain/family.dart';

/// Opens the screen.
Future<void> showFamilyScreen(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const FamilyScreen()));

/// The screen.
class FamilyScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(familyControllerProvider);

    // Every refusal says why, in words — never a silent no.
    ref.listen<FamilyFailure?>(
      familyControllerProvider.select((v) => v.failure),
      (_, failure) {
        if (failure == null) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('العيلة')),
        body: RefreshIndicator(
          onRefresh: ref.read(familyControllerProvider.notifier).refresh,
          child: switch (view.status) {
            FamilyUnknown() => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                SizedBox(
                  height: 420,
                  child: ZadEmptyState(
                    icon: ZadIcons.family,
                    title: 'بنشوف عيلتك',
                    message: 'أول مرة محتاجة نت. اسحب لتحت لو طوّلت.',
                    tone: ZadEmptyTone.waiting,
                    action: TextButton(
                      onPressed: ref
                          .read(familyControllerProvider.notifier)
                          .refresh,
                      child: const Text('جرّب تاني'),
                    ),
                  ),
                ),
              ],
            ),
            NoFamily() => _NoFamily(busy: view.isBusy),
            InFamily(:final family) => _InFamily(family: family, view: view),
          },
        ),
      ),
    );
  }
}

// ── No family yet ───────────────────────────────────────────────────────────

class _NoFamily extends ConsumerStatefulWidget {
  const new({required this.busy});

  final bool busy;

  @override
  ConsumerState<_NoFamily> createState() => _NoFamilyState();
}

class _NoFamilyState extends ConsumerState<_NoFamily> {
  final TextEditingController _alias = TextEditingController();
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _alias.dispose();
    _code.dispose();
    super.dispose();
  }

  String? get _aliasOrNull =>
      _alias.text.trim().isEmpty ? null : _alias.text.trim();

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(familyControllerProvider.notifier);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(ZadSpacing.gutter),
      children: <Widget>[
        Text(
          'لما تبقوا عيلة على زاد، المخزن وقايمة المشتريات بيبقوا مشتركين، '
          'وكل واحد بيشوف اللي ناقص.',
          style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.lg),
        TextField(
          controller: _alias,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'العيلة هتناديك بإيه؟ (اختياري)',
            hintText: 'بابا، ماما، أحمد…',
          ),
        ),
        const SizedBox(height: ZadSpacing.xl),
        ZadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('ابدأ عيلة جديدة', style: ZadType.titleSmall),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                'هتبقى المسؤول، وتاخد كود تبعته للباقيين.',
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.md),
              FilledButton(
                onPressed: widget.busy
                    ? null
                    : () => controller.create(alias: _aliasOrNull),
                child: const Text('اعمل عيلة'),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZadSpacing.md),
        ZadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('عندك كود؟', style: ZadType.titleSmall),
              const SizedBox(height: ZadSpacing.md),
              TextField(
                controller: _code,
                textDirection: TextDirection.ltr,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'كود الدعوة',
                  hintText: 'ZAD-…',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: ZadSpacing.md),
              FilledButton.tonal(
                onPressed: widget.busy || _code.text.trim().isEmpty
                    ? null
                    : () => controller.join(
                        code: _code.text,
                        alias: _aliasOrNull,
                      ),
                child: const Text('انضم'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── In a family ─────────────────────────────────────────────────────────────

class _InFamily extends ConsumerWidget {
  const new({required this.family, required this.view});

  final Family family;
  final FamilyView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(ZadSpacing.gutter),
    children: <Widget>[
      _InviteCard(code: family.inviteCode, isAdmin: view.isAdmin),
      const SizedBox(height: ZadSpacing.xl),
      Text(
        '${family.members.length} في العيلة',
        style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
      ),
      const SizedBox(height: ZadSpacing.sm),
      for (final member in family.members) ...<Widget>[
        _MemberRow(
          member: member,
          isMe: member.userId == view.userId,
          canManage: view.isAdmin && member.userId != view.userId,
        ),
        const SizedBox(height: ZadSpacing.sm),
      ],
      const SizedBox(height: ZadSpacing.xl),
      OutlinedButton.icon(
        onPressed: view.isBusy ? null : () => _confirmLeave(context, ref),
        icon: const Icon(ZadIcons.dismiss, color: ZadColors.terracottaRust),
        label: const Text(
          'اخرج من العيلة',
          style: TextStyle(color: ZadColors.terracottaRust),
        ),
      ),
      const SizedBox(height: ZadSpacing.xxl),
    ],
  );

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('تخرج من العيلة؟'),
        content: const Text(
          'المخزن وقايمة المشتريات هيبقوا ليك لوحدك، ومش هتشوف بتوع العيلة.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('لأ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text(
              'اخرج',
              style: TextStyle(color: ZadColors.terracottaRust),
            ),
          ),
        ],
      ),
    );
    if (sure ?? false) {
      await ref.read(familyControllerProvider.notifier).leave();
    }
  }
}

class _InviteCard extends ConsumerWidget {
  const new({required this.code, required this.isAdmin});

  final String code;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ZadCard(
    color: ZadColors.mint50,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'كود الدعوة',
          style: ZadType.labelMedium.copyWith(color: ZadColors.green700),
        ),
        const SizedBox(height: ZadSpacing.xs),
        Row(
          children: <Widget>[
            Expanded(
              child: SelectableText(
                code,
                textDirection: TextDirection.ltr,
                style: ZadType.titleLarge.copyWith(letterSpacing: 1),
              ),
            ),
            IconButton(
              tooltip: 'انسخ الكود',
              icon: const Icon(ZadIcons.selected),
              onPressed: () {
                unawaited(Clipboard.setData(ClipboardData(text: code)));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('اتنسخ. ابعته للي عايز تضيفه.')),
                );
              },
            ),
          ],
        ),
        Text(
          'اللي معاه الكود يقدر ينضم. ابعته لأهل البيت بس.',
          style: ZadType.labelSmall.copyWith(color: ZadColors.slate),
        ),
        if (isAdmin)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => _confirmRotate(context, ref),
              child: const Text('كود جديد'),
            ),
          ),
      ],
    ),
  );

  Future<void> _confirmRotate(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('تعمل كود جديد؟'),
        content: const Text(
          'الكود القديم هيبطل. اللي في العيلة دلوقتي مش هيتأثروا.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('لأ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('اعمل كود جديد'),
          ),
        ],
      ),
    );
    if (sure ?? false) {
      await ref.read(familyControllerProvider.notifier).rotateInviteCode();
    }
  }
}

class _MemberRow extends ConsumerWidget {
  const new({
    required this.member,
    required this.isMe,
    required this.canManage,
  });

  final FamilyMember member;
  final bool isMe;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = member.alias.isEmpty ? 'من غير اسم' : member.alias;
    return ZadCard(
      onTap: canManage ? () => _manage(context, ref) : null,
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.lg,
        vertical: ZadSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: kZadMinTapTarget,
            height: kZadMinTapTarget,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: ZadColors.mint50,
              shape: zadSquircle(ZadRadii.chip),
            ),
            child: Text(
              name.characters.first,
              style: ZadType.titleSmall.copyWith(color: ZadColors.green700),
            ),
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Text(isMe ? '$name (إنت)' : name, style: ZadType.titleSmall),
          ),
          _RoleChip(role: member.role),
          if (canManage) ...<Widget>[
            const SizedBox(width: ZadSpacing.xs),
            const Icon(ZadIcons.forward, size: 18, color: ZadColors.inkMuted),
          ],
        ],
      ),
    );
  }

  Future<void> _manage(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(familyControllerProvider.notifier);
    final choice = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: ZadColors.surface,
      shape: zadSquircle(ZadRadii.sheet),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: ZadSpacing.sm),
            for (final role in FamilyRole.values)
              ListTile(
                title: Text('خلّيه ${role.label}'),
                trailing: role == member.role
                    ? const Icon(ZadIcons.selected, color: ZadColors.green600)
                    : null,
                onTap: role == member.role
                    ? null
                    : () => Navigator.of(sheet).pop(role),
              ),
            ListTile(
              leading: const Icon(
                ZadIcons.delete,
                color: ZadColors.terracottaRust,
              ),
              title: const Text(
                'شيله من العيلة',
                style: TextStyle(color: ZadColors.terracottaRust),
              ),
              onTap: () => Navigator.of(sheet).pop('remove'),
            ),
            const SizedBox(height: ZadSpacing.sm),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice is FamilyRole) {
      await controller.setRole(member, choice);
    } else if (choice == 'remove') {
      await controller.remove(member);
    }
  }
}

class _RoleChip extends StatelessWidget {
  const new({required this.role});

  final FamilyRole role;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: ZadSpacing.sm,
      vertical: ZadSpacing.xs,
    ),
    decoration: ShapeDecoration(
      color: role == FamilyRole.admin
          ? ZadColors.green600.withValues(alpha: 0.12)
          : ZadColors.surfaceVariant,
      shape: const StadiumBorder(),
    ),
    child: Text(
      role.label,
      style: ZadType.labelSmall.copyWith(
        color: role == FamilyRole.admin ? ZadColors.green700 : ZadColors.slate,
      ),
    ),
  );
}
