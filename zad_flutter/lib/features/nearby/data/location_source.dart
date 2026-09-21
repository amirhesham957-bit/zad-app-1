/// Where the phone is — asked for as rarely and as cheaply as possible.
///
/// Three rules, all about the battery:
///
/// * **No streams.** One fix when the customer taps, nothing between. The
///   plugin's foreground location service is removed from the manifest, so a
///   stream could not run even by mistake.
/// * **The OS's last fix first.** `lastKnown` reads a position the system
///   already has, from any app; it wakes no radio. It is used on open, and
///   only when it is recent.
/// * **Medium accuracy.** A shop list needs about 100 m, which Wi-Fi and cell
///   towers give; GPS is not switched on for it.
library;

import 'package:geolocator/geolocator.dart';
import 'package:zad/features/nearby/domain/nearby.dart';

/// Whether the app may know where the phone is.
enum LocationAccess {
  /// Yes.
  granted,

  /// Not yet — asking is allowed.
  denied,

  /// No, and Android will not ask again; only the settings screen can change
  /// it.
  deniedForever,

  /// Allowed, but location is switched off on the phone.
  serviceOff,
}

/// A position and when the phone took it.
typedef Fix = ({GeoPoint at, DateTime takenAt});

/// The phone's location.
abstract interface class LocationSource {
  /// Whether the app may know, without asking.
  Future<LocationAccess> access();

  /// Asks the customer. Only ever from a tap.
  Future<LocationAccess> request();

  /// The last position the phone already has, or null. Wakes nothing.
  Future<Fix?> lastKnown();

  /// One new fix, or null when none came in time.
  Future<Fix?> current();

  /// Opens the app's settings, for [LocationAccess.deniedForever].
  Future<void> openSettings();

  /// Opens the phone's location settings, for [LocationAccess.serviceOff].
  Future<void> openLocationSettings();
}

/// The real one, over geolocator.
class GeolocatorSource implements LocationSource {
  /// Creates the source.
  const new();

  /// How long a fix may take before giving up.
  static const Duration timeLimit = Duration(seconds: 10);

  @override
  Future<LocationAccess> access() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    return _read(await Geolocator.checkPermission());
  }

  @override
  Future<LocationAccess> request() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    return _read(await Geolocator.requestPermission());
  }

  @override
  Future<Fix?> lastKnown() async {
    final p = await Geolocator.getLastKnownPosition();
    return p == null ? null : _fix(p);
  }

  @override
  Future<Fix?> current() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeLimit,
        ),
      );
      return _fix(p);
    } on Exception {
      // A timeout or a refusal mid-way: no fix, and the screen says so.
      return null;
    }
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  static Fix _fix(Position p) =>
      (at: GeoPoint(p.latitude, p.longitude), takenAt: p.timestamp.toUtc());

  static LocationAccess _read(LocationPermission p) => switch (p) {
    LocationPermission.whileInUse ||
    LocationPermission.always => LocationAccess.granted,
    LocationPermission.deniedForever => LocationAccess.deniedForever,
    LocationPermission.denied ||
    LocationPermission.unableToDetermine => LocationAccess.denied,
  };
}
