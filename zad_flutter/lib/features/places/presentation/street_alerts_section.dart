/// The settings row for street alerts, and the sheet that says why they need
/// "Allow all the time" before Android asks.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/places/application/street_alerts_controller.dart';

/// Street alerts: on, off, and what is missing when it is on but cannot work.
class StreetAlertsSection extends ConsumerStatefulWidget {
  /// Creates the section.
  const new({super.key});

  @override
  ConsumerState<StreetAlertsSection> createState() =>
      _StreetAlertsSectionState();
}

class _StreetAlertsSectionState extends ConsumerState<StreetAlertsSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the system page where "all the time" is chosen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(streetAlertsControllerProvider.notifier).reload());
    }
  }

  Future<void> _toggle(bool on) async {
    final controller = ref.read(streetAlertsControllerProvider.notifier);
    if (!on) {
      await controller.turnOff();
      return;
    }
    final agreed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ZadRadii.sheet),
        ),
      ),
      builder: (_) => const _WhySheet(),
    );
    if (agreed ?? false) await controller.turnOn();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(streetAlertsControllerProvider);
    if (view.status == StreetAlertsStatus.unavailable) {
      return const SizedBox.shrink();
    }
    final on =
        view.status == StreetAlertsStatus.on ||
        view.status == StreetAlertsStatus.needsAlways;
    final (status, fix) = switch (view.status) {
      StreetAlertsStatus.on => (
        view.homeLearned
            ? 'شغّالة — زاد عارف بيتك وهيفكّرك عند المحلات'
            : 'شغّالة — زاد بيتعلّم مكان بيتك في ليلتين',
        null,
      ),
      StreetAlertsStatus.needsAlways => (
        'محتاجة «السماح طول الوقت» عشان تشتغل والتطبيق مقفول',
        'افتح الإعدادات',
      ),
      StreetAlertsStatus.needsLocation => (
        'الموقع مقفول أو مرفوض على الموبايل',
        'افتح الإعدادات',
      ),
      StreetAlertsStatus.noFix => (
        'ماقدرناش نعرف مكانك دلوقتي — جرّب تاني برّه',
        null,
      ),
      StreetAlertsStatus.failed => (
        'أندرويد رفض تسجيل المحلات — جرّب تاني',
        null,
      ),
      _ => ('زاد يفكّرك بنواقصك لما تعدّي جنب ماركت أو صيدلية', null),
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
            'وانت في الشارع',
            style: ZadType.labelLarge.copyWith(color: ZadColors.inkMuted),
          ),
        ),
        ZadCard(
          padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
          child: Column(
            children: <Widget>[
              SwitchListTile(
                secondary: Icon(
                  ZadIcons.location,
                  color: on ? ZadColors.green600 : ZadColors.inkMuted,
                ),
                title: const Text('تنبيهات قرب المحلات'),
                subtitle: Text(
                  status,
                  style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
                ),
                value: on,
                onChanged:
                    view.busy || view.status == StreetAlertsStatus.unknown
                    ? null
                    : (v) => unawaited(_toggle(v)),
              ),
              if (fix != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ZadSpacing.lg,
                    0,
                    ZadSpacing.lg,
                    ZadSpacing.md,
                  ),
                  child: FilledButton(
                    onPressed: ref
                        .read(streetAlertsControllerProvider.notifier)
                        .openSettings,
                    child: Text(fix),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Why, before Android asks — and what never leaves the phone.
class _WhySheet extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: ZadColors.green600),
          const SizedBox(width: ZadSpacing.md),
          Expanded(child: Text(text, style: ZadType.bodyMedium)),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.xl,
          ZadSpacing.xl,
          ZadSpacing.xl,
          ZadSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('زاد معاك في الشارع', style: ZadType.titleLarge),
            const SizedBox(height: ZadSpacing.lg),
            point(
              ZadIcons.shopping,
              'تعدّي جنب ماركت أو صيدلية؟ زاد يقولك الناقص في البيت '
              'والأدوية اللي قربت تخلص.',
            ),
            point(
              ZadIcons.home,
              'ترجع البيت بعد خروجة؟ يقولك صرفت كام وفين. مكان بيتك بيفضل '
              'على موبايلك بس — السيرفر بيعرف وقت خروجك ورجوعك بس.',
            ),
            point(
              ZadIcons.location,
              'أندرويد هو اللي بيراقب المحلات، مش GPS شغال طول الوقت — '
              'فالبطارية مش هتتأثر. وتقدر تقفلها من هنا في أي وقت.',
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              'في الخطوة الجاية اختار «السماح طول الوقت».',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('كمّل'),
            ),
            const SizedBox(height: ZadSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('مش دلوقتي'),
            ),
          ],
        ),
      ),
    );
  }
}
