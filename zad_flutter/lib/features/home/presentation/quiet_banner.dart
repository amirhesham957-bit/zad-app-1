/// «زاد مهدّي التنبيهات لحد …» with «رجّع التنبيهات»: the customer sees
/// that زاد is quieter and why it is, and takes the alerts back in one tap
/// (docs/agent/ZAD_LIVING_BRAIN.md slice 29).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/home/application/quiet_mode.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

/// The banner, or nothing.
class QuietModeBanner extends ConsumerStatefulWidget {
  /// Creates the banner.
  const new({super.key});

  @override
  ConsumerState<QuietModeBanner> createState() => _QuietModeBannerState();
}

class _QuietModeBannerState extends ConsumerState<QuietModeBanner> {
  bool _busy = false;

  Future<void> _end(String id) async {
    setState(() => _busy = true);
    final ok = await ref.read(endQuietModeProvider)(id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(quietModeProvider);
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('مقدرتش أرجّع التنبيهات. جرّب تاني.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiet = ref.watch(quietModeProvider).value;
    if (quiet == null) return const SizedBox.shrink();
    final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    final localEnd = tz.TZDateTime.from(quiet.endsAt.toUtc(), zone);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ZadSpacing.lg,
          ZadSpacing.sm,
          ZadSpacing.sm,
          ZadSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: ZadColors.surfaceVariant,
          borderRadius: BorderRadius.circular(ZadRadii.card),
        ),
        child: Row(
          children: <Widget>[
            Icon(ZadIcons.quiet, size: 20, color: ZadColors.inkMuted),
            const SizedBox(width: ZadSpacing.sm),
            Expanded(
              child: Text(
                quiet.banner(localEnd),
                style: ZadType.bodySmall.copyWith(color: ZadColors.ink),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: _busy ? null : () => unawaited(_end(quiet.id)),
              child: const Text('رجّع التنبيهات'),
            ),
          ],
        ),
      ),
    );
  }
}
