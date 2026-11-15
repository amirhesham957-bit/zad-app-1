/// The look sign-in and sign-up share: a dark emerald hero holding Zado and
/// the brand, and a white card laid over its lower edge.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zad/core/design/components/zad_auth_surfaces.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// How far the card climbs over the hero.
const double kAuthCardOverlap = 36;

/// Where Zado looks while [length] characters sit in a field: down at the
/// text, and along it as it grows. [rtl] fields (a name in Arabic) run the
/// other way.
Offset authGazeFor(int length, {bool rtl = false}) {
  final along = (length / 22).clamp(0.0, 1.0) * 1.4 - 0.6;
  return Offset(rtl ? -along : along, 0.75);
}

/// The hero, the card and what lies under it, scrolling as one when the
/// keyboard or a small screen needs it to.
class AuthHeroShell extends StatelessWidget {
  /// Creates the shell; [small] is the shorter hero sign-up uses.
  const new({
    required this.zado,
    required this.card,
    required this.footer,
    this.small = false,
    super.key,
  });

  /// Zado and the brand, centred in the hero.
  final Widget zado;

  /// The card's content.
  final List<Widget> card;

  /// Under the card: the switch to the other screen.
  final Widget footer;

  /// A shorter hero (150..230 instead of 200..300).
  final bool small;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // From the screen, not the viewport: the keyboard must not shrink it.
    final tall = media.size.height;
    final heroHeight = small
        ? (tall * 0.24).clamp(150.0, 230.0)
        : (tall * 0.32).clamp(200.0, 300.0);
    final top = media.viewPadding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: media.viewPadding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Stack(
              children: <Widget>[
                Container(
                  height: heroHeight + top,
                  padding: EdgeInsets.only(top: top, bottom: kAuthCardOverlap),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        ZadColors.forestEmerald,
                        ZadColors.emeraldDeep,
                      ],
                    ),
                  ),
                  child: Center(child: zado),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: heroHeight + top - kAuthCardOverlap,
                    left: ZadSpacing.lg,
                    right: ZadSpacing.lg,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: ZadColors.shadowAmbient,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                        BoxShadow(
                          color: Color(0x2E0F172A),
                          blurRadius: 32,
                          spreadRadius: -14,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ZadSpacing.lg,
                        ZadSpacing.lg,
                        ZadSpacing.lg,
                        ZadSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: card,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: ZadSpacing.xs),
              child: footer,
            ),
          ],
        ),
      ),
    );
  }
}

/// Zado over the white brand, with his looks as parameters: where he looks,
/// whether he covers his eyes, a hop on every [hop] change, and an optional
/// bubble beside him.
class AuthZado extends StatefulWidget {
  /// Creates Zado for the hero; [small] is the sign-up size.
  const new({
    this.gaze = Offset.zero,
    this.cover = false,
    this.hop = 0,
    this.bubble,
    this.small = false,
    super.key,
  });

  /// Where the eyes look.
  final Offset gaze;

  /// Hands over the eyes.
  final bool cover;

  /// A change (not the value) makes him hop.
  final int hop;

  /// What he says, or null.
  final String? bubble;

  /// The smaller Zado of the sign-up hero.
  final bool small;

  @override
  State<AuthZado> createState() => _AuthZadoState();
}

class _AuthZadoState extends State<AuthZado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  @override
  void didUpdateWidget(AuthZado old) {
    super.didUpdateWidget(old);
    if (old.hop != widget.hop &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _hop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.small ? 84.0 : 124.0;
    // The orb's box is bigger than its body: let it overlap the brand.
    final room = widget.small ? 70.0 : 104.0;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: room,
              child: OverflowBox(
                maxHeight: box,
                child: AnimatedBuilder(
                  animation: _hop,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      0,
                      -math.sin(_hop.value * math.pi) * (box * 0.16),
                    ),
                    child: child,
                  ),
                  child: CompanionOrb(
                    size: box,
                    animated:
                        !(MediaQuery.maybeDisableAnimationsOf(context) ??
                            false),
                    gaze: widget.gaze,
                    coverEyes: widget.cover,
                  ),
                ),
              ),
            ),
            const ZadBrandRow(compact: true, foreground: Colors.white),
          ],
        ),
        PositionedDirectional(
          top: 0,
          start: 0,
          child: _ZadoBubble(text: widget.bubble),
        ),
      ],
    );
  }
}

class _ZadoBubble extends StatelessWidget {
  const new({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final shown = text != null;
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: ZadDuration.quick,
        opacity: shown ? 1 : 0,
        child: AnimatedScale(
          duration: ZadDuration.enter,
          curve: ZadCurves.springy,
          scale: shown ? 1 : 0.9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ZadRadii.card),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x59064E3B),
                  blurRadius: 24,
                  spreadRadius: -10,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.md,
                vertical: ZadSpacing.sm,
              ),
              child: Text(
                text ?? '',
                style: ZadType.bodyMedium.copyWith(
                  color: ZadColors.green800,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
