/// Kotlin's shared surfaces and controls, for screens copied from Kotlin:
/// `ZadListCard` and `HeroGradientCard`/`ZadScreenBanner`
/// (`PremiumSurfaces.kt`), `ZadSwitch` (`ZadCupertinoControls.kt`) and
/// `SubScreenTopBar` (`ProfileSubScreens.kt`).
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:zad/design/foundation/compose_shadow.dart';
import 'package:zad/design/tokens/zad_typography.dart';

/// Kotlin's `ZadHeroGradient` — the mockup's mesh (`120deg, #0B6B4E, #0F9B76,
/// #064E3B, #0B6B4E`), static in both themes.
const List<Color> kZadHeroGradient = <Color>[
  Color(0xFF0B6B4E),
  Color(0xFF0F9B76),
  Color(0xFF064E3B),
  Color(0xFF0B6B4E),
];

/// Kotlin's `ZadListCard`: the plain list card — surface, 20dp squircle,
/// `zadCardShadow`, 16dp padding.
class ZadListCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.child,
    this.radius = 20,
    this.color,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  /// The content.
  final Widget child;

  /// Corner radius.
  final double radius;

  /// Fill; the theme's surface by default (`ZadLuxe.cardWhite`).
  final Color? color;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: kZadCardShadow,
    ),
    child: child,
  );
}

/// Kotlin's `HeroGradientCard` at rest (and `ZadScreenBanner`, which is it
/// with a 20dp shape and 18dp padding): the mesh brush drawn between Compose's
/// absolute pixel offsets, a primary-tinted shadow, a 16% white hairline.
class HeroGradientCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });

  /// `ZadScreenBanner`.
  const new banner({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    super.key,
  }) : radius = 20;

  /// The content.
  final Widget child;

  /// Corner radius.
  final double radius;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        // Compose: start (0.35·900 − 300, −250) px, end (1400 − 0.35·500, 850)
        // px, with the loop closed by repeating the first colour.
        const shift = 0.35;
        final start = Offset((shift * 900 - 300) / dpr, -250 / dpr);
        final end = Offset((1400 - shift * 500) / dpr, 850 / dpr);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: composeShadow(
              elevation: 22,
              ambient: primary.withValues(alpha: 0.35),
              spot: primary.withValues(alpha: 0.45),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: CustomPaint(
              painter: _MeshPainter(start: start, end: end),
              child: Container(
                width: w,
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MeshPainter extends CustomPainter {
  new({required this.start, required this.end});

  final Offset start;
  final Offset end;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = <Color>[...kZadHeroGradient, kZadHeroGradient.first];
    final stops = <double>[
      for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
    ];
    final paint = Paint()
      ..shader = ui.Gradient.linear(start, end, colors, stops);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_MeshPainter old) => old.start != start || old.end != end;
}

/// Kotlin's `ZadSwitch`: the iOS switch — 51×31 track, 27dp thumb on a
/// spring (0.6 / 500), primary when on, outlineVariant when off.
class ZadSwitch extends StatefulWidget {
  /// Creates the switch.
  const new({
    required this.value,
    required this.onChanged,
    this.activeColor,
    super.key,
  });

  /// On or off.
  final bool value;

  /// Toggles.
  final ValueChanged<bool>? onChanged;

  /// The track when on; the theme's primary by default.
  final Color? activeColor;

  @override
  State<ZadSwitch> createState() => _ZadSwitchState();
}

class _ZadSwitchState extends State<ZadSwitch>
    with SingleTickerProviderStateMixin {
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 2 * 0.6 * 22.360679774998,
  );

  late final AnimationController _t = AnimationController.unbounded(
    vsync: this,
    value: widget.value ? 1 : 0,
  );

  @override
  void didUpdateWidget(ZadSwitch old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _t.animateWith(
        SpringSimulation(_spring, _t.value, widget.value ? 1 : 0, 0),
      );
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final track = widget.value
        ? (widget.activeColor ?? scheme.primary)
        : scheme.outlineVariant;
    return Semantics(
      toggled: widget.value,
      child: GestureDetector(
        onTap: widget.onChanged == null
            ? null
            : () => widget.onChanged!(!widget.value),
        child: Container(
          width: 51,
          height: 31,
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(31),
          ),
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, child) => Align(
              alignment: AlignmentDirectional(-1 + 2 * _t.value, 0),
              child: child,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: composeShadow(
                    elevation: 2,
                    ambient: Colors.black,
                    spot: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `SubScreenTopBar`: a surface row, the mirrored forward arrow as
/// back, and the title in titleLarge bold.
class SubScreenTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates the bar.
  const new({required this.title, super.key});

  /// The screen's title.
  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(Icons.arrow_forward, color: scheme.onSurface),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: ZadType.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `ZadEmptyState` (`ZadStateComponents.kt`): a 96dp primary-tinted
/// circle with a 44dp icon, the title, the subtitle, an optional action.
/// Without an icon the title is a plain muted line.
class KtEmptyState extends StatelessWidget {
  /// Creates the state.
  const new({
    required this.title,
    this.icon,
    this.subtitle,
    this.action,
    this.iconTint,
    this.iconBackground,
    super.key,
  });

  /// The title.
  final String title;

  /// The glyph.
  final IconData? icon;

  /// Kotlin's `iconTint`; primary at 50% by default.
  final Color? iconTint;

  /// Kotlin's `iconBackground`; primary at 8% by default.
  final Color? iconBackground;

  /// The guidance.
  final String? subtitle;

  /// A button under it.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: icon != null ? 0 : 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color:
                      iconBackground ?? scheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 44,
                  color: iconTint ?? scheme.primary.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: (icon != null ? ZadType.titleMedium : ZadType.bodyMedium)
                  .copyWith(
                    fontWeight: icon != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: icon != null
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: ZadType.bodyMedium.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Kotlin's `ZadSegmentedTabs` (`ZadShell.kt`): a surface pill track with a
/// hairline and the card shadow, 4dp inset; the chosen segment is filled with
/// primary and white 12sp bold text. More than three tabs scroll.
class ZadSegmentedTabs extends StatelessWidget {
  /// Creates the tabs.
  const new({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    super.key,
  });

  /// The labels.
  final List<String> tabs;

  /// The chosen one.
  final int selectedIndex;

  /// Picks one.
  final ValueChanged<int> onSelect;

  /// Kotlin's default modifier padding.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scrollable = tabs.length > 3;

    Widget segment(int i) {
      final selected = i == selectedIndex;
      return Material(
        color: selected ? scheme.primary : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelect(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              tabs[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final children = <Widget>[
      for (var i = 0; i < tabs.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(width: 6),
        if (scrollable) segment(i) else Expanded(child: segment(i)),
      ],
    ];
    return Padding(
      padding: margin,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outline, width: 0.5),
          boxShadow: kZadCardShadow,
        ),
        child: scrollable
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: children),
              )
            : Row(children: children),
      ),
    );
  }
}
