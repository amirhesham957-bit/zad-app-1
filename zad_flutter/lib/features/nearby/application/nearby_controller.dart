/// The "near you" tab's state.
///
/// On open it never asks for permission and never wakes a radio: it shows the
/// kept list, checks whether location is already allowed, and uses the
/// position the phone already has if it is recent. A new fix — one, at medium
/// accuracy — is only ever taken when the customer taps.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/nearby/data/location_source.dart';
import 'package:zad/features/nearby/data/nearby_repository.dart';
import 'package:zad/features/nearby/domain/nearby.dart';

/// What the tab draws.
class NearbyView {
  /// Creates a view.
  const new({
    this.snapshot,
    this.here,
    this.access,
    this.radius = 1000,
    this.isLocating = false,
    this.noFix = false,
    this.error,
    this.onList = const <String>[],
    this.runningOut = const <String>[],
  });

  /// The last shops found.
  final NearbySnapshot? snapshot;

  /// Where the customer is, when known this session. Never stored.
  final GeoPoint? here;

  /// Whether location is allowed, once checked.
  final LocationAccess? access;

  /// The chosen radius, metres.
  final int radius;

  /// Whether a fix or a lookup is in flight.
  final bool isLocating;

  /// The last tap got no fix in time.
  final bool noFix;

  /// Why the last lookup failed.
  final Object? error;

  /// Open shopping-list lines — worth a reminder beside a supermarket.
  final List<String> onList;

  /// Medicines running out — worth one beside a pharmacy.
  final List<String> runningOut;

  /// The point distances are measured from: the exact one when known, the
  /// snapshot's coarse one otherwise.
  GeoPoint? get from => here ?? snapshot?.center;

  /// Shops of [kind] inside [radius], nearest first.
  List<StoreDistance> storesOf(StoreKind kind) {
    final s = snapshot;
    final origin = from;
    if (s == null || origin == null) return const <StoreDistance>[];
    return storesWithin(
      kind == StoreKind.supermarket ? s.supermarkets : s.pharmacies,
      from: origin,
      radius: radius,
    );
  }

  /// A copy with the given fields replaced.
  NearbyView copyWith({
    NearbySnapshot? snapshot,
    GeoPoint? here,
    LocationAccess? access,
    int? radius,
    bool? isLocating,
    bool? noFix,
    Object? error,
    bool clearError = false,
  }) => NearbyView(
    snapshot: snapshot ?? this.snapshot,
    here: here ?? this.here,
    access: access ?? this.access,
    radius: radius ?? this.radius,
    isLocating: isLocating ?? this.isLocating,
    noFix: noFix ?? this.noFix,
    error: clearError ? null : (error ?? this.error),
    onList: onList,
    runningOut: runningOut,
  );
}

/// Holds the tab.
class NearbyController extends Notifier<NearbyView> {
  /// How old the phone's last position may be and still count as "here".
  static const Duration lastKnownFor = Duration(minutes: 30);

  @override
  NearbyView build() {
    unawaited(Future<void>.microtask(() => ref.mounted ? _onOpen() : null));
    return NearbyView(
      snapshot: ref.read(nearbyRepositoryProvider).cached(),
      onList: <String>[
        for (final s in ref.read(shoppingListRepositoryProvider).outstanding())
          s.itemName,
      ],
      runningOut: <String>[
        for (final m in ref.read(pharmacyRepositoryProvider).cached())
          if (m.isRunningOut || m.isOutOfStock) m.name,
      ],
    );
  }

  /// No prompt, no new fix: permission as it stands, and the phone's last
  /// position if it is recent.
  Future<void> _onOpen() async {
    final source = ref.read(locationSourceProvider);
    final access = await source.access();
    if (!ref.mounted) return;
    state = state.copyWith(access: access);
    if (access != LocationAccess.granted) return;

    final last = await source.lastKnown();
    if (!ref.mounted || last == null) return;
    final age = ref.read(nowProvider)().toUtc().difference(last.takenAt);
    if (age > lastKnownFor) return;
    await _lookUp(last.at);
  }

  /// The customer's tap: ask if need be, take one fix, look around it.
  Future<void> locate() async {
    if (state.isLocating || !ref.mounted) return;
    final source = ref.read(locationSourceProvider);

    var access = await source.access();
    if (access == LocationAccess.denied) access = await source.request();
    if (!ref.mounted) return;
    state = state.copyWith(access: access, noFix: false, clearError: true);
    if (access != LocationAccess.granted) return;

    state = state.copyWith(isLocating: true);
    final fix = await source.current() ?? await source.lastKnown();
    if (!ref.mounted) return;
    if (fix == null) {
      state = state.copyWith(isLocating: false, noFix: true);
      return;
    }
    await _lookUp(fix.at);
  }

  /// Filters to [metres]. What is on the phone already; no network.
  void setRadius(int metres) {
    if (ref.mounted) state = state.copyWith(radius: metres);
  }

  /// Opens the settings screen that can change [LocationAccess].
  Future<void> openSettings() async {
    final source = ref.read(locationSourceProvider);
    if (state.access == LocationAccess.serviceOff) {
      await source.openLocationSettings();
    } else {
      await source.openSettings();
    }
  }

  Future<void> _lookUp(GeoPoint at) async {
    state = state.copyWith(here: at, isLocating: true, clearError: true);
    try {
      final snapshot = await ref.read(nearbyRepositoryProvider).around(at);
      if (!ref.mounted) return;
      state = state.copyWith(snapshot: snapshot, isLocating: false);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isLocating: false, error: error);
    }
  }
}

/// The phone's location.
final locationSourceProvider = Provider<LocationSource>(
  (ref) => const GeolocatorSource(),
);

/// Shops near the customer.
final nearbyControllerProvider =
    NotifierProvider<NearbyController, NearbyView>(NearbyController.new);
