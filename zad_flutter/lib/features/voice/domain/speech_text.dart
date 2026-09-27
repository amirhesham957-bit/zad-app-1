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
    if (current.isNotEmpty && current.length + s.length > chunkTarget) {
      merged.add(current.toString());
      current.clear();
    }
    if (current.isNotEmpty) current.write(' ');
    current.write(s);
  }
  if (current.isNotEmpty) merged.add(current.toString());
  return <String>[for (final c in merged) c.replaceAll('،', '، ...')];
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
