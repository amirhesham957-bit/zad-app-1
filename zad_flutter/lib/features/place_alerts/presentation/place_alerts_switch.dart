/// «فكّرني لما أوصل سوبرماركت أو صيدلية» — the switch, and the explanation
/// Android wants before asking for location «all the time».
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/place_alerts/application/place_alerts_controller.dart';

/// The switch, with its state underneath.
class PlaceAlertsSwitch extends ConsumerWidget {
  /// Creates the switch.
  const new({super.key});

  Future<void> _turnOn(BuildContext context, WidgetRef ref) async {
    // The disclosure comes before the system's own prompt, as Android asks:
    // what is collected, when, and what for.
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('زاد هيعرف إنك وصلت المحل'),
        content: const Text(
          'عشان أفكّرك بنواقص البيت أول ما توقف عند سوبرماركت أو صيدلية — حتى '
          'والتطبيق مقفول — محتاج إذن الموقع «طول الوقت».\n\n'
          'الموبايل هو اللي بيعرف إنك عند محل؛ اللي بيوصلنا اسم المحل ونوعه '
          'بس، مش مكانك. تقدر تقفل الميزة دي في أي وقت من هنا.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('مش دلوقتي'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('كمّل'),
          ),
        ],
      ),
    );
    if (go ?? false) {
      await ref.read(placeAlertsControllerProvider.notifier).enable();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(placeAlertsControllerProvider);
    final controller = ref.read(placeAlertsControllerProvider.notifier);
    final status =
        view.problem ??
        (view.enabled
            ? (view.watching > 0
                  ? 'شغّال — بنراقب ${view.watching} محل حواليك.'
                  : 'شغّال — بندوّر على المحلات اللي حواليك.')
            : 'مقفول');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'فكّرني لما أوصل سوبرماركت أو صيدلية',
            style: ZadType.titleSmall,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: ZadSpacing.xs),
            child: Text(
              status,
              style: ZadType.bodySmall.copyWith(
                color: view.problem == null
                    ? ZadColors.inkMuted
                    : ZadColors.terracottaRust,
              ),
            ),
          ),
          value: view.enabled,
          onChanged: view.busy
              ? null
              : (on) => unawaited(
                  on ? _turnOn(context, ref) : controller.disable(),
                ),
        ),
      ],
    );
  }
}
