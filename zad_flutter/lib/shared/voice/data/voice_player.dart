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

/// Over audioplayers, from a temp file — a device file is the one source
/// every Android version plays without a data-URI size limit.
class AudioplayersVoicePlayer implements VoicePlayer {
  /// Creates a player.
  new() : _player = AudioPlayer(playerId: 'zad-voice');

  final AudioPlayer _player;
  Completer<void>? _playing;
  var _clip = 0;

  @override
  Future<void> play(Uint8List wav) async {
    await stop();
    final dir = await getTemporaryDirectory();
    // Two files in rotation: the next clip is written while this one plays.
    final file = File('${dir.path}/zad_voice_${_clip++ % 2}.wav');
    await file.writeAsBytes(wav, flush: true);
    final done = _playing = Completer<void>();
    final sub = _player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await _player.play(DeviceFileSource(file.path));
      await done.future;
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> stop() async {
    final playing = _playing;
    _playing = null;
    if (playing != null && !playing.isCompleted) playing.complete();
    await _player.stop();
  }

  @override
  Future<void> dispose() => _player.dispose();
}
