/// Kotlin's `FamilyScreen`: with no family, create one or join by code; in
/// one, the green header (code, members, SOS, join, invite, share, avatars)
/// over the tabs — الشات, المهام, الأعضاء, البقالة, and for a parent الأبناء
/// and الأهداف.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/family/presentation/family_chat_tab.dart';
import 'package:zad/features/family/presentation/family_dialogs.dart';
import 'package:zad/features/family/presentation/family_tabs.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/application/family_format.dart';
import 'package:zad/shared/family/application/family_life_controller.dart';
import 'package:zad/shared/family/data/family_repository.dart';
import 'package:zad/shared/family/domain/family.dart';

/// Opens the screen on [initialTab] — 0 الشات, 1 المهام, 2 الأعضاء,
/// 3 البقالة (and, for a parent, 4 الأبناء, 5 الأهداف).
Future<void> showFamilyScreen(BuildContext context, {int initialTab = 0}) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FamilyScreen(initialTab: initialTab),
      ),
    );

/// The screen.
class FamilyScreen extends ConsumerWidget {
  /// Creates the screen; [showFinancials] false is Kotlin's kids mode — no
  /// balances, goals, limits or rewards.
  const new({this.showFinancials = true, this.initialTab = 0, super.key});

  /// Whether money is shown.
  final bool showFinancials;

  /// The tab showing first, once the family has loaded.
  final int initialTab;

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
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: switch (view.status) {
        InFamily(:final family) => _ActiveFamily(
          family: family,
          view: view,
          showFinancials: showFinancials,
          initialTab: initialTab,
        ),
        final status => Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('العيلة')),
          body: RefreshIndicator(
            onRefresh: ref.read(familyControllerProvider.notifier).refresh,
            child: status is NoFamily
                ? _NoFamily(busy: view.isBusy)
                : ListView(
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
          ),
        ),
      },
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

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(familyControllerProvider.notifier);
    // The code alone is enough: the server names a member without an alias
    // «فرد من العيلة». Requiring the alias left the button dead with the
    // alias field scrolled out of sight (owner's phone, 2026-10-30).
    final canJoin = _code.text.trim().isNotEmpty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(ZadSpacing.xl),
      children: <Widget>[
        const SizedBox(height: ZadSpacing.lg),
        Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: ZadColors.mint100,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            ZadIcons.family,
            size: 56,
            color: ZadColors.green700,
          ),
        ),
        const SizedBox(height: ZadSpacing.xl),
        const Text(
          'أهلاً بك في عائلة زاد',
          textAlign: TextAlign.center,
          style: ZadType.headlineMedium,
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          'يمكنك إنشاء عائلة جديدة لتكون أنت المدير، أو الانضمام لعائلة '
          'موجودة عبر كود الدعوة.',
          textAlign: TextAlign.center,
          style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.xxl),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
            onPressed: widget.busy
                ? null
                : () => controller.create(
                    alias: _alias.text.trim().isEmpty
                        ? null
                        : _alias.text.trim(),
                  ),
            icon: const Icon(ZadIcons.add),
            label: const Text('إنشاء عائلة جديدة كمدير (Admin)'),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              backgroundColor: ZadColors.mustardOchre,
            ),
            onPressed: widget.busy
                ? null
                : () => unawaited(showJoinFamilyDialog(context, ref)),
            icon: const Icon(ZadIcons.joinFamily),
            label: const Text('الانضمام للعائلة'),
          ),
        ),
        const SizedBox(height: ZadSpacing.xl),
        Text(
          'أو',
          textAlign: TextAlign.center,
          style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.xl),
        TextField(
          controller: _alias,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'اسمك في العيلة (اختياري)',
            hintText: 'مثال: الابن أحمد',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: ZadSpacing.md),
        TextField(
          controller: _code,
          textDirection: TextDirection.ltr,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'كود الدعوة',
            hintText: 'مثال: ZAD-1234',
          ),
          onChanged: (v) {
            final code = extractInviteCode(v);
            if (code != v) {
              _code.value = TextEditingValue(
                text: code,
                selection: TextSelection.collapsed(offset: code.length),
              );
            }
            setState(() {});
          },
        ),
        const SizedBox(height: ZadSpacing.lg),
        SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
            onPressed: widget.busy || !canJoin
                ? null
                : () => controller.join(
                    code: _code.text.trim(),
                    alias: _alias.text.trim(),
                  ),
            icon: const Icon(ZadIcons.forward),
            label: const Text('الانضمام للعائلة'),
          ),
        ),
      ],
    );
  }
}

// ── In a family ─────────────────────────────────────────────────────────────

class _ActiveFamily extends ConsumerStatefulWidget {
  const new({
    required this.family,
    required this.view,
    required this.showFinancials,
    this.initialTab = 0,
  });

  final Family family;
  final FamilyView view;
  final bool showFinancials;
  final int initialTab;

  @override
  ConsumerState<_ActiveFamily> createState() => _ActiveFamilyState();
}

class _ActiveFamilyState extends ConsumerState<_ActiveFamily> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final family = widget.family;
    final view = widget.view;
    final me = family.me(view.userId);
    final isParent = view.isAdmin && widget.showFinancials;

    // The shared-life controller's one-off messages.
    ref.listen<int>(
      familyLifeControllerProvider.select((v) => v.noticeSerial),
      (_, _) {
        final notice = ref.read(familyLifeControllerProvider).notice;
        if (notice != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(notice)));
        }
      },
    );

    final tabs = <(IconData, String)>[
      (ZadIcons.ask, 'الشات'),
      (ZadIcons.chore, 'المهام'),
      (ZadIcons.family, 'الأعضاء'),
      (ZadIcons.shopping, 'البقالة'),
      if (isParent) ...<(IconData, String)>[
        (ZadIcons.wallet, 'الأبناء'),
        (ZadIcons.savings, 'الأهداف'),
      ],
    ];
    final tab = _tab.clamp(0, tabs.length - 1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: <Widget>[
          _Header(family: family),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.gutter,
              ZadSpacing.md,
              ZadSpacing.gutter,
              0,
            ),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  for (final (i, (icon, label)) in tabs.indexed)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: ZadSpacing.sm,
                      ),
                      child: ChoiceChip(
                        avatar: Icon(
                          icon,
                          size: 16,
                          color: tab == i ? Colors.white : ZadColors.slate,
                        ),
                        label: Text(label),
                        selected: tab == i,
                        showCheckmark: false,
                        selectedColor: ZadColors.green700,
                        labelStyle: ZadType.labelLarge.copyWith(
                          color: tab == i ? Colors.white : ZadColors.slate,
                        ),
                        shape: const StadiumBorder(),
                        onSelected: (_) => setState(() => _tab = i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: me == null
                ? const Center(child: CircularProgressIndicator())
                : AnimatedSwitcher(
                    duration: ZadDuration.quick,
                    switchInCurve: ZadCurves.standard,
                    switchOutCurve: ZadCurves.exit,
                    layoutBuilder: (current, previous) => Stack(
                      fit: StackFit.expand,
                      children: <Widget>[...previous, ?current],
                    ),
                    child: KeyedSubtree(
                      key: ValueKey<int>(tab),
                      child: switch (tab) {
                        0 => FamilyChatTab(family: family, me: me),
                        1 => FamilyTasksTab(
                          family: family,
                          isAdmin: view.isAdmin,
                          showFinancials: widget.showFinancials,
                        ),
                        2 => FamilyMembersTab(
                          family: family,
                          view: view,
                          showFinancials: widget.showFinancials,
                        ),
                        3 => const FamilyGroceriesTab(),
                        4 => FamilyKidsTab(family: family),
                        _ => FamilyGoalsTab(family: family),
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const new({required this.family});

  final Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final code = family.inviteCode;
    final members = family.members;
    final owner = familyOwnerAlias(family);
    final shown = members.length > 6 ? 7 : members.length;
    return Container(
      decoration: const BoxDecoration(
        gradient: ZadColors.hero,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(ZadRadii.hero),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.lg,
            ZadSpacing.xs,
            ZadSpacing.lg,
            ZadSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const BackButton(color: Colors.white),
                  Expanded(
                    child: Text(
                      owner == null
                          ? l.familyHeaderTitle
                          : l.familyTitleOf(owner),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZadType.headlineMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'الانضمام للعائلة',
                    onPressed: () =>
                        unawaited(showJoinFamilyDialog(context, ref)),
                    icon: const Icon(ZadIcons.joinFamily, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: ZadSpacing.md),
              Row(
                children: <Widget>[
                  SizedBox(
                    height: 40,
                    width: shown == 0 ? 0 : (shown - 1) * 28 + 40,
                    child: Stack(
                      children: <Widget>[
                        for (final (i, m) in members.take(6).indexed)
                          PositionedDirectional(
                            start: i * 28,
                            child: _PopIn(
                              index: i,
                              child: _HeaderAvatar(
                                text: m.alias.characters.firstOrNull ?? '?',
                              ),
                            ),
                          ),
                        if (members.length > 6)
                          PositionedDirectional(
                            start: 6 * 28,
                            child: _PopIn(
                              index: 6,
                              child: _HeaderAvatar(
                                text: '+${members.length - 6}',
                                strong: true,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.md),
                  Text(
                    l.familyMembersCount(members.length),
                    style: ZadType.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZadSpacing.lg),
              // Named buttons: bare icons on the green read as decoration
              // (owner, 2026-11-09).
              Row(
                children: <Widget>[
                  Expanded(
                    child: _HeaderAction(
                      icon: ZadIcons.invite,
                      label: l.familyActionInvite,
                      onTap: () => unawaited(showInviteDialog(context, code)),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.sm),
                  Expanded(
                    child: _HeaderAction(
                      icon: ZadIcons.share,
                      label: l.familyActionShare,
                      onTap: () => unawaited(
                        SharePlus.instance.share(
                          ShareParams(
                            subject: 'مشاركة الدعوة',
                            text:
                                '🌱 دعوة للانضمام إلى عائلتي على تطبيق زاد\n\n'
                                '📲 اضغط على الرابط التالي للانضمام فوراً '
                                'وفتح التطبيق:\n${inviteLink(code)}\n\n'
                                '🔑 كود الدعوة المباشر:\n$code',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.sm),
                  Expanded(
                    child: _HeaderAction(
                      icon: ZadIcons.sos,
                      label: l.familyActionSos,
                      urgent: true,
                      onTap: () => unawaited(confirmAndSendSos(context, ref)),
                    ),
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

/// A member arriving: each one a beat after the last, and still when the
/// phone asks for reduced motion.
class _PopIn extends StatelessWidget {
  const new({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(
      begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
      end: 1,
    ),
    duration: ZadDuration.settle,
    curve: Interval(index * 0.08, 1, curve: ZadCurves.springy),
    builder: (_, value, c) => Opacity(
      opacity: value.clamp(0, 1),
      child: Transform.scale(scale: value, child: c),
    ),
    child: child,
  );
}

class _HeaderAction extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onTap,
    this.urgent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool urgent;

  @override
  Widget build(BuildContext context) => Material(
    color: urgent
        ? ZadColors.terracottaRust
        : Colors.white.withValues(alpha: 0.14),
    borderRadius: BorderRadius.circular(ZadRadii.chip),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: ZadSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZadType.labelLarge.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HeaderAvatar extends StatelessWidget {
  const new({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Color.alphaBlend(
        Colors.white.withValues(alpha: strong ? 0.4 : 0.25),
        ZadColors.green700,
      ),
      border: Border.all(color: ZadColors.emeraldDeep, width: 2),
    ),
    child: Text(text, style: ZadType.labelLarge.copyWith(color: Colors.white)),
  );
}
