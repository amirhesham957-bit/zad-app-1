/// Every section of the app, in one list — Kotlin's `zadAppSections`, which
/// feeds both Home's grid and the "المزيد" sheet so the two cannot drift.
///
/// A section joins this list when its screen exists in this client. Kotlin's
/// appointments, budget, tasbiha, maintenance, statement import and premium
/// plans are not here yet; FLUTTER_PARITY.md tracks them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/brain/presentation/brain_hub_screen.dart';
import 'package:zad/features/brain/presentation/knowledge_map_screen.dart';
import 'package:zad/features/family/presentation/family_screen.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/notifications/presentation/notification_center_screen.dart';
import 'package:zad/features/prices/presentation/prices_screen.dart';
import 'package:zad/features/settings/presentation/settings_screen.dart';
import 'package:zad/features/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/features/subscriptions/presentation/subscriptions_screen.dart';

/// Kotlin's `ZadSectionAccent`, light values: a tile's icon colour, with its
/// container at 12%.
abstract final class ZadSectionAccent {
  /// Emerald.
  static const Color emerald = Color(0xFF047857);

  /// Amber.
  static const Color amber = Color(0xFFB45309);

  /// Violet.
  static const Color violet = Color(0xFF6D28D9);

  /// Blue.
  static const Color blue = Color(0xFF1D4ED8);

  /// Indigo.
  static const Color indigo = Color(0xFF4338CA);

  /// Rose.
  static const Color rose = Color(0xFFBE123C);

  /// Teal.
  static const Color teal = Color(0xFF0F766E);

  /// Slate.
  static const Color slate = Color(0xFF334155);
}

/// Which badge a section carries, if any.
enum SectionBadge {
  /// None.
  none,

  /// Pantry lines that need buying.
  shortages,

  /// Shopping lines not bought yet.
  shopping,

  /// Subscriptions renewing within a week.
  renewals,
}

/// One section.
@immutable
class ZadSection {
  /// Creates a section.
  const new({
    required this.id,
    required this.icon,
    required this.label,
    required this.accent,
    required this.open,
    this.badge = SectionBadge.none,
  });

  /// Kotlin's route name, for deep links later.
  final String id;

  /// Its icon.
  final IconData icon;

  /// Its name.
  final String label;

  /// Its colour.
  final Color accent;

  /// Opens it.
  final Future<void> Function(BuildContext context) open;

  /// Its badge.
  final SectionBadge badge;
}

/// The sections, in Kotlin's order — the first eight are the most used.
final List<ZadSection> zadSections = <ZadSection>[
  ZadSection(
    id: 'inventory',
    icon: ZadIcons.inventory,
    label: 'المخزون',
    accent: ZadSectionAccent.emerald,
    badge: SectionBadge.shortages,
    open: (c) => showHouseholdSection(c, HouseholdSection.pantry),
  ),
  ZadSection(
    id: 'shopping',
    icon: ZadIcons.shopping,
    label: 'قائمة التسوق',
    accent: ZadSectionAccent.amber,
    badge: SectionBadge.shopping,
    open: (c) => showHouseholdSection(c, HouseholdSection.shopping),
  ),
  const ZadSection(
    id: 'family',
    icon: ZadIcons.family,
    label: 'العائلة',
    accent: ZadSectionAccent.violet,
    open: showFamilyScreen,
  ),
  const ZadSection(
    id: 'subscriptions',
    icon: ZadIcons.card,
    label: 'الاشتراكات',
    accent: ZadSectionAccent.indigo,
    badge: SectionBadge.renewals,
    open: showSubscriptionsScreen,
  ),
  ZadSection(
    id: 'pharmacy',
    icon: ZadIcons.pharmacy,
    label: 'صيدلية العائلة',
    accent: ZadSectionAccent.rose,
    open: (c) => showHouseholdSection(c, HouseholdSection.pharmacy),
  ),
  ZadSection(
    id: 'recipes',
    icon: ZadIcons.chef,
    label: 'شيف زاد',
    accent: ZadSectionAccent.emerald,
    open: (c) => showHouseholdSection(c, HouseholdSection.recipes),
  ),
  const ZadSection(
    id: 'assistant',
    icon: ZadIcons.brain,
    label: 'عقل زاد',
    accent: ZadSectionAccent.teal,
    open: showBrainHub,
  ),
  const ZadSection(
    id: 'deals',
    icon: ZadIcons.prices,
    label: 'الأسعار والعروض',
    accent: ZadSectionAccent.blue,
    open: showPricesScreen,
  ),
  const ZadSection(
    id: 'knowledge_map',
    icon: ZadIcons.knowledgeMap,
    label: 'خريطة زاد',
    accent: ZadSectionAccent.blue,
    open: showKnowledgeMap,
  ),
  const ZadSection(
    id: 'notifications',
    icon: ZadIcons.notifications,
    label: 'الإشعارات',
    accent: ZadSectionAccent.amber,
    open: showNotificationCenter,
  ),
  const ZadSection(
    id: 'profile',
    icon: ZadIcons.settings,
    label: 'حسابي',
    accent: ZadSectionAccent.slate,
    open: showSettingsScreen,
  ),
];

/// How many columns the grid has.
const int kSectionColumns = 4;

/// How many sections show before "كل الأقسام".
const int kSectionsCollapsed = 8;

/// Home's grid: two rows, and the rest behind "كل الأقسام".
class SectionsGrid extends ConsumerStatefulWidget {
  /// Creates the grid.
  const new({super.key});

  @override
  ConsumerState<SectionsGrid> createState() => _SectionsGridState();
}

class _SectionsGridState extends ConsumerState<SectionsGrid> {
  bool _expanded = false;

  int _badgeFor(SectionBadge badge) => switch (badge) {
    SectionBadge.none => 0,
    SectionBadge.shortages => ref.watch(
      pantryControllerProvider.select((v) => v.shortages.length),
    ),
    SectionBadge.shopping => ref.watch(
      shoppingControllerProvider.select((v) => v.outstanding.length),
    ),
    SectionBadge.renewals => ref.watch(
      subscriptionsControllerProvider.select(renewalsWithinAWeek),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final head = zadSections.take(kSectionsCollapsed).toList();
    final rest = zadSections.skip(kSectionsCollapsed).toList();
    return Column(
      children: <Widget>[
        _Rows(sections: head, badgeFor: _badgeFor),
        AnimatedSize(
          duration: ZadDuration.enter,
          curve: ZadCurves.standard,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: ZadSpacing.md),
                  child: _Rows(sections: rest, badgeFor: _badgeFor),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (rest.isNotEmpty)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: ZadColors.forestEmerald,
              minimumSize: const Size(44, 44),
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _expanded
                      ? 'أقسام أقل'
                      : 'كل الأقسام (${zadSections.length})',
                  style: ZadType.labelLarge.copyWith(
                    color: ZadColors.forestEmerald,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: ZadSpacing.xs),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: ZadDuration.quick,
                  child: const Icon(
                    ZadIcons.expand,
                    size: 20,
                    color: ZadColors.forestEmerald,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The count of running subscriptions renewing within seven days — Kotlin's
/// badge on the subscriptions tile.
int renewalsWithinAWeek(SubscriptionsView view) {
  var n = 0;
  for (final s in view.active) {
    final next = s.nextRenewalFrom(view.today);
    if (next == null) continue;
    final days = next.difference(view.today).inDays;
    if (days >= 0 && days <= 7) n++;
  }
  return n;
}

class _Rows extends StatelessWidget {
  const new({required this.sections, required this.badgeFor});

  final List<ZadSection> sections;
  final int Function(SectionBadge) badgeFor;

  @override
  Widget build(BuildContext context) {
    final rows = <List<ZadSection>>[
      for (var i = 0; i < sections.length; i += kSectionColumns)
        sections.sublist(
          i,
          i + kSectionColumns > sections.length
              ? sections.length
              : i + kSectionColumns,
        ),
    ];
    return Column(
      children: <Widget>[
        for (var r = 0; r < rows.length; r++) ...<Widget>[
          if (r > 0) const SizedBox(height: ZadSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var c = 0; c < kSectionColumns; c++) ...<Widget>[
                if (c > 0) const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: c < rows[r].length
                      ? SectionTile(
                          section: rows[r][c],
                          badge: badgeFor(rows[r][c].badge),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// One tile: a tinted rounded square with the icon, a badge on its corner,
/// the name under it.
class SectionTile extends StatelessWidget {
  /// Creates a tile.
  const new({required this.section, this.badge = 0, super.key});

  /// The section.
  final ZadSection section;

  /// The number on its corner; nothing when zero.
  final int badge;

  @override
  Widget build(BuildContext context) => ZadPressable(
    onPressed: () => section.open(context),
    semanticLabel: badge > 0 ? '${section.label}، $badge' : section.label,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
      child: Column(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: section.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ZadRadii.card),
                  border: Border.all(
                    color: section.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(section.icon, size: 24, color: section.accent),
              ),
              if (badge > 0)
                PositionedDirectional(
                  top: -4,
                  end: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: ZadColors.terracottaRust,
                      borderRadius: BorderRadius.circular(ZadRadii.pill),
                      border: Border.all(color: ZadColors.surface, width: 1.5),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: ZadType.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          Text(
            section.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: ZadType.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: ZadColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}
