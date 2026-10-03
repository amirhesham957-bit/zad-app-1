/// A child's phone keeping its school zones in step with the server
/// (docs/agent/ZAD_LIVING_BRAIN.md slice 2, migration 20261003110000).
///
/// The parent sets the zones; the child agreed to share coming and going
/// there. This phone only registers them as geofences and reports entering and
/// leaving ([PlaceEngine.handlePending]); it never sends where it is. While
/// any zone is watched, a notice stays up saying so and who follows.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/alerts/data/push_platform.dart';
import 'package:zad/shared/family/data/family_shares_remote.dart';
import 'package:zad/shared/family/domain/family_share.dart';
import 'package:zad/shared/places/application/place_engine.dart';

/// Fetches the zones, registers them, and puts the notice up or down.
class ChildZonesSync {
  /// Creates the sync. [engine] is null where there is no geofence plugin
  /// (tests); the zones are then fetched and the notice still follows them.
  const new({
    required FamilySharesRemote remote,
    required PlaceEngine? engine,
    required SharingNotice notice,
  }) : _remote = remote,
       _engine = engine,
       _notice = notice;

  final FamilySharesRemote _remote;
  final PlaceEngine? _engine;
  final SharingNotice _notice;

  /// One pass. Throws when the server cannot be reached (nothing changes on
  /// the phone) or when Android refuses the fences — then the notice comes
  /// down, since nothing is being shared, and the caller asks for "all the
  /// time".
  Future<MyZones> sync() async {
    final mine = await _remote.myZones();
    try {
      await _engine?.setZones(mine.zones);
    } on Object {
      await _notice.clear();
      rethrow;
    }
    if (mine.zones.isEmpty) {
      await _notice.clear();
    } else {
      await _notice.show(
        watchers: mine.watchers,
        places: <String>[for (final z in mine.zones) z.label],
      );
    }
    return mine;
  }
}

/// The sync, over the app's providers.
final childZonesSyncProvider = Provider<ChildZonesSync>(
  (ref) => ChildZonesSync(
    remote: ref.watch(familySharesRemoteProvider),
    engine: ref.watch(placeEngineProvider),
    notice: ref.watch(sharingNoticeProvider),
  ),
);
