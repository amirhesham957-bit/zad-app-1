/// Kotlin's `OrbAccessoryStore`: the chosen accessory, on this phone only — a
/// personal look the server has no use for.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/orb/domain/orb_accessory.dart';

/// The chosen accessory.
class OrbAccessoryController extends Notifier<OrbAccessory> {
  static const String _key = 'orb_accessory';

  @override
  OrbAccessory build() =>
      OrbAccessory.from(ref.read(localStoreProvider).device.get(_key));

  /// Chooses [accessory]. Refuses a locked one even if the UI offered it.
  bool select(OrbAccessory accessory, int familySize) {
    if (!accessory.isUnlocked(familySize)) return false;
    state = accessory;
    unawaited(
      ref.read(localStoreProvider).device.put(_key, accessory.prefValue),
    );
    return true;
  }
}

/// The chosen accessory, for every orb that draws one.
final orbAccessoryProvider =
    NotifierProvider<OrbAccessoryController, OrbAccessory>(
      OrbAccessoryController.new,
    );
