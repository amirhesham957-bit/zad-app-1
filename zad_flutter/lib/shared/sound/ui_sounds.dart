/// Zad's three UI sounds (ZAD_PLAN ٢.٢): an expense saved, a receipt read,
/// something achieved. Off until the customer turns them on in Settings —
/// sound in a quiet room or on a bus startles more than it pleases — and kept
/// on this phone only, like any other device preference.
///
/// Synthesised on the companion's sound engine (`pet_sound.dart`): short,
/// quiet chimes, no sound files.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/orb/application/pet_sound.dart';

/// The sounds there are, as the notes they ring.
enum UiSound {
  /// An expense or income saved: two soft rising notes, E6 then A6.
  saved(<ChimeNote>[
    (hz: 1318.5, startMs: 0, ms: 180),
    (hz: 1760.0, startMs: 70, ms: 260),
  ]),

  /// A receipt or photo read and saved: a short high tick, then G6.
  scan(<ChimeNote>[
    (hz: 2637.0, startMs: 0, ms: 30),
    (hz: 1568.0, startMs: 50, ms: 280),
  ]),

  /// A goal reached, a level up: C6 E6 G6 C7.
  achieve(<ChimeNote>[
    (hz: 1046.5, startMs: 0, ms: 300),
    (hz: 1318.5, startMs: 80, ms: 300),
    (hz: 1568.0, startMs: 160, ms: 300),
    (hz: 2093.0, startMs: 240, ms: 450),
  ]);

  new(this.notes);

  /// What it rings.
  final List<ChimeNote> notes;
}

/// Whether the UI sounds are on, and the way to play one.
class UiSoundsController extends Notifier<bool> {
  static const String _key = 'ui_sounds';

  /// Plays a chime; a test replaces it.
  static void Function(List<ChimeNote> notes) player = playChime;

  @override
  bool build() {
    try {
      return ref.read(localStoreProvider).device.get(_key) == 'true';
    } on Object {
      // No store (a test): sounds stay off.
      return false;
    }
  }

  /// Turns the sounds on or off. Turning them on plays one, so the customer
  /// hears what they chose.
  void setEnabled({required bool on}) {
    state = on;
    try {
      unawaited(ref.read(localStoreProvider).device.put(_key, '$on'));
    } on Object {
      // No store (a test): the choice lives for this run only.
    }
    play(UiSound.saved);
  }

  /// Plays [sound] if the sounds are on. Never waits and never throws.
  void play(UiSound sound) {
    if (state) player(sound.notes);
  }
}

/// The UI sounds.
final uiSoundsProvider = NotifierProvider<UiSoundsController, bool>(
  UiSoundsController.new,
);
