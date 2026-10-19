/// The pet's care on the server (ZAD_PLAN ٥.٥, migration 20261020090000).
///
/// One call does both directions: the phone sends what it has and gets the
/// merged row back — the latest meal, drink and pat of either phone, and the
/// streak of whichever cared last. Null sent is a read only, for a phone that
/// meets the pet for the first time and must not push its newborn over a real
/// streak from another phone.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/companion/domain/pet_care.dart';

/// `zad_companion_care_sync(p_care)`.
abstract interface class PetCareRemote {
  /// Sends [care] (or reads, when null) and returns the server's row; null
  /// when the server has none yet.
  Future<PetCare?> sync(PetCare? care);
}

/// The real implementation.
class SupabasePetCareRemote implements PetCareRemote {
  /// Creates one over the app's client.
  const new(this._ref);

  final Ref _ref;

  @override
  Future<PetCare?> sync(PetCare? care) async {
    final r = await _ref
        .read(supabaseClientProvider)
        .rpc<dynamic>(
          'zad_companion_care_sync',
          params: <String, dynamic>{'p_care': care?.toJson()},
        );
    return PetCare.fromJson(r);
  }
}

/// The server side of the pet's care.
final petCareRemoteProvider = Provider<PetCareRemote>(
  SupabasePetCareRemote.new,
);
