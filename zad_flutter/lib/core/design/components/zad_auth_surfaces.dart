/// The auth screens' canvas and primary button, shared by login, the
/// introduction and the market picker.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zad/core/design/components/zad_pressable.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';

/// Kotlin's `ZadAuthBackground`: the canvas with a warm wash top-start and a
/// cool one bottom-end.
class ZadAuthBackground extends StatelessWidget {
  /// Creates the background.
  const new({required this.child, super.key});

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = context.zadExt;
    return LayoutBuilder(
      builder: (context, c) {
        final r = (c.maxWidth > c.maxHeight ? c.maxWidth : c.maxHeight) * 0.9;
        RadialGradient wash(Color color, double x, double y) => RadialGradient(
          center: Alignment(x * 2 - 1, y * 2 - 1),
          radius: r / (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight),
          colors: <Color>[color.withValues(alpha: 0.55), Colors.transparent],
        );
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: wash(ext.authWashWarm, 0.15, 0.10),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: wash(ext.authWashCool, 0.85, 0.90),
                  ),
                ),
              ),
              Positioned.fill(child: child),
            ],
          ),
        );
      },
    );
  }
}

/// Kotlin's `ZadPrimaryButton` (`ZadDesignPrimitives.kt`): a 56dp primary
/// pill, white label, elevation 10.
class ZadPrimaryButton extends StatelessWidget {
  /// Creates the button.
  const new({
    required this.text,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
    super.key,
  });

  /// The label.
  final String text;

  /// The action.
  final VoidCallback onPressed;

  /// Whether it can be pressed.
  final bool enabled;

  /// Shows a spinner instead of the label.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ZadPressable(
      onPressed: enabled && !loading ? onPressed : null,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled && !loading ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: primary.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            elevation: 10,
            shape: const StadiumBorder(),
          ),
          child: loading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  text,
                  style: ZadType.titleMedium.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

/// The brand as the intro, sign-in and sign-up all show it: the carrot beside
/// «زاد» in the app's language. Sign-in used to say «ZAD» in Latin under a
/// carrot while the intro said «زاد» beside one (emulator, 2026-11-15).
class ZadBrandRow extends StatelessWidget {
  /// Creates the brand row; [compact] is the smaller one above a form.
  const new({this.compact = false, this.foreground, super.key});

  /// Smaller logo and wordmark, for screens where the form needs the room.
  final bool compact;

  /// The wordmark's colour; the dark brand green by default, white on the
  /// sign-in hero.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final logo = compact ? 40.0 : 52.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SvgPicture.asset(
          'assets/brand/carrot_logo.svg',
          width: logo,
          height: logo,
          semanticsLabel: l.introLogoLabel,
        ),
        const SizedBox(width: 12),
        Text(
          l.appTitle,
          style: (compact ? ZadType.displayMedium : ZadType.displayLarge)
              .copyWith(color: foreground ?? context.zadExt.primaryDark),
        ),
      ],
    );
  }
}
