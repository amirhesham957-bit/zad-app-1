/// Turning a reply into what Zad's voice reads — Kotlin's
/// `ZadNaturalVoiceEngine.cleanRawText`, `splitIntoSpeechChunks` and
/// `buildSpeechChunks`, same rules.
library;

import 'dart:typed_data';

/// The longest text one turn speaks (`voice_synthesize` refuses over 1200).
const int maxSpokenLength = 1200;

/// Sentences are merged into chunks up to about this long, so each request
/// is short enough to come back fast and long enough to sound like speech.
const int chunkTarget = 200;

/// The first chunk is kept to about one short sentence. Gemini TTS takes
/// roughly two to three times the audio's length to produce it (measured
/// 2026-09-28: 30 s for an 11 s clip), and nothing plays until the first
/// chunk is back — a 200-character opener was most of the half-minute the
/// owner waited before Zad said anything.
const int firstChunkTarget = 90;

/// The reply cleaned for speech: links become «الرابط», markdown marks and
/// emoji/symbols become spaces (Azure reads an emoji's name aloud), runs of
/// whitespace collapse.
String speakableText(String raw) => raw
    .replaceAll(RegExp(r'https?://\S+'), 'الرابط')
    .replaceAll(RegExp(r'[#*`_~\[\]()]'), ' ')
    .replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}'
        r'\u{FE00}-\u{FE0F}\u{200D}\u{20E3}]',
        unicode: true,
      ),
      ' ',
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// [raw] as the chunks to request, in order. Split at sentence ends, merged
/// up to [chunkTarget], and only then given the comma pause («، ...») — the
/// other order made every comma a sentence end and a request of its own.
List<String> speechChunks(String raw) {
  var text = speakableText(raw);
  if (text.length > maxSpokenLength) {
    text = text.substring(0, maxSpokenLength);
  }
  if (text.isEmpty) return const <String>[];
  final sentences = text
      .split(RegExp(r'(?<=[.!؟?])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final merged = <String>[];
  final current = StringBuffer();
  for (final s in sentences) {
    final target = merged.isEmpty ? firstChunkTarget : chunkTarget;
    if (current.isNotEmpty && current.length + s.length > target) {
      merged.add(current.toString());
      current.clear();
    }
    if (current.isNotEmpty) current.write(' ');
    current.write(s);
  }
  if (current.isNotEmpty) merged.add(current.toString());
  return <String>[for (final c in merged) c.replaceAll('،', '، ...')];
}

/// How much of a streamed reply is enough to start talking: the first chunk
/// goes to the voice as soon as a sentence ends past this many characters, so
/// Zad starts speaking while the rest of the reply is still arriving.
const int firstStreamedChunk = 90;

/// Cuts a reply that arrives in pieces into chunks as soon as each one is
/// ready, with the same cleaning and comma pause as [speechChunks].
///
/// The first chunk is released at the first sentence end past
/// [firstStreamedChunk] characters; later ones at a sentence end past
/// [chunkTarget]. A reply with no sentence end is cut at a space once it runs
/// to twice the target, so a long unpunctuated answer is not held back until
/// it finishes. Nothing past [maxSpokenLength] is ever released.
class SpeechStreamSplitter {
  final StringBuffer _pending = StringBuffer();
  var _released = 0;
  var _first = true;

  /// Adds [delta] and returns the chunks it made ready, in order.
  List<String> add(String delta) {
    _pending.write(delta);
    return _drain(done: false);
  }

  /// The rest, once the reply has finished arriving.
  List<String> finish() => _drain(done: true);

  List<String> _drain({required bool done}) {
    final out = <String>[];
    for (var chunk = _take(done: done); chunk != null;) {
      out.add(chunk);
      chunk = _take(done: done);
    }
    return out;
  }

  String? _take({required bool done}) {
    if (_released >= maxSpokenLength) return null;
    final text = speakableText(_pending.toString());
    if (text.isEmpty) return null;
    final want = _first ? firstStreamedChunk : chunkTarget;

    int? cut;
    if (done) {
      cut = text.length;
    } else {
      // A sentence end followed by more text: the text after it has started,
      // so the sentence is complete.
      for (final m in RegExp(r'[.!؟?](?=\s)').allMatches(text)) {
        if (m.end >= want) {
          cut = m.end;
          break;
        }
      }
      if (cut == null && text.length >= chunkTarget * 2) {
        final space = text.lastIndexOf(' ', chunkTarget);
        cut = space > 0 ? space : chunkTarget;
      }
    }
    if (cut == null) return null;

    var chunk = text.substring(0, cut).trim();
    final room = maxSpokenLength - _released;
    if (chunk.length > room) chunk = chunk.substring(0, room);
    // The remainder is kept cleaned (cleaning it again changes nothing), but
    // a trailing space in what arrived is kept: the next piece may start with
    // a word, and dropping the space would glue the two together.
    final endsInSpace = RegExp(r'\s$').hasMatch(_pending.toString());
    final rest = text.substring(cut).trim();
    _pending
      ..clear()
      ..write(rest.isNotEmpty && endsInSpace ? '$rest ' : rest);
    if (chunk.isEmpty) return null;
    _first = false;
    _released += chunk.length;
    return chunk.replaceAll('،', '، ...');
  }
}

/// [pcm] with its first and last [fadeMs] faded in and out, and an odd
/// trailing byte dropped.
///
/// A clip that starts or stops mid-wave clicks; one after another, sentence
/// after sentence, the clicks read as noise. An odd byte count would shift
/// every sample after it into static.
Uint8List smoothPcmEdges(
  Uint8List pcm, {
  int sampleRate = 24000,
  int fadeMs = 8,
}) {
  final length = pcm.length - pcm.length % 2;
  final out = Uint8List.fromList(pcm.sublist(0, length));
  final samples = length ~/ 2;
  final fade = sampleRate * fadeMs ~/ 1000;
  // Too short to fade without eating the clip itself.
  if (fade <= 0 || samples < fade * 4) return out;
  final data = ByteData.sublistView(out);
  for (var i = 0; i < fade; i++) {
    final gain = i / fade;
    final head = data.getInt16(i * 2, Endian.little);
    data.setInt16(i * 2, (head * gain).round(), Endian.little);
    final t = samples - 1 - i;
    final tail = data.getInt16(t * 2, Endian.little);
    data.setInt16(t * 2, (tail * gain).round(), Endian.little);
  }
  return out;
}

/// Wraps `voice_synthesize`'s raw PCM (24 kHz, 16-bit, mono — the same bytes
/// Kotlin writes to AudioTrack) in a 44-byte WAV header a player can open.
Uint8List pcmToWav(
  Uint8List pcm, {
  int sampleRate = 24000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final header = ByteData(44)
    ..setUint32(0, 0x52494646) // "RIFF"
    ..setUint32(4, 36 + pcm.length, Endian.little)
    ..setUint32(8, 0x57415645) // "WAVE"
    ..setUint32(12, 0x666d7420) // "fmt "
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, byteRate, Endian.little)
    ..setUint16(32, blockAlign, Endian.little)
    ..setUint16(34, bitsPerSample, Endian.little)
    ..setUint32(36, 0x64617461) // "data"
    ..setUint32(40, pcm.length, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(pcm))
      .toBytes();
}
