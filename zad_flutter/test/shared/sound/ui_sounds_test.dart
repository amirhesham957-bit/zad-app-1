// The UI sounds (ZAD_PLAN ٢.٢): off until the customer turns them on, one
// chime when they do, and chimes quiet enough never to startle.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/orb/application/pet_sound.dart';
import 'package:zad/shared/sound/ui_sounds.dart';

void main() {
  late List<List<ChimeNote>> played;

  setUp(() {
    played = <List<ChimeNote>>[];
    UiSoundsController.player = played.add;
  });

  test('off by default: nothing plays', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(uiSoundsProvider), isFalse);
    container.read(uiSoundsProvider.notifier).play(UiSound.saved);
    expect(played, isEmpty);
  });

  test('turned on, it plays one so the customer hears the choice', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(uiSoundsProvider.notifier).setEnabled(on: true);
    expect(played, <List<ChimeNote>>[UiSound.saved.notes]);
    container.read(uiSoundsProvider.notifier).play(UiSound.scan);
    expect(played.last, UiSound.scan.notes);
  });

  test('turned off, it stays quiet', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sounds = container.read(uiSoundsProvider.notifier)
      ..setEnabled(on: true)
      ..setEnabled(on: false);
    played.clear();
    sounds.play(UiSound.achieve);
    expect(played, isEmpty);
  });

  test('every chime is short, quiet, and starts and ends at silence', () {
    for (final sound in UiSound.values) {
      final pcm = renderChime(sound.notes, 0.35);
      final seconds = pcm.length / 44100;
      expect(seconds, lessThan(0.8), reason: sound.name);
      final peak = pcm.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
      expect(peak, lessThan(32767 * 0.4), reason: sound.name);
      expect(pcm.first.abs(), lessThan(200), reason: sound.name);
      expect(pcm.last.abs(), lessThan(2000), reason: sound.name);
    }
  });
}
