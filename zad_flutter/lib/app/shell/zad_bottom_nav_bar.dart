/// Kotlin's `ZadBottomNavBar` (`ui/components/ZadShell.kt`), measure for
/// measure: a floating 64dp capsule 16dp in from the sides and 22dp above the
/// system bar, four tabs — الرئيسية · عقل زاد · [mic + camera] · المخزون ·
/// المزيد — and the raised action cluster over the middle: the pulsing
/// emerald mic orb and the camera button beside it.
///
/// Kids mode collapses it to الرئيسية · العائلة, with no mic and no camera.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/foundation/compose_shadow.dart';

/// Kotlin's `primary` (`ZadForestEmerald`).
const Color _primary = Color(0xFF1B4332);

/// Kotlin's `textTertiary`.
const Color _textTertiary = Color(0xFF6E7065);

/// Kotlin's `outline` (`ZadIosOutline`).
const Color _outline = Color(0xFFE0E3DA);

/// Kotlin's `surface` / `surfaceContainerLow`.
const Color _surface = Color(0xFFFFFFFF);
const Color _surfaceContainerLow = Color(0xFFFBFBFA);

/// Kotlin's `ZadDarkSlate`.
const Color _darkSlate = Color(0xFF0F172A);

/// A destination in the bar. `more` is not a screen: it opens the sheet.
enum ZadNavDestination {
  /// الرئيسية.
  home,

  /// عقل زاد.
  assistant,

  /// المخزون.
  inventory,

  /// المزيد.
  more,

  /// العائلة — kids mode only.
  family,
}

class _NavItem {
  const new(this.destination, this.icon, this.label);

  final ZadNavDestination destination;
  final IconData icon;
  final String label;
}

// Kotlin draws these with Material's filled icons (`Icons.Default.*`), so
// these are the same glyphs, not Lucide look-alikes.
const List<_NavItem> _adultItems = <_NavItem>[
  _NavItem(ZadNavDestination.home, Icons.home, 'الرئيسية'),
  _NavItem(ZadNavDestination.assistant, Icons.psychology, 'عقل زاد'),
  _NavItem(ZadNavDestination.inventory, Icons.inventory_2, 'المخزون'),
  _NavItem(ZadNavDestination.more, Icons.grid_view, 'المزيد'),
];

const List<_NavItem> _kidsItems = <_NavItem>[
  _NavItem(ZadNavDestination.home, Icons.home, 'الرئيسية'),
  _NavItem(ZadNavDestination.family, Icons.family_restroom, 'العائلة'),
];

/// The bar.
class ZadBottomNavBar extends StatelessWidget {
  /// Creates the bar.
  const new({
    required this.current,
    required this.onNavigate,
    required this.onOpenCamera,
    required this.onOpenVoice,
    required this.onOpenMore,
    this.kidsMode = false,
    super.key,
  });

  /// What is showing. `null` means a screen the bar has no tab for, which
  /// Kotlin shows by lighting المزيد.
  final ZadNavDestination? current;

  /// A tab was tapped.
  final ValueChanged<ZadNavDestination> onNavigate;

  /// The camera button, and a long press on the mic.
  final VoidCallback onOpenCamera;

  /// The mic orb.
  final VoidCallback onOpenVoice;

  /// المزيد.
  final VoidCallback onOpenMore;

  /// Home and family only.
  final bool kidsMode;

  bool _selected(ZadNavDestination d) {
    if (d == ZadNavDestination.more) {
      return current != ZadNavDestination.home &&
          current != ZadNavDestination.assistant &&
          current != ZadNavDestination.inventory;
    }
    return current == d;
  }

  Widget _tab(_NavItem item) => _ZadNavTab(
    icon: item.icon,
    label: item.label,
    selected: _selected(item.destination),
    onTap: () => item.destination == ZadNavDestination.more
        ? onOpenMore()
        : onNavigate(item.destination),
  );

  @override
  Widget build(BuildContext context) {
    final items = kidsMode ? _kidsItems : _adultItems;
    // Kotlin: `.navigationBarsPadding()` outermost, then 16dp sides and 22dp
    // below, in a 74dp box — ten taller than the pill, for the raised mic.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        child: SizedBox(
          height: 74,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 64,
                child: _Pill(
                  children: kidsMode
                      ? <Widget>[for (final i in items) _tab(i)]
                      : <Widget>[
                          _tab(items[0]),
                          _tab(items[1]),
                          // The slot the action cluster floats over.
                          const SizedBox(width: 108),
                          _tab(items[2]),
                          _tab(items[3]),
                        ],
                ),
              ),
              if (!kidsMode)
                Positioned(
                  top: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _MicOrb(onTap: onOpenVoice, onLongPress: onOpenCamera),
                      const SizedBox(width: 8),
                      _CameraFab(onTap: onOpenCamera),
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

/// The glass capsule: radius 32, shadow at elevation 28, white at 85% and a
/// 0.5dp hairline. Kotlin's "blur" layer blurs only its own flat fill, which
/// is the same fill, so the pill is drawn as that fill.
class _Pill extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(32));

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: _radius,
      boxShadow: composeShadow(
        elevation: 28,
        ambient: _darkSlate.withValues(alpha: 0.10),
        spot: const Color(0xFF064E3B).withValues(alpha: 0.18),
      ),
    ),
    child: ClipRRect(
      borderRadius: _radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _surface.withValues(alpha: 0.85),
          borderRadius: _radius,
          border: Border.all(
            color: _outline.withValues(alpha: 0.35),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: children,
          ),
        ),
      ),
    ),
  );
}

/// One tab: springs to 1.12 when selected (Compose's MediumBouncy/Medium
/// spring — damping ratio 0.5, stiffness 1500), label ExtraBold, and a 16×3
/// dot under it.
class _ZadNavTab extends StatefulWidget {
  const new({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ZadNavTab> createState() => _ZadNavTabState();
}

class _ZadNavTabState extends State<_ZadNavTab>
    with SingleTickerProviderStateMixin {
  // damping = 2 · ratio · √(stiffness · mass).
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 1500,
    damping: 2 * 0.5 * 38.729833462,
  );

  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: widget.selected ? 1.12 : 1,
  );

  @override
  void didUpdateWidget(_ZadNavTab old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      _scale.animateWith(
        SpringSimulation(
          _spring,
          _scale.value,
          widget.selected ? 1.12 : 1,
          _scale.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.selected ? _primary : _textTertiary;
    return ScaleTransition(
      scale: _scale,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          onTap: widget.onTap,
          child: Semantics(
            selected: widget.selected,
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(widget.icon, size: 22, color: tint),
                  const SizedBox(height: 3),
                  Text(
                    widget.label,
                    maxLines: 1,
                    // Compose merges an ad-hoc Text into bodyLarge, so the
                    // 10sp label keeps bodyLarge's 22sp line and 0.2 tracking.
                    style: TextStyle(
                      fontSize: 10,
                      height: 22 / 10,
                      letterSpacing: 0.2,
                      fontWeight: widget.selected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: tint,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 16,
                    height: 3,
                    decoration: BoxDecoration(
                      color: widget.selected ? _primary : Colors.transparent,
                      borderRadius: const BorderRadius.all(Radius.circular(99)),
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
}

/// The mic orb: a 68dp glow ring breathing between 25% and 55% over 1400ms
/// (FastOutSlowIn, reversing), and the 52dp green orb inside it.
class _MicOrb extends StatefulWidget {
  const new({required this.onTap, required this.onLongPress});

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_MicOrb> createState() => _MicOrbState();
}

class _MicOrbState extends State<_MicOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _eased = CurvedAnimation(
    parent: _pulse,
    curve: Curves.fastOutSlowIn,
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox.square(
      dimension: 68,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Its own layer: the ring repaints every frame, the orb never does.
          RepaintBoundary(
            child: CustomPaint(
              size: const Size.square(68),
              painter: _GlowPainter(_eased, dpr),
            ),
          ),
          ZadPressable(
            scale: 0.96,
            onPressed: widget.onTap,
            onLongPress: () {
              // Compose's combinedClickable buzzes LONG_PRESS; Flutter's
              // long-press feedback is that same constant on Android.
              unawaited(Feedback.forLongPress(context));
              widget.onLongPress();
            },
            semanticLabel: 'زاد — المساعد الصوتي',
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Compose's linearGradient runs from the top-left corner to
                // the bottom-right one unless told otherwise.
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFF0B6B4E),
                    Color(0xFF064E3B),
                    Color(0xFF052E16),
                  ],
                ),
                boxShadow: composeShadow(
                  elevation: 20,
                  ambient: _primary.withValues(alpha: 0.40),
                  spot: _primary.withValues(alpha: 0.55),
                ),
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotlin's ring: `radialGradient(primary @ alpha → transparent, radius =
/// pulseRadius * 2f)` inside a circle. That radius is in *pixels* — 56 to 68
/// of them, not dp — so it is divided by the device's pixel ratio here to
/// draw the same size ring on the same phone.
class _GlowPainter extends CustomPainter {
  new(this.t, this.dpr) : super(repaint: t);

  final Animation<double> t;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final alpha = 0.25 + (0.55 - 0.25) * v;
    final radiusPx = (28 + (34 - 28) * v) * 2;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          _primary.withValues(alpha: alpha),
          _primary.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radiusPx / dpr));
    canvas.drawCircle(center, size.shortestSide / 2, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.dpr != dpr;
}

/// The 46dp camera button beside the orb: white to off-white, a 1dp primary
/// ring at 35%, shadow at elevation 16.
class _CameraFab extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZadPressable(
    scale: 0.96,
    onPressed: onTap,
    semanticLabel: 'تصوير الفواتير والمنتجات',
    child: Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_surface, _surfaceContainerLow],
        ),
        border: Border.all(color: _primary.withValues(alpha: 0.35)),
        boxShadow: composeShadow(
          elevation: 16,
          ambient: _darkSlate.withValues(alpha: 0.15),
          spot: _primary.withValues(alpha: 0.25),
        ),
      ),
      child: const Icon(Icons.camera_alt, color: _primary, size: 22),
    ),
  );
}
