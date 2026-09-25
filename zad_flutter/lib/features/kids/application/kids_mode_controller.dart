/// Kids mode, as Kotlin's `MainScreen` + `KidsModePin` run it.
///
/// On when the signed-in member is a child (until a parent's PIN unlocks the
/// phone for this run), or when a parent switched it on by hand to hand the
/// phone over. The manual switch survives a restart so a closed app does not
/// reopen in full mode without the PIN. The PIN is local friction only — a
/// SHA-256 on this phone, never synced, not a server security boundary.
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/domain/family.dart';

/// What the phone knows about kids mode.
typedef KidsModeState = ({bool manual, bool pinUnlocked});

/// Holds the switch and the PIN.
class KidsModeController extends Notifier<KidsModeState> {
  static const String _manualKey = 'kids_manual_active';
  static const String _hashKey = 'kids_pin_hash';
  static const Duration _backoff = Duration(milliseconds: 1500);

  // Controller-scoped, not per dialog, so closing and reopening the PIN
  // dialog cannot reset the guessing delay.
  DateTime _lastFailure = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  KidsModeState build() => (
    manual: ref.read(localStoreProvider).device.get(_manualKey) == 'true',
    pinUnlocked: false,
  );

  /// Turns the hand-over mode on or off.
  void setManual({required bool active}) {
    state = (manual: active, pinUnlocked: state.pinUnlocked);
    unawaited(ref.read(localStoreProvider).device.put(_manualKey, '$active'));
  }

  /// Kotlin's unlock: a child's lock lifts for this run, a manual mode ends.
  void unlocked({required bool isChild}) {
    state = (manual: state.manual, pinUnlocked: isChild || state.pinUnlocked);
    if (state.manual) setManual(active: false);
  }

  /// Puts a child's lock back.
  void relock() => state = (manual: state.manual, pinUnlocked: false);

  /// Whether a PIN was ever set on this phone.
  bool get hasPin => ref.read(localStoreProvider).device.get(_hashKey) != null;

  static String _sha(String pin) => sha256.convert(utf8.encode(pin)).toString();

  /// Sets the PIN.
  void setPin(String pin) =>
      unawaited(ref.read(localStoreProvider).device.put(_hashKey, _sha(pin)));

  /// Checks [pin]; a miss starts the guessing delay.
  bool verify(String pin) {
    final stored = ref.read(localStoreProvider).device.get(_hashKey);
    if (stored == null) return false;
    final ok = stored == _sha(pin);
    if (!ok) _lastFailure = DateTime.now();
    return ok;
  }

  /// Kotlin's `clearAccountState` on sign-out: the next account on this phone
  /// starts with no PIN and no hand-over mode.
  static Future<void> clearAccountState(Box<String> device) async {
    await device.delete(_manualKey);
    await device.delete(_hashKey);
  }

  /// Time left before another guess is allowed.
  Duration get backoffRemaining {
    final left = _backoff - DateTime.now().difference(_lastFailure);
    return left.isNegative ? Duration.zero : left;
  }
}

/// Kids mode's switch and PIN.
final kidsModeProvider = NotifierProvider<KidsModeController, KidsModeState>(
  KidsModeController.new,
);

/// Whether the signed-in member is a child of the family.
final isChildRoleProvider = Provider<bool>((ref) {
  final view = ref.watch(familyControllerProvider);
  return view.family?.me(view.userId)?.role == FamilyRole.child;
});

/// Kotlin's `kidsModeEffective`.
final kidsModeActiveProvider = Provider<bool>((ref) {
  final s = ref.watch(kidsModeProvider);
  return (ref.watch(isChildRoleProvider) && !s.pinUnlocked) || s.manual;
});
