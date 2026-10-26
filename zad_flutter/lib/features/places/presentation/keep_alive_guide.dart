/// «عشان زاد يفضل صاحي» — the battery and auto-start guide.
///
/// Xiaomi, Oppo, Realme, Vivo, Huawei and Samsung kill apps in the background
/// to save battery, and with them the street alerts (geofences), the reminders
/// and the bank reading (ZAD_SUPER_AGENT.md weak point 5). No permission
/// fixes it: the customer has to switch the app to "no restrictions" and, on
/// the Chinese brands, turn on auto-start. This card says so, per brand, and
/// opens the app's system page.
///
/// While battery optimisation is on, the button asks for the exemption with
/// the system dialog (REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, owner's decision
/// 2026-10-26, ZAD_PLAN 2.1) and falls back to the app's page when that is
/// refused or unavailable. Once off, it opens the app's page for auto-start,
/// which no permission covers.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';

/// The steps, per brand. UI text.
const List<(String, String)> kKeepAliveSteps = <(String, String)>[
  (
    'شاومي / ريدمي / بوكو',
    'الإعدادات ← التطبيقات ← زاد ← «التشغيل التلقائي» شغّال، و«توفير '
        'البطارية» ← «بدون قيود».',
  ),
  (
    'أوبو / ريلمي / ون بلس',
    'الإعدادات ← البطارية ← زاد ← «السماح بالنشاط في الخلفية»، و«التشغيل '
        'التلقائي» شغّال.',
  ),
  (
    'فيفو',
    'الإعدادات ← البطارية ← «استهلاك عالي في الخلفية» ← زاد، و«التشغيل '
        'التلقائي» شغّال.',
  ),
  (
    'هواوي / أونر',
    'الإعدادات ← البطارية ← تشغيل التطبيقات ← زاد ← «إدارة يدوي» وشغّل '
        'الثلاث اختيارات.',
  ),
  (
    'سامسونج',
    'الإعدادات ← التطبيقات ← زاد ← البطارية ← «غير مقيّد»، وشيله من «التطبيقات '
        'النايمة».',
  ),
  ('باقي الأجهزة', 'معلومات التطبيق ← البطارية ← «بدون قيود».'),
];

/// Whether battery optimisation is already off for Zad; null when it cannot
/// be told (a test host, a platform without it).
Future<bool?> batteryUnrestricted() async {
  try {
    return await Permission.ignoreBatteryOptimizations.isGranted;
  } on Object {
    return null;
  }
}

/// The card.
class KeepAliveGuide extends StatefulWidget {
  /// Creates the card.
  const new({super.key});

  @override
  State<KeepAliveGuide> createState() => _KeepAliveGuideState();
}

class _KeepAliveGuideState extends State<KeepAliveGuide>
    with WidgetsBindingObserver {
  bool? _unrestricted;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the system page: look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    final v = await batteryUnrestricted();
    if (mounted) setState(() => _unrestricted = v);
  }

  Future<void> _openSettings() async {
    try {
      await openAppSettings();
    } on Object {
      // No plugin (a test host).
    }
  }

  /// The system's «السماح لزاد بالعمل في الخلفية؟» dialog; the app's page if
  /// the customer says no or the phone has no such dialog.
  Future<void> _askExemption() async {
    var granted = false;
    try {
      granted = await Permission.ignoreBatteryOptimizations.request().isGranted;
    } on Object {
      // No plugin (a test host).
    }
    if (!granted) await _openSettings();
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _unrestricted ?? false;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ok ? ZadColors.mint100 : ZadColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZadColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  ok ? Icons.battery_full : Icons.battery_saver,
                  color: ok ? ZadColors.green700 : ZadColors.mustardOchre,
                ),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: Text(
                    ok
                        ? 'البطارية مش هتقفل زاد'
                        : 'عشان زاد يفضل صاحي في الخلفية',
                    style: ZadType.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              ok
                  ? 'لو موبايلك شاومي أو أوبو أو ريلمي أو فيفو، اتأكد كمان إن '
                        '«التشغيل التلقائي» شغّال.'
                  : 'موبايلات كتير بتقفل التطبيقات لتوفير البطارية، فتنبيهات '
                        'الشارع والتذكيرات وقراءة البنك تقف. خطوة واحدة من '
                        'الإعدادات بتحل ده.',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
            if (_open) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              for (final (brand, steps) in kKeepAliveSteps)
                Padding(
                  padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        brand,
                        style: ZadType.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        steps,
                        style: ZadType.bodySmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: ZadSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: ZadSpacing.sm,
              children: <Widget>[
                TextButton(
                  onPressed: () => setState(() => _open = !_open),
                  child: Text(_open ? 'اخفي الخطوات' : 'الخطوات لموبايلي'),
                ),
                FilledButton(
                  onPressed: () =>
                      unawaited(ok ? _openSettings() : _askExemption()),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: Text(
                    ok ? 'افتح إعدادات زاد' : context.l10n.keepAliveAllow,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
