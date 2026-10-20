/// The rest of Kotlin's chrome (`ui/components/ZadShell.kt`): the header on
/// top of every shell screen, the drawer behind the menu square, the المزيد
/// sheet and the camera sheet. Same measures, same colours, same strings.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zad/app/shell/zad_sky.dart';
import 'package:zad/core/design/components/zad_network_image.dart';
import 'package:zad/core/design/components/zad_pressable.dart';
import 'package:zad/core/design/components/zad_pulses.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_shell_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/home/presentation/sections_grid.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// Kotlin's `textTertiary`.
Color get _textTertiary => ZadColors.textTertiary;

/// Kotlin's `surfaceContainerLow`.
Color get _surfaceContainerLow => ZadColors.surfaceLow;

/// Kotlin's `error` (`ZadTerracottaRust`).
Color get _danger => ZadColors.terracottaRust;

/// Kotlin's `kidsPrimary`.
const Color _kidsPrimary = Color(0xFF6B46C1);

const String _carrot = 'assets/brand/carrot_logo.svg';

// ── header ───────────────────────────────────────────────────────────────────

/// `ZadTopHeader`: `rgba(251,251,250,.92)`, the 32dp menu square, the carrot
/// tile and «زاد», the avatar and the bell pill, then the 26sp title on its
/// own line — and a 1dp green rule under all of it.
class ZadTopHeader extends StatelessWidget {
  /// Creates the header.
  const new({
    required this.title,
    required this.onOpenDrawer,
    required this.onNotifications,
    required this.onAvatar,
    this.hasUnreadNotifications = false,
    this.avatarUrl,
    this.kidsMode = false,
    this.onExitKidsMode,
    this.pet,
    this.sky = SkyPhase.day,
    super.key,
  });

  /// The time of day the header's sky shows (zad_sky.dart).
  final SkyPhase sky;

  /// The screen's title.
  final String title;

  /// رفيق زاد, perched at the end of the title line on the header's rule
  /// (Home only).
  final Widget? pet;

  /// The menu square.
  final VoidCallback onOpenDrawer;

  /// The bell.
  final VoidCallback onNotifications;

  /// The avatar.
  final VoidCallback onAvatar;

  /// Shakes the bell and shows its dot.
  final bool hasUnreadNotifications;

  /// The picture, when there is one.
  final String? avatarUrl;

  /// Adds the «وضع الأطفال» badge and the exit pill.
  final bool kidsMode;

  /// The exit pill.
  final VoidCallback? onExitKidsMode;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      ColoredBox(
        color: _surfaceContainerLow.withValues(alpha: 0.92),
        child: ZadSky(
          phase: sky,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _Square(
                        size: 32,
                        radius: 10,
                        color: kShellPrimary.withValues(alpha: 0.08),
                        onTap: onOpenDrawer,
                        semantic: context.l10n.navMore,
                        child: const Icon(
                          Icons.menu,
                          size: 18,
                          color: kShellPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const _CarrotTile(size: 32, radius: 9, glyph: 18),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.appTitle,
                        style: const TextStyle(
                          fontSize: 19,
                          height: 22 / 19,
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w700,
                          color: kShellPrimary,
                        ),
                      ),
                      if (kidsMode) ...<Widget>[
                        const SizedBox(width: 8),
                        _KidsPill(context.l10n.drawerKidsMode, fontSize: 11),
                      ],
                      const Spacer(),
                      if (kidsMode && onExitKidsMode != null) ...<Widget>[
                        _KidsPill(
                          context.l10n.drawerFullMode,
                          fontSize: 11.5,
                          onTap: onExitKidsMode,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _Avatar(url: avatarUrl, onTap: onAvatar),
                      const SizedBox(width: 8),
                      _BellPill(
                        unread: hasUnreadNotifications,
                        onTap: onNotifications,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 26,
                            height: 32 / 26,
                            letterSpacing: 0.2,
                            fontWeight: FontWeight.w700,
                            color: kShellTextPrimary,
                          ),
                        ),
                      ),
                      // Down by the bottom padding, so it sits on the rule.
                      if (pet case final pet?)
                        Transform.translate(
                          offset: const Offset(0, 14),
                          child: pet,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ColoredBox(
        color: kShellPrimary.withValues(alpha: 0.06),
        child: const SizedBox(height: 1, width: double.infinity),
      ),
    ],
  );
}

class _Square extends StatelessWidget {
  const new({
    required this.size,
    required this.radius,
    required this.color,
    required this.child,
    this.onTap,
    this.semantic,
  });

  final double size;
  final double radius;
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final String? semantic;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: semantic,
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Center(child: child),
        ),
      ),
    ),
  );
}

class _CarrotTile extends StatelessWidget {
  const new({required this.size, required this.radius, required this.glyph});

  final double size;
  final double radius;
  final double glyph;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFE6F4EC),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: SvgPicture.asset(_carrot, width: glyph, height: glyph),
  );
}

class _KidsPill extends StatelessWidget {
  const new(
    this.text, {
    required this.fontSize,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
  });

  final String text;
  final double fontSize;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
    color: _kidsPrimary.withValues(alpha: 0.10),
    shape: const StadiumBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            height: 22 / fontSize,
            fontWeight: FontWeight.w700,
            color: _kidsPrimary,
          ),
        ),
      ),
    ),
  );
}

/// 44dp, primary at 12%, the picture cropped into it or the person glyph.
class _Avatar extends StatelessWidget {
  const new({required this.url, required this.onTap, this.initial});

  final String? url;
  final VoidCallback onTap;
  final String? initial;

  @override
  Widget build(BuildContext context) {
    final u = url;
    final fallback = initial != null
        ? Text(
            initial!,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: kShellPrimary,
            ),
          )
        : const Icon(Icons.person, size: 20, color: kShellPrimary);
    return Semantics(
      button: true,
      label: context.l10n.shellOpenProfile,
      child: Material(
        color: kShellPrimary.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: u == null || u.isEmpty
                ? Center(child: fallback)
                : ZadNetworkImage(
                    u,
                    fit: BoxFit.cover,
                    // Kotlin's placeholder and error are the same default
                    // avatar; here the glyph stands in for it.
                    fallback: Center(child: fallback),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The trailing pill: the bell, shaking and dotted while anything is unread.
class _BellPill extends StatelessWidget {
  const new({required this.unread, required this.onTap});

  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.drawerNotifications,
    child: Material(
      color: kShellPrimary.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: ZadBellShake(
                enabled: unread,
                child: const Icon(
                  Icons.notifications,
                  size: 18,
                  color: kShellPrimary,
                ),
              ),
            ),
            if (unread)
              PositionedDirectional(
                top: 0,
                end: 0,
                child: SizedBox.square(
                  dimension: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ── drawer ───────────────────────────────────────────────────────────────────

/// One row of the drawer.
@immutable
class ZadDrawerEntry {
  /// Creates a row.
  const new({
    required this.id,
    required this.icon,
    required this.label,
    this.accent = ZadSectionAccent.slate,
    this.group,
  });

  /// The route it opens.
  final String id;

  /// Its glyph.
  final IconData icon;

  /// Its name, in the app's language.
  final String Function(ZadL10n) label;

  /// The colour of its tile — the section's own, as on the home grid.
  final Color accent;

  /// The heading it sits under; a change of group starts a new heading.
  final String Function(ZadL10n)? group;
}

// The drawer's names, resolved in the app's language when drawn.
String _navHome(ZadL10n l) => l.navHome;
String _drawerCompanion(ZadL10n l) => l.drawerCompanion;
String _drawerBrain(ZadL10n l) => l.drawerBrain;
String _drawerAppointments(ZadL10n l) => l.drawerAppointments;
String _drawerPlaces(ZadL10n l) => l.drawerPlaces;
String _navMoney(ZadL10n l) => l.navMoney;
String _drawerObligations(ZadL10n l) => l.drawerObligations;
String _drawerPlans(ZadL10n l) => l.drawerPlans;
String _navHomeStock(ZadL10n l) => l.navHomeStock;
String _drawerShopping(ZadL10n l) => l.drawerShopping;
String _drawerPharmacy(ZadL10n l) => l.drawerPharmacy;
String _drawerMaintenance(ZadL10n l) => l.drawerMaintenance;
String _drawerDocuments(ZadL10n l) => l.drawerDocuments;
String _drawerNearby(ZadL10n l) => l.drawerNearby;
String _navMyFamily(ZadL10n l) => l.navMyFamily;
String _drawerTips(ZadL10n l) => l.drawerTips;
String _drawerTasbiha(ZadL10n l) => l.drawerTasbiha;
String _drawerNotifications(ZadL10n l) => l.drawerNotifications;
String _drawerAccount(ZadL10n l) => l.drawerAccount;
String _drawerGroupZad(ZadL10n l) => l.drawerGroupZad;
String _drawerGroupMoney(ZadL10n l) => l.drawerGroupMoney;
String _drawerGroupHome(ZadL10n l) => l.drawerGroupHome;
String _drawerGroupMore(ZadL10n l) => l.drawerGroupMore;

/// The drawer: everything, grouped by the bar's four places (2026-09-30) —
/// زاد and what the brain knows, then فلوسي, بيتي, عيلتي, and the rest. رفيق
/// زاد sits second, under الرئيسية (owner, 2026-10-13: it was missing).
const List<ZadDrawerEntry> zadDrawerEntries = <ZadDrawerEntry>[
  ZadDrawerEntry(
    id: 'home',
    icon: Icons.home_rounded,
    label: _navHome,
    accent: ZadSectionAccent.emerald,
    group: _drawerGroupZad,
  ),
  ZadDrawerEntry(
    id: 'companion',
    icon: Icons.pets_rounded,
    label: _drawerCompanion,
    accent: ZadSectionAccent.amber,
    group: _drawerGroupZad,
  ),
  ZadDrawerEntry(
    id: 'assistant',
    icon: Icons.psychology,
    label: _drawerBrain,
    accent: ZadSectionAccent.teal,
    group: _drawerGroupZad,
  ),
  ZadDrawerEntry(
    id: 'appointments',
    icon: Icons.event,
    label: _drawerAppointments,
    accent: ZadSectionAccent.indigo,
    group: _drawerGroupZad,
  ),
  ZadDrawerEntry(
    id: 'places',
    icon: Icons.place,
    label: _drawerPlaces,
    accent: ZadSectionAccent.rose,
    group: _drawerGroupZad,
  ),
  ZadDrawerEntry(
    id: 'budget',
    icon: Icons.account_balance_wallet,
    label: _navMoney,
    accent: ZadSectionAccent.green,
    group: _drawerGroupMoney,
  ),
  ZadDrawerEntry(
    id: 'subscriptions',
    icon: Icons.credit_card,
    label: _drawerObligations,
    accent: ZadSectionAccent.blue,
    group: _drawerGroupMoney,
  ),
  ZadDrawerEntry(
    id: 'premium',
    icon: Icons.star_rounded,
    label: _drawerPlans,
    accent: ZadSectionAccent.amber,
    group: _drawerGroupMoney,
  ),
  ZadDrawerEntry(
    id: 'inventory',
    icon: Icons.kitchen,
    label: _navHomeStock,
    accent: ZadSectionAccent.emerald,
    group: _drawerGroupHome,
  ),
  ZadDrawerEntry(
    id: 'shopping',
    icon: Icons.shopping_cart,
    label: _drawerShopping,
    accent: ZadSectionAccent.brown,
    group: _drawerGroupHome,
  ),
  ZadDrawerEntry(
    id: 'pharmacy',
    icon: Icons.local_pharmacy,
    label: _drawerPharmacy,
    accent: ZadSectionAccent.rose,
    group: _drawerGroupHome,
  ),
  ZadDrawerEntry(
    id: 'maintenance',
    icon: Icons.build,
    label: _drawerMaintenance,
    group: _drawerGroupHome,
  ),
  ZadDrawerEntry(
    id: 'documents',
    icon: Icons.badge_outlined,
    label: _drawerDocuments,
    accent: ZadSectionAccent.indigo,
    group: _drawerGroupHome,
  ),
  ZadDrawerEntry(
    id: 'deals',
    icon: Icons.storefront,
    label: _drawerNearby,
    accent: ZadSectionAccent.teal,
    group: _drawerGroupHome,
  ),
  ZadDrawerEntry(
    id: 'family',
    icon: Icons.family_restroom,
    label: _navMyFamily,
    accent: ZadSectionAccent.violet,
    group: _drawerGroupHome,
  ),
  ZadDrawerEntry(
    id: 'tips',
    icon: Icons.lightbulb,
    label: _drawerTips,
    accent: ZadSectionAccent.amber,
    group: _drawerGroupMore,
  ),
  ZadDrawerEntry(
    id: 'tasbiha',
    icon: Icons.park,
    label: _drawerTasbiha,
    accent: ZadSectionAccent.green,
    group: _drawerGroupMore,
  ),
  ZadDrawerEntry(
    id: 'notifications',
    icon: Icons.notifications,
    label: _drawerNotifications,
    accent: ZadSectionAccent.blue,
    group: _drawerGroupMore,
  ),
  ZadDrawerEntry(
    id: 'profile',
    icon: Icons.person,
    label: _drawerAccount,
    group: _drawerGroupMore,
  ),
];

/// `ZadDrawerContent`, redrawn 2026-10-13 (owner: «كئيبة»): the companion
/// greeting on a green card at the top, the rows under coloured headings
/// with each section's own tile colour, and the rows sliding in one after
/// another as the drawer opens. The profile row stays at the foot.
class ZadDrawer extends StatefulWidget {
  /// Creates the drawer.
  const new({
    required this.current,
    required this.entries,
    required this.onNavigate,
    required this.onProfile,
    this.userName,
    this.avatarUrl,
    super.key,
  });

  /// The route showing, lit in the list.
  final String? current;

  /// The rows — all of them, or home and family in kids mode.
  final List<ZadDrawerEntry> entries;

  /// A row was tapped.
  final ValueChanged<String> onNavigate;

  /// The profile row.
  final VoidCallback onProfile;

  /// The name at the foot.
  final String? userName;

  /// The picture at the foot.
  final String? avatarUrl;

  @override
  State<ZadDrawer> createState() => _ZadDrawerState();
}

class _ZadDrawerState extends State<ZadDrawer>
    with SingleTickerProviderStateMixin {
  static const Color _rule = Color(0x0F000000);

  // The drawer is built when it opens, so the cascade plays on every open.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: ZadDuration.settle + ZadDuration.enter,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _enter.value = 1;
    } else if (!_enter.isAnimating && _enter.value == 0) {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  /// Row [i] of [n] slides in from the start edge, a beat after the one
  /// above it.
  Widget _staggered(int i, int n, Widget child) {
    final start = (i / math.max(1, n)) * 0.45;
    final curve = CurvedAnimation(
      parent: _enter,
      curve: Interval(
        start,
        math.min(1, start + 0.55),
        curve: ZadCurves.standard,
      ),
    );
    return AnimatedBuilder(
      animation: curve,
      child: child,
      builder: (context, child) {
        final t = curve.value;
        final dir = Directionality.of(context) == TextDirection.rtl ? 1 : -1;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(dir * 24 * (1 - t), 0),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    var index = 0;
    final n = widget.entries.length;
    String? group;
    for (final e in widget.entries) {
      final heading = e.group?.call(context.l10n);
      if (heading != null && heading != group) {
        group = heading;
        rows.add(
          _staggered(
            index,
            n,
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                ZadSpacing.md,
                rows.isEmpty ? ZadSpacing.xs : ZadSpacing.lg,
                ZadSpacing.md,
                ZadSpacing.xs,
              ),
              child: Text(
                heading,
                style: ZadType.labelMedium.copyWith(
                  color: _textTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }
      rows.add(
        _staggered(
          index,
          n,
          _DrawerRow(
            entry: e,
            active: widget.current == e.id,
            onTap: () => widget.onNavigate(e.id),
          ),
        ),
      );
      index++;
    }

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.8,
      backgroundColor: ZadColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.horizontal(
          end: Radius.circular(ZadRadii.sheet),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          _CompanionHeader(
            userName: widget.userName,
            enter: _enter,
            onOpen: () => widget.onNavigate('companion'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.sm,
                ZadSpacing.sm,
                ZadSpacing.sm,
                ZadSpacing.lg,
              ),
              children: rows,
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _rule),
          InkWell(
            onTap: widget.onProfile,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(ZadSpacing.lg),
                child: Row(
                  children: <Widget>[
                    IgnorePointer(
                      child: _Avatar(
                        url: widget.avatarUrl,
                        onTap: widget.onProfile,
                        initial:
                            (widget.userName == null ||
                                widget.userName!.isEmpty)
                            ? 'Z'
                            : widget.userName!.characters.first.toUpperCase(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.userName ?? context.l10n.shellZadUser,
                            style: ZadType.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: kShellTextPrimary,
                            ),
                          ),
                          Text(
                            context.l10n.shellOpenProfile,
                            style: ZadType.labelSmall.copyWith(
                              color: _textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_left, size: 20, color: _textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The top of the drawer: the customer's own companion, alive, on the green
/// card, with a hello and where it stands. A tap opens its studio.
class _CompanionHeader extends ConsumerWidget {
  const new({
    required this.userName,
    required this.enter,
    required this.onOpen,
  });

  final String? userName;
  final Animation<double> enter;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(companionProvider).value;
    final look = ref.watch(companionLookProvider);
    final name = (userName == null || userName!.trim().isEmpty)
        ? null
        : userName!.trim().split(' ').first;
    final pop = CurvedAnimation(parent: enter, curve: ZadCurves.springy);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Ink(
          decoration: const BoxDecoration(gradient: ZadColors.hero),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ZadSpacing.lg,
                ZadSpacing.lg,
                ZadSpacing.lg,
                ZadSpacing.lg,
              ),
              child: Row(
                children: <Widget>[
                  ScaleTransition(
                    scale: pop,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      child: Center(child: CompanionOrb(size: 72, look: look)),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name == null
                              ? context.l10n.shellHello
                              : context.l10n.shellHelloName(name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZadType.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: ZadSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ZadSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(ZadRadii.pill),
                          ),
                          child: Text(
                            status == null
                                ? context.l10n.drawerCompanion
                                : context.l10n.shellCompanionTag(
                                    status.persona.name,
                                    status.level,
                                  ),
                            style: ZadType.labelMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (status != null) ...<Widget>[
                          const SizedBox(height: ZadSpacing.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(ZadRadii.pill),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              value: status.levelNeed <= 0
                                  ? 0
                                  : (status.levelXp / status.levelNeed).clamp(
                                      0.0,
                                      1.0,
                                    ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                ZadColors.mintGlow,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left, color: Colors.white70),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  const new({required this.entry, required this.active, required this.onTap});

  final ZadDrawerEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Material(
      color: active ? entry.accent.withValues(alpha: 0.10) : Colors.transparent,
      borderRadius: BorderRadius.circular(ZadRadii.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ZadSpacing.sm,
              vertical: 6,
            ),
            child: Row(
              children: <Widget>[
                AnimatedContainer(
                  duration: ZadDuration.quick,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active
                        ? entry.accent
                        : entry.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(ZadRadii.chip - 2),
                  ),
                  child: Icon(
                    entry.icon,
                    size: 19,
                    color: active ? Colors.white : entry.accent,
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                Expanded(
                  child: Text(
                    entry.label(context.l10n),
                    style: ZadType.titleSmall.copyWith(
                      fontSize: 14.5,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? entry.accent : kShellTextPrimary,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: entry.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ── المزيد ───────────────────────────────────────────────────────────────────

/// `ZadMoreSheet`: every section but the two the bar already has, two to a
/// row. Returns the id tapped.
Future<String?> showZadMoreSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZadColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _MoreSheet(),
    );

class _MoreSheet extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final entries = <ZadSection>[
      for (final s in zadSections)
        if (s.id != 'inventory' && s.id != 'assistant') s,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                context.l10n.navMore,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kShellTextPrimary,
                ),
              ),
            ),
            for (var i = 0; i < entries.length; i += 2) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(child: _MoreTile(entries[i])),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < entries.length
                        ? _MoreTile(entries[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const new(this.section);

  final ZadSection section;

  @override
  Widget build(BuildContext context) => ZadPressable(
    scale: 0.96,
    onPressed: () => Navigator.of(context).pop(section.id),
    semanticLabel: section.label(context.l10n),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: section.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(section.icon, size: 18, color: section.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              section.label(context.l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 22 / 13,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w700,
                color: kShellTextPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
