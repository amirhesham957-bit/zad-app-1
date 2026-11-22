/// «العيلة» as one world (ZadWorld.family): with no family, create one or
/// join by code; in one, a house with its people in the scene, one state
/// line (members, tasks ahead, requests waiting), the tabs — الشات, المهام,
/// الأعضاء, البقالة, and for a parent الأبناء and الأهداف — and the family's
/// own actions (invite, share, SOS, join).
///
/// The chat tab keeps the whole height: a compact header, the conversation
/// and the composer docked at the bottom. Every other tab is the world's
/// scroll — scene, tabs, body, links strip.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/family/presentation/family_chat_header.dart';
import 'package:zad/features/family/presentation/family_chat_tab.dart';
import 'package:zad/features/family/presentation/family_dialogs.dart';
import 'package:zad/features/family/presentation/family_scene.dart';
import 'package:zad/features/family/presentation/family_tabs.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/application/family_format.dart';
import 'package:zad/shared/family/application/family_life_controller.dart';
import 'package:zad/shared/family/data/family_repository.dart';
import 'package:zad/shared/family/domain/family.dart';
import 'package:zad/shared/family/domain/family_life.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the screen on [initialTab] — 0 الشات, 1 المهام, 2 الأعضاء,
/// 3 البقالة (and, for a parent, 4 الأبناء, 5 الأهداف).
Future<void> showFamilyScreen(BuildContext context, {int initialTab = 0}) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FamilyScreen(initialTab: initialTab),
      ),
    );

/// The companion stands left of the house.
const ZadWorldZado _stand = ZadWorldZado(left: 30, top: 52, size: 140);

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

    return switch (view.status) {
      InFamily(:final family) => _ActiveFamily(
        family: family,
        view: view,
        showFinancials: showFinancials,
        initialTab: initialTab,
      ),
      NoFamily() => _NoFamily(busy: view.isBusy),
      _ => const _Loading(),
    };
  }
}

// ── Loading ─────────────────────────────────────────────────────────────────

class _Loading extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ZadWorldScaffold(
        world: ZadWorld.family,
        title: l.worldLabelFamily,
        stateLine: l.familyLoadingTitle,
        scene: (loop) => FamilyWorldScene(loop, members: 0),
        zado: _stand,
        onRefresh: ref.read(familyControllerProvider.notifier).refresh,
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
            sliver: SliverList.list(
              children: <Widget>[
                ZadWorldCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l.familyLoadingTitle, style: ZadType.titleMedium),
                      const SizedBox(height: ZadSpacing.xs),
                      Text(
                        l.familyLoadingMessage,
                        style: ZadType.bodyMedium.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.md),
                      TextButton(
                        onPressed: ref
                            .read(familyControllerProvider.notifier)
                            .refresh,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          foregroundColor: ZadWorldColors.family,
                        ),
                        child: Text(l.familyRetry),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = ref.read(familyControllerProvider.notifier);
    // The code alone is enough: the server names a member without an alias
    // «فرد من العيلة». Requiring the alias left the button dead with the
    // alias field scrolled out of sight (owner's phone, 2026-10-30).
    final canJoin = _code.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ZadWorldScaffold(
        world: ZadWorld.family,
        title: l.worldLabelFamily,
        stateLine: l.familyWorldNone,
        scene: (loop) => FamilyWorldScene(loop, members: 0),
        zado: _stand,
        onRefresh: controller.refresh,
        // Creating is the one primary action: docked in the thumb zone, in
        // its own strip, so it never covers a card.
        dockHeight: 88,
        overlay: PositionedDirectional(
          start: ZadSpacing.gutter,
          end: ZadSpacing.gutter,
          bottom: ZadSpacing.md,
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                backgroundColor: ZadWorldColors.family,
              ),
              onPressed: widget.busy
                  ? null
                  : () => controller.create(
                      alias: _alias.text.trim().isEmpty
                          ? null
                          : _alias.text.trim(),
                    ),
              icon: const Icon(ZadIcons.add),
              label: Text(l.familyCreateButton),
            ),
          ),
        ),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
            sliver: SliverList.list(
              children: <Widget>[
                ZadWorldCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l.familyWelcomeTitle, style: ZadType.titleMedium),
                      const SizedBox(height: ZadSpacing.xs),
                      Text(
                        l.familyWelcomeBody,
                        style: ZadType.bodyMedium.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ZadSpacing.md),
                ZadWorldCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l.familyAliasCardTitle, style: ZadType.titleSmall),
                      const SizedBox(height: ZadSpacing.sm),
                      TextField(
                        controller: _alias,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l.familyAliasLabel,
                          hintText: l.familyAliasHint,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ZadSpacing.md),
                ZadWorldCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l.familyJoinCardTitle, style: ZadType.titleSmall),
                      const SizedBox(height: ZadSpacing.sm),
                      TextField(
                        controller: _code,
                        textDirection: TextDirection.ltr,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: l.familyCodeLabel,
                          hintText: l.familyCodeHint,
                        ),
                        onChanged: (v) {
                          final code = extractInviteCode(v);
                          if (code != v) {
                            _code.value = TextEditingValue(
                              text: code,
                              selection: TextSelection.collapsed(
                                offset: code.length,
                              ),
                            );
                          }
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: ZadSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            foregroundColor: ZadWorldColors.family,
                          ),
                          onPressed: widget.busy || !canJoin
                              ? null
                              : () => controller.join(
                                  code: _code.text.trim(),
                                  alias: _alias.text.trim(),
                                ),
                          icon: const Icon(ZadIcons.forward),
                          label: Text(l.familyJoinButton),
                        ),
                      ),
                      const SizedBox(height: ZadSpacing.xs),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          foregroundColor: ZadWorldColors.family,
                        ),
                        onPressed: widget.busy
                            ? null
                            : () =>
                                  unawaited(showJoinFamilyDialog(context, ref)),
                        icon: const Icon(ZadIcons.joinFamily, size: 18),
                        label: Text(l.familyJoinPasteLink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  /// «٣ أفراد · ٢ مهام قدامكم»: the members, then what is waiting — a
  /// parent's money requests first, else the tasks still open. `waiting` is
  /// whether there is anything after the members.
  (String, bool) _stateLine(
    ZadL10n l,
    FamilyLifeView life,
    int members, {
    required bool isParent,
  }) {
    final requests = isParent
        ? life.messages
              .where(
                (m) =>
                    m.type == FamilyMessageType.purchaseRequest &&
                    m.requestStatus == RequestStatus.pending,
              )
              .length
        : 0;
    final chores = life.chores.where((c) => !c.isCompleted).length;
    final waiting = requests > 0 || chores > 0;
    return (
      <String>[
        l.familyMembersCount(members),
        if (requests > 0)
          l.familyWorldRequests(requests)
        else if (chores > 0)
          l.familyWorldChores(chores),
      ].join(' · '),
      waiting,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final family = widget.family;
    final view = widget.view;
    final life = ref.watch(familyLifeControllerProvider);
    final me = family.me(view.userId);
    final isParent = view.isAdmin && widget.showFinancials;
    final owner = familyOwnerAlias(family);
    final title = owner == null ? l.familyHeaderTitle : l.familyTitleOf(owner);
    final (line, waiting) = _stateLine(
      l,
      life,
      family.members.length,
      isParent: isParent,
    );

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
      (ZadIcons.ask, l.familyTabChat),
      (ZadIcons.chore, l.familyTabTasks),
      (ZadIcons.family, l.familyTabMembers),
      (ZadIcons.shopping, l.familyTabGroceries),
      if (isParent) ...<(IconData, String)>[
        (ZadIcons.wallet, l.familyTabKids),
        (ZadIcons.savings, l.familyTabGoals),
      ],
    ];
    final tab = _tab.clamp(0, tabs.length - 1);
    final chips = _TabChips(
      tabs: tabs,
      selected: tab,
      onSelect: (i) => setState(() => _tab = i),
    );
    final pose = waiting ? CompanionState.alert : CompanionState.happy;

    if (tab == 0) {
      // Inside the shell, the shell's own Scaffold already lifts the body
      // over the keyboard; lifting it here too pushed the input up by the
      // keyboard's height twice. Only a pushed screen owns the inset.
      final pushed = ModalRoute.of(context)?.canPop ?? false;
      return Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: pushed,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                ZadWorldColors.tint(ZadWorldColors.family),
                ZadColors.canvasMid,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                FamilyChatHeader(
                  title: title,
                  stateLine: line,
                  members: family.members.length,
                  pose: pose,
                  onSos: () => unawaited(confirmAndSendSos(context, ref)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: ZadSpacing.sm),
                  child: chips,
                ),
                Expanded(
                  child: me == null
                      ? const Center(child: CircularProgressIndicator())
                      : FamilyChatTab(family: family, me: me),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ZadWorldScaffold(
        world: ZadWorld.family,
        eyebrow: l.worldLabelFamily,
        title: title,
        stateLine: line,
        scene: (loop) => FamilyWorldScene(loop, members: family.members.length),
        zado: ZadWorldZado(
          left: _stand.left,
          top: _stand.top,
          size: _stand.size,
          state: pose,
        ),
        onRefresh: tab == 2
            ? ref.read(familyControllerProvider.notifier).refresh
            : ref.read(familyLifeControllerProvider.notifier).refresh,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
              child: chips,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.gutter,
              ZadSpacing.sm,
              ZadSpacing.gutter,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _FamilyCard(family: family)),
          ),
          if (me == null)
            const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            switch (tab) {
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
          if (widget.showFinancials)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
              sliver: SliverToBoxAdapter(child: _MoreCard()),
            ),
        ],
      ),
    );
  }
}

/// The tabs, as chips that scroll sideways.
class _TabChips extends StatelessWidget {
  const new({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<(IconData, String)> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
      children: <Widget>[
        for (final (i, (icon, label)) in tabs.indexed)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: ZadSpacing.sm),
            child: ChoiceChip(
              avatar: Icon(
                icon,
                size: 16,
                color: selected == i ? Colors.white : ZadColors.slate,
              ),
              label: Text(label),
              selected: selected == i,
              showCheckmark: false,
              selectedColor: ZadWorldColors.family,
              backgroundColor: ZadColors.surface,
              labelStyle: ZadType.labelLarge.copyWith(
                color: selected == i ? Colors.white : ZadColors.slate,
              ),
              shape: const StadiumBorder(),
              onSelected: (_) => onSelect(i),
            ),
          ),
      ],
    ),
  );
}

/// Who is in the family and what the family can do from here: invite,
/// share, SOS and join with another code.
class _FamilyCard extends ConsumerWidget {
  const new({required this.family});

  final Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final code = family.inviteCode;
    final members = family.members;
    final shown = members.length > 6 ? 7 : members.length;
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
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
                          child: _Avatar(
                            text: m.alias.characters.firstOrNull ?? '?',
                          ),
                        ),
                      ),
                    if (members.length > 6)
                      PositionedDirectional(
                        start: 6 * 28,
                        child: _PopIn(
                          index: 6,
                          child: _Avatar(
                            text: '+${members.length - 6}',
                            strong: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Text(
                  l.familyMembersCount(members.length),
                  style: ZadType.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          // Named buttons: bare icons read as decoration (owner, 2026-11-09).
          Row(
            children: <Widget>[
              Expanded(
                child: _Action(
                  icon: ZadIcons.invite,
                  label: l.familyActionInvite,
                  onTap: () => unawaited(showInviteDialog(context, code)),
                ),
              ),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: _Action(
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
                child: _Action(
                  icon: ZadIcons.sos,
                  label: l.familyActionSos,
                  urgent: true,
                  onTap: () => unawaited(confirmAndSendSos(context, ref)),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xs),
          TextButton.icon(
            onPressed: () => unawaited(showJoinFamilyDialog(context, ref)),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              foregroundColor: ZadWorldColors.family,
            ),
            icon: const Icon(ZadIcons.joinFamily, size: 18),
            label: Text(l.familyJoinButton),
          ),
        ],
      ),
    );
  }
}

/// The rest of the family's places — savings funds, achievements, the
/// tasbiha garden — for a parent (they are money and rank, never kids mode).
class _MoreCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget tool(IconData icon, String label, OpenScreen open) => InkWell(
      onTap: () => unawaited(open(context)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: <Widget>[
            Icon(icon, color: ZadWorldColors.family),
            const SizedBox(width: ZadSpacing.md),
            Expanded(child: Text(label, style: ZadType.bodyLarge)),
            const Icon(Icons.chevron_left_rounded),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: ZadSpacing.md),
      child: ZadWorldCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.familyMoreTitle, style: ZadType.titleSmall),
            tool(
              ZadIcons.savings,
              l.familyToolSavings,
              ZadScreens.showFamilySavingsScreen,
            ),
            tool(
              ZadIcons.leaderboard,
              l.familyToolAchievements,
              ZadScreens.showAchievementsScreen,
            ),
            tool(
              ZadIcons.tree,
              l.familyToolTasbiha,
              ZadScreens.showTasbihaScreen,
            ),
          ],
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

class _Action extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final fg = urgent ? Colors.white : ZadWorldColors.family;
    return Material(
      color: urgent
          ? ZadColors.terracottaRust
          : ZadWorldColors.family.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(ZadRadii.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: ZadSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.labelLarge.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
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
      color: ZadWorldColors.family.withValues(alpha: strong ? 1 : 0.85),
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Text(text, style: ZadType.labelLarge.copyWith(color: Colors.white)),
  );
}
