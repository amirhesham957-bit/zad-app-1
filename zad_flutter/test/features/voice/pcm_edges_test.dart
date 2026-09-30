// A clip that starts or stops mid-wave clicks; sentence after sentence the
// clicks read as noise (owner: «تشويش», 2026-09-30).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/voice/domain/speech_text.dart';

Uint8List _loud(int samples) {
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    data.setInt16(i * 2, 20000, Endian.little);
  }
  return data.buffer.asUint8List();
}

int _sample(Uint8List pcm, int i) =>
    ByteData.sublistView(pcm).getInt16(i * 2, Endian.little);

void main() {
  test('a clip starts and ends at silence, its middle untouched', () {
    final out = smoothPcmEdges(_loud(24000)); // one second
    expect(_sample(out, 0), 0);
    expect(_sample(out, 23999).abs(), lessThan(200));
    expect(_sample(out, 12000), 20000);
    expect(out.length, 48000);
  });

  test('an odd trailing byte is dropped, not played as static', () {
    final odd = Uint8List.fromList(<int>[..._loud(24000), 7]);
    expect(smoothPcmEdges(odd).length, 48000);
  });

  test('a clip too short to fade is left as it is', () {
    final tiny = Uint8List.fromList(<int>[1, 2, 3, 4]);
    expect(smoothPcmEdges(tiny), tiny);
  });
}
