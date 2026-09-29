/// The phone's geofences and the permissions they need, behind an interface
/// so the controller can be tested without Android.
library;

import 'package:native_geofence/native_geofence.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zad/features/place_alerts/data/place_arrival_background.dart';
import 'package:zad/features/place_alerts/domain/place_fences.dart';

/// Registers and clears the watched shops.
abstract interface class FencePlatform {
  /// Replaces every fence of ours with [fences].
  Future<void> replaceAll(List<FenceSpec> fences);

  /// Removes them all.
  Future<void> clear();
}

/// Location permission, in the two steps Android requires.
abstract interface class FencePermissions {
  /// «While using the app». True when granted.
  Future<bool> foreground();

  /// «Allow all the time» — on Android 11+ a settings screen, not a dialog.
  /// True when granted.
  Future<bool> always();

  /// Whether «all the time» is granted now.
  Future<bool> hasAlways();
}

/// Android's GeofencingClient, through native_geofence.
class NativeFencePlatform implements FencePlatform {
  /// Creates the platform.
  const new();

  static Future<void>? _ready;

  Future<void> _init() =>
      _ready ??= NativeGeofenceManager.instance.initialize();

  @override
  Future<void> replaceAll(List<FenceSpec> fences) async {
    await _init();
    await NativeGeofenceManager.instance.removeAllGeofences();
    for (final f in fences) {
      await NativeGeofenceManager.instance.createGeofence(
        Geofence(
          id: f.id,
          location: Location(latitude: f.at.lat, longitude: f.at.lon),
          radiusMeters: kFenceRadiusMetres,
          // Dwell, not enter: driving or walking past a shop is not being
          // at it.
          triggers: const <GeofenceEvent>{GeofenceEvent.dwell},
          iosSettings: const IosGeofenceSettings(),
          androidSettings: const AndroidGeofenceSettings(
            initialTriggers: <GeofenceEvent>{},
            loiteringDelay: Duration(minutes: 2),
            notificationResponsiveness: Duration(minutes: 1),
          ),
        ),
        placeArrivalCallback,
      );
    }
  }

  @override
  Future<void> clear() async {
    await _init();
    await NativeGeofenceManager.instance.removeAllGeofences();
  }
}

/// permission_handler.
class PluginFencePermissions implements FencePermissions {
  /// Creates the permissions.
  const new();

  @override
  Future<bool> foreground() async =>
      (await Permission.locationWhenInUse.request()).isGranted;

  @override
  Future<bool> always() async =>
      (await Permission.locationAlways.request()).isGranted;

  @override
  Future<bool> hasAlways() => Permission.locationAlways.isGranted;
}
