/// The settings row for alerts: whether زاد may alert this phone, and the
/// one button that changes it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/alerts/application/alerts_controller.dart';
import 'package:zad/features/alerts/data/notification_permission.dart';

/// Whether زاد may alert this phone.
class AlertsSettingsSection extends ConsumerStatefulWidget {
  /// Creates the section.
  const new({super.key});

  @override
  ConsumerState<AlertsSettingsSection> createState() =>
      _AlertsSettingsSectionState();
}

class _AlertsSettingsSectionState extends ConsumerState<AlertsSettingsSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref.read(alertsControllerProvider.notifier).refreshPermission(),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the system settings, where the answer may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(alertsControllerProvider.notifier).refreshPermission(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(
      alertsControllerProvider.select((v) => v.permission),
    );
    final (icon, accent, status) = switch (permission) {
      AlertPermission.granted => (
        ZadIcons.synced,
        ZadColors.green600,
        'شغّالة — زاد يقدر ينبهك حتى والتطبيق مقفول',
      ),
      AlertPermission.denied || AlertPermission.blocked => (
        ZadIcons.noNotifications,
        ZadColors.mustardOchre,
        'مقفولة — تنبيهات زاد مش هتوصلك',
      ),
      AlertPermission.unknown => (
        ZadIcons.notifications,
        ZadColors.inkMuted,
        'بنتأكد…',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            right: ZadSpacing.xs,
            bottom: ZadSpacing.sm,
          ),
          child: Text(
            'التنبيهات',
            style: ZadType.labelLarge.copyWith(color: ZadColors.inkMuted),
          ),
        ),
        ZadCard(
          padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
          child: Column(
            children: <Widget>[
              ListTile(
                leading: Icon(icon, color: accent),
                title: const Text('تنبيهات زاد على الموبايل'),
                subtitle: Text(
                  status,
                  style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
                ),
              ),
              if (permission == AlertPermission.denied ||
                  permission == AlertPermission.blocked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ZadSpacing.lg,
                    0,
                    ZadSpacing.lg,
                    ZadSpacing.md,
                  ),
                  child: FilledButton(
                    onPressed: ref
                        .read(alertsControllerProvider.notifier)
                        .enable,
                    child: Text(
                      permission == AlertPermission.blocked
                          ? 'افتح إعدادات النظام'
                          : 'شغّل التنبيهات',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
