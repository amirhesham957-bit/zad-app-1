/// Kotlin's `TravelBanner` (`ui/components/TravelBanner.kt`) and
/// `TravelDetector`: when the phone's network country differs from the
/// chosen market, a suggestion — «شكلك في X — أحوّل لـ Y؟» — with an explicit
/// switch and a dismiss. Never a silent change of anyone's currency.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/market/application/switch_market.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';

const MethodChannel _channel = MethodChannel('zad/travel');
const String _dismissedKey = 'dismissed_travel_country';

/// The detected country, read once per session.
final detectedCountryProvider = FutureProvider<String?>((ref) async {
  try {
    return await _channel.invokeMethod<String>('detectCountry');
  } on Object {
    return null;
  }
});

/// The mobile network's country alone — null on Wi-Fi without a SIM. Unlike
/// [detectedCountryProvider] it never falls back to the phone's language: a
/// trip must not come from a phone set to English (US) in Cairo.
final networkCountryProvider = FutureProvider<String?>((ref) async {
  try {
    final code = await _channel.invokeMethod<String>('networkCountry');
    return code == null || code.isEmpty ? null : code;
  } on Object {
    return null;
  }
});

/// Tells zad-brain the country the phone is in (`zad_travel_report`,
/// migration 20261003140000): abroad starts a trip — the brain then suggests
/// places there — and home ends it. The account's market is not changed.
final travelReporterProvider = Provider<Future<void> Function(String country)>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    return (country) async {
      await client.rpc<Object?>(
        'zad_travel_report',
        params: <String, dynamic>{'p_country': country},
      );
    };
  },
);

/// Once a session: the network's country to the server. Nothing without a
/// mobile network (the last trip stands), and a failure is only logged.
final travelReportProvider = FutureProvider<void>((ref) async {
  final country = await ref.watch(networkCountryProvider.future);
  if (country == null) return;
  try {
    await ref.read(travelReporterProvider)(country);
  } on Object catch (e) {
    debugPrint('[travel] not reported: $e');
  }
});

/// The banner, or nothing.
class TravelBannerSlot extends ConsumerStatefulWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  ConsumerState<TravelBannerSlot> createState() => _TravelBannerSlotState();
}

class _TravelBannerSlotState extends ConsumerState<TravelBannerSlot> {
  late String? _dismissed = ref
      .read(localStoreProvider)
      .device
      .get(_dismissedKey);

  void _dismiss(String? country) {
    setState(() => _dismissed = country);
    if (country != null) {
      unawaited(
        ref.read(localStoreProvider).device.put(_dismissedKey, country),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(travelReportProvider);
    final detected = ref.watch(detectedCountryProvider).value;
    final currentCountry = ref
        .watch(settingsRepositoryProvider)
        .cached()
        ?.country;
    if (detected == null || detected == _dismissed) {
      return const SizedBox.shrink();
    }
    if (detected == currentCountry?.toUpperCase()) {
      return const SizedBox.shrink();
    }
    final suggested = marketFor(detected);
    if (suggested == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.flight_takeoff, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'شكلك في ${suggested.nameAr} — أحوّل لـ '
                '${suggested.currencySymbol}؟',
                style: ZadType.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                _dismiss(detected);
                await switchMarket(ref, marketFor(currentCountry), suggested);
              },
              child: Text(
                'تحويل',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox.square(
              dimension: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'تجاهل',
                onPressed: () => _dismiss(detected),
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
