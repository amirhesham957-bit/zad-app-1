/// The camera sheet the shell's camera button opens (Kotlin's
/// `ZadCameraSheet` in `ui/components/ZadShell.kt`): scan the pantry, or scan
/// a receipt. Part of the scan feature; the shell opens it.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/components/zad_pressable.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_shell_colors.dart';

/// Kotlin's `onSurfaceVariant` / `textSecondary`.
Color get _textSecondary => ZadColors.inkMuted;

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
      backgroundColor: ZadColors.surface,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
