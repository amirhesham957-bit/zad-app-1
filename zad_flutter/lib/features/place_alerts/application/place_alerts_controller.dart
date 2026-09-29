/// «فكّرني لما أوصل سوبرماركت أو صيدلية» — on, off, and keeping the watched
/// shops around where the customer is.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/nearby/application/nearby_controller.dart';
import 'package:zad/features/nearby/domain/nearby.dart';
import 'package:zad/features/place_alerts/data/fence_platform.dart';
import 'package:zad/features/place_alerts/domain/place_fences.dart';

/// Where the feature stands.
@immutable
class PlaceAlertsView {
  /// Creates a view.
  const new({
    this.enabled = false,
    this.watching = 0,
    this.busy = false,
    this.problem,
  });

  /// The customer turned it on.
  final bool enabled;

  /// How many shops are watched.
  final int watching;

  /// Turning on, or looking for shops.
  final bool busy;

  /// Why the last attempt did not work, in words the customer can act on.
  final String? problem;
}

/// The controller.
class PlaceAlertsController extends Notifier<PlaceAlertsView> {
  static const String _enabledKey = 'place_alerts_enabled';
  static const String _centerKey = 'place_alerts_center';
  static const String _countKey = 'place_alerts_count';

  @override
  PlaceAlertsView build() {
    final device = ref.read(localStoreProvider).device;
    return PlaceAlertsView(
      enabled: device.get(_enabledKey) == 'true',
      watching: int.tryParse(device.get(_countKey) ?? '') ?? 0,
    );
  }

  /// Asks for location «all the time», then watches the nearest shops.
  Future<void> enable() async {
    state = PlaceAlertsView(enabled: state.enabled, busy: true);
    final permissions = ref.read(fencePermissionsProvider);
    if (!await permissions.foreground()) {
      state = const PlaceAlertsView(problem: 'محتاجين إذن الموقع الأول.');
      return;
    }
    if (!await permissions.always()) {
      state = const PlaceAlertsView(
        problem:
            'من الإعدادات اختار «السماح طول الوقت» للموقع، عشان التنبيه يشتغل '
            'والتطبيق مقفول.',
      );
      return;
    }
    await ref.read(localStoreProvider).device.put(_enabledKey, 'true');
    state = const PlaceAlertsView(enabled: true, busy: true);
    await refresh(force: true);
  }

  /// Stops watching.
  Future<void> disable() async {
    final device = ref.read(localStoreProvider).device;
    await device.put(_enabledKey, 'false');
    await device.delete(_countKey);
    await device.delete(_centerKey);
    try {
      await ref.read(fencePlatformProvider).clear();
    } on Object catch (e) {
      debugPrint('[place_alerts] clear failed: $e');
    }
    state = const PlaceAlertsView();
  }

  /// Draws the fences again around where the customer is — only when they
  /// have moved far enough, unless [force].
  Future<void> refresh({bool force = false}) async {
    if (!state.enabled) return;
    final device = ref.read(localStoreProvider).device;
    try {
      if (!await ref.read(fencePermissionsProvider).hasAlways()) {
        state = const PlaceAlertsView(
          enabled: true,
          problem: 'إذن الموقع «طول الوقت» اتشال — فعّله تاني من الإعدادات.',
        );
        return;
      }
      final fix =
          await ref.read(locationSourceProvider).current() ??
          await ref.read(locationSourceProvider).lastKnown();
      if (fix == null) {
        state = PlaceAlertsView(
          enabled: true,
          watching: state.watching,
          problem: 'مش عارفين مكانك دلوقتي — اتأكد إن الموقع شغال.',
        );
        return;
      }
      final here = fix.at;
      if (!force && !fencesStale(_center(device.get(_centerKey)), here)) {
        state = PlaceAlertsView(enabled: true, watching: state.watching);
        return;
      }
      final snapshot = await ref.read(nearbyRepositoryProvider).around(here);
      final fences = pickFences(<NearbyStore>[
        ...snapshot.supermarkets,
        ...snapshot.pharmacies,
      ], here);
      await ref.read(fencePlatformProvider).replaceAll(fences);
      await device.put(_centerKey, jsonEncode(<double>[here.lat, here.lon]));
      await device.put(_countKey, '${fences.length}');
      if (ref.mounted) {
        state = PlaceAlertsView(enabled: true, watching: fences.length);
      }
    } on Object catch (e) {
      debugPrint('[place_alerts] refresh failed: $e');
      if (ref.mounted) {
        state = PlaceAlertsView(
          enabled: true,
          watching: state.watching,
          problem: 'مقدرناش ندوّر على المحلات اللي حواليك — جرّب تاني.',
        );
      }
    }
  }

  static GeoPoint? _center(String? raw) {
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return GeoPoint((list[0] as num).toDouble(), (list[1] as num).toDouble());
    } on Object {
      return null;
    }
  }
}

/// The phone's geofences.
final fencePlatformProvider = Provider<FencePlatform>(
  (ref) => const NativeFencePlatform(),
);

/// Location permission.
final fencePermissionsProvider = Provider<FencePermissions>(
  (ref) => const PluginFencePermissions(),
);

/// «فكّرني لما أوصل».
final placeAlertsControllerProvider =
    NotifierProvider<PlaceAlertsController, PlaceAlertsView>(
      PlaceAlertsController.new,
    );
