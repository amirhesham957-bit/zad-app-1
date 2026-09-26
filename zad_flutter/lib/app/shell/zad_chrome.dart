/// The rest of Kotlin's chrome (`ui/components/ZadShell.kt`): the header on
/// top of every shell screen, the drawer behind the menu square, the المزيد
/// sheet and the camera sheet. Same measures, same colours, same strings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/components/zad_pulses.dart';
import 'package:zad/features/home/presentation/sections_grid.dart';

/// Kotlin's `primary`.
const Color kShellPrimary = Color(0xFF1B4332);

/// Kotlin's `textPrimary` (`onSurface`, ZadNeutralDark).
const Color kShellTextPrimary = Color(0xFF1F1F14);

/// Kotlin's `onSurfaceVariant` / `textSecondary`.
const Color _textSecondary = Color(0xFF5F6258);

/// Kotlin's `textTertiary`.
const Color _textTertiary = Color(0xFF6E7065);

/// Kotlin's `surfaceContainerLow`.
const Color _surfaceContainerLow = Color(0xFFFBFBFA);

/// Kotlin's `error` (`ZadTerracottaRust`).
const Color _danger = Color(0xFFD95726);

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
    super.key,
  });

  /// The screen's title.
  final String title;

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
                      semantic: 'المزيد',
                      child: const Icon(
                        Icons.menu,
                        size: 18,
                        color: kShellPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const _CarrotTile(size: 32, radius: 9, glyph: 18),
                    const SizedBox(width: 10),
                    const Text(
                      'زاد',
                      style: TextStyle(
                        fontSize: 19,
                        height: 22 / 19,
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w700,
                        color: kShellPrimary,
                      ),
                    ),
                    if (kidsMode) ...<Widget>[
                      const SizedBox(width: 8),
                      const _KidsPill('وضع الأطفال', fontSize: 11),
                    ],
                    const Spacer(),
                    if (kidsMode && onExitKidsMode != null) ...<Widget>[
                      _KidsPill(
                        'الوضع الكامل',
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
                Text(
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
              ],
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
      label: 'اضغط لعرض الملف الشخصي',
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
                : Image.network(
                    u,
                    fit: BoxFit.cover,
                    // Kotlin's placeholder and error are the same default
                    // avatar; here the glyph stands in for it.
                    errorBuilder: (_, _, _) => Center(child: fallback),
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
    label: 'الإشعارات',
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
              const PositionedDirectional(
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
  const new({required this.id, required this.icon, required this.label});

  /// The route it opens.
  final String id;

  /// Its glyph.
  final IconData icon;

  /// Its name.
  final String label;
}

/// Kotlin's `zadDrawerEntries`, in order.
const List<ZadDrawerEntry> zadDrawerEntries = <ZadDrawerEntry>[
  ZadDrawerEntry(id: 'home', icon: Icons.home, label: 'الرئيسية'),
  ZadDrawerEntry(id: 'inventory', icon: Icons.inventory_2, label: 'المخزون'),
  ZadDrawerEntry(id: 'assistant', icon: Icons.psychology, label: 'عقل زاد'),
  ZadDrawerEntry(
    id: 'subscriptions',
    icon: Icons.credit_card,
    label: 'الاشتراكات والأقساط',
  ),
  ZadDrawerEntry(
    id: 'shopping',
    icon: Icons.shopping_cart,
    label: 'قائمة التسوق',
  ),
  ZadDrawerEntry(id: 'family', icon: Icons.family_restroom, label: 'العائلة'),
  ZadDrawerEntry(id: 'budget', icon: Icons.bar_chart, label: 'الميزانية'),
  ZadDrawerEntry(
    id: 'pharmacy',
    icon: Icons.local_pharmacy,
    label: 'صيدلية العائلة',
  ),
  ZadDrawerEntry(id: 'maintenance', icon: Icons.build, label: 'صيانة المنزل'),
  ZadDrawerEntry(
    id: 'deals',
    icon: Icons.location_on,
    label: 'المتاجر والأسواق القريبة',
  ),
  ZadDrawerEntry(id: 'tasbiha', icon: Icons.park, label: 'تسبيحة'),
  ZadDrawerEntry(id: 'profile', icon: Icons.person, label: 'حسابي'),
  ZadDrawerEntry(
    id: 'notifications',
    icon: Icons.notifications,
    label: 'الإشعارات',
  ),
];

/// `ZadDrawerContent`: 78% wide, square-edged, the carrot and «زاد», the
/// rows, and the profile row at the foot.
class ZadDrawer extends StatelessWidget {
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

  static const Color _rule = Color(0x0F000000);

  @override
  Widget build(BuildContext context) => Drawer(
    width: MediaQuery.sizeOf(context).width * 0.78,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(),
    child: Column(
      children: <Widget>[
        const SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 20, 20, 18),
            child: Row(
              children: <Widget>[
                _CarrotTile(size: 34, radius: 10, glyph: 20),
                SizedBox(width: 10),
                Text(
                  'زاد',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kShellPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _rule),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: <Widget>[
              for (final e in entries) ...<Widget>[
                _DrawerRow(
                  entry: e,
                  active: current == e.id,
                  onTap: () => onNavigate(e.id),
                ),
                const SizedBox(height: 2),
              ],
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _rule),
        InkWell(
          onTap: onProfile,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  IgnorePointer(
                    child: _Avatar(
                      url: avatarUrl,
                      onTap: onProfile,
                      initial: (userName == null || userName!.isEmpty)
                          ? 'Z'
                          : userName!.characters.first.toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          userName ?? 'مستخدم زاد',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: kShellTextPrimary,
                          ),
                        ),
                        const Text(
                          'اضغط لعرض الملف الشخصي',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_left,
                    size: 20,
                    color: _textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DrawerRow extends StatelessWidget {
  const new({required this.entry, required this.active, required this.onTap});

  final ZadDrawerEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: active ? kShellPrimary.withValues(alpha: 0.08) : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: <Widget>[
            Icon(
              entry.icon,
              size: 19,
              color: active ? kShellPrimary : _textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                entry.label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? kShellPrimary : _textSecondary,
                ),
              ),
            ),
          ],
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
      backgroundColor: Colors.white,
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'المزيد',
                style: TextStyle(
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
    semanticLabel: section.label,
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
              section.label,
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

// ── camera ───────────────────────────────────────────────────────────────────

/// What the camera sheet was asked for.
enum ZadCameraChoice {
  /// مسح مخزون.
  inventory,

  /// مسح فاتورة.
  receipt,
}

/// `ZadCameraSheet`: the title, the green 150dp plate, then مسح مخزون and
/// مسح فاتورة side by side, and إلغاء.
Future<ZadCameraChoice?> showZadCameraSheet(BuildContext context) =>
    showModalBottomSheet<ZadCameraChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CameraSheet(),
    );

class _CameraSheet extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 0, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'زاد الذكي بالكاميرا',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kShellTextPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kShellPrimary,
              // ZadLuxe.squircle is a plain 20dp rounded rectangle.
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.camera_alt,
              size: 36,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _SheetButton(
                  text: 'مسح مخزون',
                  container: kShellPrimary,
                  content: Colors.white,
                  onTap: () =>
                      Navigator.of(context).pop(ZadCameraChoice.inventory),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetButton(
                  text: 'مسح فاتورة',
                  container: kShellPrimary.withValues(alpha: 0.06),
                  content: kShellTextPrimary,
                  onTap: () =>
                      Navigator.of(context).pop(ZadCameraChoice.receipt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SheetButton extends StatelessWidget {
  const new({
    required this.text,
    required this.container,
    required this.content,
    required this.onTap,
  });

  final String text;
  final Color container;
  final Color content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZadPressable(
    scale: 0.96,
    onPressed: onTap,
    semanticLabel: text,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: content,
        ),
      ),
    ),
  );
}
