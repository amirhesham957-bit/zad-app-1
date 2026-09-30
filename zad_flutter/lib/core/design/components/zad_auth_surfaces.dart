/// The auth screens' canvas and primary button, shared by login, the
/// introduction and the market picker.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/components/zad_pressable.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';

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
