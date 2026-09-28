import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/voice/domain/speech_text.dart';

void main() {
  group('speakableText', () {
    test('links, markdown and emoji do not reach the voice', () {
      expect(
        speakableText('**تمام** 👍 شوف https://zad.app/x (هنا)'),
        'تمام شوف الرابط هنا',
      );
      expect(speakableText('عيلة 👨‍👩‍👧 ✅ سعيدة'), 'عيلة سعيدة');
    });
  });

  group('speechChunks', () {
    test('one short sentence is one chunk', () {
      expect(speechChunks('صرفت ٥٠ جنيه.'), <String>['صرفت ٥٠ جنيه.']);
    });

    test('sentences merge up to about 200 characters', () {
      final sentence = '${'كلمة ' * 30}تمام.'; // ~155 chars
      final chunks = speechChunks('$sentence $sentence $sentence');
      expect(chunks, hasLength(3));
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(chunkTarget));
      }
      expect(speechChunks('أهلاً. إزيك؟ تمام!'), <String>[
        'أهلاً. إزيك؟ تمام!',
      ]);
    });

    test('the first chunk is one short sentence, so Zad starts sooner', () {
      final chunks = speechChunks(
        'تمام، سجلتها. ${'كلمة ' * 20}خلاص. ${'كلمة ' * 12}تمام.',
      );
      expect(chunks.first, 'تمام، ... سجلتها.');
      expect(chunks, hasLength(2));
    });

    test('commas pause after splitting, not before', () {
      // «، ...» holds a ". " — added before the split it would cut here.
      expect(speechChunks('أولاً، ثانياً، ثالثاً.'), <String>[
        'أولاً، ... ثانياً، ... ثالثاً.',
      ]);
    });

    test('capped at what voice_synthesize accepts', () {
      final long = List<String>.filled(400, 'كلام.').join(' ');
      final total = speechChunks(long).join(' ').length;
      expect(total, lessThanOrEqualTo(maxSpokenLength + 10));
    });

    test('nothing speakable is nothing', () {
      expect(speechChunks('  🎉 '), isEmpty);
    });
  });

  test('pcmToWav writes a 24 kHz, 16-bit mono header', () {
    final pcm = Uint8List.fromList(List<int>.filled(480, 7));
    final wav = pcmToWav(pcm);
    final h = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(h.getUint32(4, Endian.little), 36 + 480);
    expect(h.getUint16(22, Endian.little), 1);
    expect(h.getUint32(24, Endian.little), 24000);
    expect(h.getUint32(28, Endian.little), 48000);
    expect(h.getUint16(34, Endian.little), 16);
    expect(h.getUint32(40, Endian.little), 480);
    expect(wav.length, 44 + 480);
    expect(wav.sublist(44), pcm);
  });
}
