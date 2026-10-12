// The mascot's contract with the designer's Rive file: the written spec and
// the code name the same things, every mood the app has reaches the file,
// only what changed is sent, and without the file the screen is the orb.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/mascot/domain/mascot_contract.dart';
import 'package:zad/shared/mascot/presentation/zad_mascot.dart';
import 'package:zad/shared/orb/application/orb_accessory_controller.dart';
import 'package:zad/shared/orb/application/orb_occasion_controller.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/domain/orb_accessory.dart';
import 'package:zad/shared/orb/domain/orb_occasion.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// The spec's ```contract block, as `key → value`.
Map<String, String> _specContract() {
  final spec = File('../docs/agent/ZAD_MASCOT_RIVE_SPEC.md').readAsStringSync();
  final block = RegExp(r'```contract\n([\s\S]*?)```').firstMatch(spec)!;
  return <String, String>{
    for (final line in block.group(1)!.trim().split('\n'))
      line.split(' = ').first.trim(): line
          .substring(line.indexOf(' = ') + 3)
          .trim(),
  };
}

class _Recorder implements MascotSink {
  new({this.absent = const <String>{}});

  final Set<String> absent;
  final List<String> calls = <String>[];

  bool _record(String call, String name) {
    calls.add(call);
    return !absent.contains(name);
  }

  @override
  bool setEnum(String name, String value) => _record('$name=$value', name);

  @override
  bool setNumber(String name, double value) => _record('$name=$value', name);

  @override
  bool setColor(String name, Color value) =>
      _record('$name=${value.toARGB32().toRadixString(16)}', name);

  @override
  bool fire(String name) => _record('$name!', name);
}

const MascotInputs _calm = MascotInputs(
  mood: 'idle',
  occasion: 'none',
  accessory: 'none',
);

void main() {
  test('the spec names exactly what the code binds to', () {
    final spec = _specContract();
    expect(spec['asset'], MascotContract.asset);
    expect(spec['artboard'], MascotContract.artboard);
    expect(spec['stateMachine'], MascotContract.stateMachine);
    expect(spec['viewModel'], MascotContract.viewModel);
    String enumOf(List<String> values) => values.join(', ');
    expect(
      spec['mood'],
      '${MascotContract.mood} : enum = ${enumOf(MascotContract.moods)}',
    );
    expect(spec['level'], '${MascotContract.level} : number');
    expect(
      spec['occasion'],
      '${MascotContract.occasion} : enum = '
      '${enumOf(MascotContract.occasions)}',
    );
    expect(spec['primary'], '${MascotContract.primary} : color');
    expect(spec['secondary'], '${MascotContract.secondary} : color');
    expect(
      spec['accessory'],
      '${MascotContract.accessory} : enum = '
      '${enumOf(MascotContract.accessories)}',
    );
    expect(spec['tap'], '${MascotContract.tap} : trigger');
    expect(spec['blink'], '${MascotContract.blink} : trigger');
    expect(spec.length, 12, reason: 'a name in the spec the code lacks');
  });

  test('every mood, look and accessory the app has is a value in the file', () {
    // Each of the orb's seven moods lands on its own value, and none of the
    // file's values is unreachable.
    expect(
      CompanionState.values.map(moodValue).toSet(),
      MascotContract.moods.toSet(),
    );
    expect(moodValue(CompanionState.focused), 'thinking');
    expect(
      OrbOccasionLook.values.map(occasionValue).toList(),
      MascotContract.occasions,
    );
    expect(
      OrbAccessory.values.map(accessoryValue).toList(),
      MascotContract.accessories,
    );
  });

  group('the binder', () {
    test('the first apply sets everything; the same again sets nothing', () {
      final sink = _Recorder();
      MascotBinder(sink)
        ..apply(
          const MascotInputs(
            mood: 'thinking',
            occasion: 'scarf',
            accessory: 'crown',
            primary: Color(0xFF006C35),
            secondary: Color(0xFFFFFFFF),
          ),
        )
        ..apply(
          const MascotInputs(
            mood: 'thinking',
            occasion: 'scarf',
            accessory: 'crown',
            primary: Color(0xFF006C35),
            secondary: Color(0xFFFFFFFF),
          ),
        );
      expect(sink.calls, <String>[
        'mood=thinking',
        'occasion=scarf',
        'accessory=crown',
        'primary=ff006c35',
        'secondary=ffffffff',
      ]);
    });

    test('a change sends only what changed', () {
      final sink = _Recorder();
      final binder = MascotBinder(sink)..apply(_calm);
      sink.calls.clear();
      binder.apply(
        const MascotInputs(
          mood: 'speaking',
          occasion: 'none',
          accessory: 'none',
        ),
      );
      expect(sink.calls, <String>['mood=speaking']);
    });

    test('the voice level is clamped, and an unchanged one is not resent', () {
      final sink = _Recorder();
      MascotBinder(sink)
        ..level(0.4)
        ..level(0.4)
        ..level(3)
        ..level(-1);
      expect(sink.calls, <String>['level=0.4', 'level=1.0', 'level=0.0']);
    });

    test('a name the file lacks is reported once, and the rest still play', () {
      final reported = <String>[];
      final sink = _Recorder(absent: <String>{'occasion', 'tap'});
      final binder = MascotBinder(sink, onMissing: reported.add)
        ..apply(_calm)
        ..apply(
          const MascotInputs(
            mood: 'happy',
            occasion: 'lantern',
            accessory: 'none',
          ),
        )
        ..tap()
        ..tap()
        ..blink();
      expect(reported, <String>['occasion', 'tap']);
      expect(binder.missing, <String>{'occasion', 'tap'});
      expect(sink.calls, contains('mood=happy'));
      expect(sink.calls, contains('blink!'));
    });

    test('from() reads the orb: same mood, look, colours and accessory', () {
      final inputs = MascotInputs.from(
        state: CompanionState.focused,
        occasion: const OrbOccasion(
          OrbOccasionLook.balloons,
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF10B981),
        ),
        accessory: OrbAccessory.bow,
      );
      expect(
        inputs,
        const MascotInputs(
          mood: 'thinking',
          occasion: 'balloons',
          accessory: 'bow',
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF10B981),
        ),
      );
    });
  });

  group('on screen', () {
    test('this build has no mascot file, so it reads as absent', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(mascotFileProvider.future), isFalse);
    });

    testWidgets('without the file it is the orb, with the same mood, size '
        'and tap', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mascotFileProvider.overrideWith((ref) async => false),
            orbAccessoryProvider.overrideWith(_NoAccessory.new),
            orbOccasionProvider.overrideWithValue(OrbOccasion.none),
          ],
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: ZadMascot(
                state: CompanionState.listening,
                size: 64,
                onTap: () => tapped++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final orb = tester.widget<CompanionOrb>(find.byType(CompanionOrb));
      expect(orb.state, CompanionState.listening);
      expect(orb.size, 64);
      await tester.tap(find.byType(CompanionOrb));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tapped, 1);
    });
  });
}

class _NoAccessory extends OrbAccessoryController {
  @override
  OrbAccessory build() => OrbAccessory.none;
}
