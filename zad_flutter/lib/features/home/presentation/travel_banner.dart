/// Kotlin's `TravelBanner` (`ui/components/TravelBanner.kt`) and
/// `TravelDetector`: when the phone's network country differs from the
/// chosen market, a suggestion — «شكلك في X — أحوّل لـ Y؟» — with an explicit
/// switch and a dismiss. Never a silent change of anyone's currency.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/market/application/switch_market.dart';
import 'package:zad/features/market/domain/market.dart';

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
