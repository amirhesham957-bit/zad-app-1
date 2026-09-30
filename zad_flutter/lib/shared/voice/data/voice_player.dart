/// Plays one WAV clip to the end.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// Plays clips one at a time.
abstract interface class VoicePlayer {
  /// Plays [wav] and completes when it has finished, or when [stop] cut it.
  Future<void> play(Uint8List wav);

  /// Stops whatever is playing.
  Future<void> stop();

  /// Releases the player.
  Future<void> dispose();
}

/// A player that can load the next clip while the current one plays.
///
/// Each clip used to be written, loaded and started only once the previous
/// one had finished — a gap and a click between every sentence, which the
/// owner heard as «تشويش» (2026-09-30).
abstract interface class PreparingVoicePlayer implements VoicePlayer {
  /// Loads [wav] so that the next [play] of the same bytes starts at once.
  Future<void> prepare(Uint8List wav);
}

/// Over audioplayers, from temp files, on two players in turn: one plays
/// while the other holds the next clip, loaded and ready.
class AudioplayersVoicePlayer implements PreparingVoicePlayer {
  /// Creates a player.
  new()
    : _players = <AudioPlayer>[
        AudioPlayer(playerId: 'zad-voice-a'),
        AudioPlayer(playerId: 'zad-voice-b'),
      ];

  final List<AudioPlayer> _players;
  var _turn = 0;
  Completer<void>? _playing;
  Uint8List? _prepared;
  Future<void>? _preparing;

  Future<void> _load(int index, Uint8List wav) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/zad_voice_$index.wav');
    await file.writeAsBytes(wav, flush: true);
    await _players[index].setSource(DeviceFileSource(file.path));
  }

  @override
  Future<void> prepare(Uint8List wav) {
    final loading = _load(_turn, wav).then<void>(
      (_) => _prepared = wav,
      // A clip that failed to load is loaded again by play().
      onError: (Object _) {},
    );
    return _preparing = loading;
  }

  @override
  Future<void> play(Uint8List wav) async {
    await _preparing;
    _preparing = null;
    final index = _turn;
    _turn = 1 - _turn;
    if (!identical(_prepared, wav)) await _load(index, wav);
    _prepared = null;
    final player = _players[index];
    final done = _playing = Completer<void>();
    final sub = player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await player.resume();
      await done.future;
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> stop() async {
    final playing = _playing;
    _playing = null;
    _prepared = null;
    if (playing != null && !playing.isCompleted) playing.complete();
    for (final p in _players) {
      await p.stop();
    }
  }

  @override
  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
  }
}
