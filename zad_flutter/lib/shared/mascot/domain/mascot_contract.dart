/// The contract between the app and the designer's Rive file for Zad's
/// mascot — every name the app looks for, in one place.
///
/// The designer builds to this; `ZadMascot` binds to it. The written spec,
/// `docs/agent/ZAD_MASCOT_RIVE_SPEC.md`, lists the same names, and
/// `mascot_contract_test.dart` fails if the two disagree — a renamed enum
/// value in either place would otherwise only show as a mascot that stops
/// reacting, on a customer's phone.
///
/// Data Binding (a View Model), not state-machine inputs: it is what Rive
/// recommends for new files (rive 0.14), and one View Model carries enums,
/// numbers, colours and triggers alike.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/domain/orb_accessory.dart';
import 'package:zad/shared/orb/domain/orb_occasion.dart';

/// The names in the file.
abstract final class MascotContract {
  /// Where the file goes. Dropping it here is the whole install: the folder
  /// is already declared in pubspec.yaml.
  static const String asset = 'assets/rive/zad_mascot.riv';

  /// The artboard.
  static const String artboard = 'Zad';

  /// The state machine that plays it.
  static const String stateMachine = 'Zad';

  /// The View Model bound to the state machine.
  static const String viewModel = 'Zad';

  /// Enum property: what Zad is doing ([moods]).
  static const String mood = 'mood';

  /// Number property, 0..1: the voice's loudness while listening or speaking.
  static const String level = 'level';

  /// Enum property: the season's look ([occasions]).
  static const String occasion = 'occasion';

  /// Colour property: the occasion's first colour.
  static const String primary = 'primary';

  /// Colour property: the occasion's second colour.
  static const String secondary = 'secondary';

  /// Enum property: what the family has unlocked ([accessories]).
  static const String accessory = 'accessory';

  /// Trigger: the customer tapped Zad.
  static const String tap = 'tap';

  /// Trigger: blink twice now.
  static const String blink = 'blink';

  /// Enum property: which رفيق زاد character ([personas]).
  static const String persona = 'persona';

  /// Number property: its stage, 0 (بذرة) to 4 (حكيم).
  static const String stage = 'stage';

  /// Enum property: what it wears ([outfits]).
  static const String outfit = 'outfit';

  /// Boolean property: asleep (away two days or more, until greeted).
  static const String asleep = 'asleep';

  /// The `persona` enum's values — `zad_companion_items` ids.
  static const List<String> personas = <String>[
    'zado',
    'basbous',
    'fella',
    'felfool',
    'mishmish',
    'toota',
    'fanoos',
    'maamoul',
  ];

  /// The `outfit` enum's values.
  static const List<String> outfits = <String>[
    'none',
    'sunglasses',
    'winter_hat',
    'chef_hat',
    'shemagh',
    'grad_cap',
  ];

  /// The `mood` enum's values, in the order the spec lists them.
  static const List<String> moods = <String>[
    'idle',
    'listening',
    'thinking',
    'speaking',
    'happy',
    'alert',
    'celebrating',
  ];

  /// The `occasion` enum's values.
  static const List<String> occasions = <String>[
    'none',
    'lantern',
    'balloons',
    'scarf',
  ];

  /// The `accessory` enum's values.
  static const List<String> accessories = <String>[
    'none',
    'bow',
    'glasses',
    'flower',
    'crown',
  ];
}

/// The `mood` value for [state]. The orb's `focused` is the file's
/// `thinking` — the word the owner and the designer use.
String moodValue(CompanionState state) => switch (state) {
  CompanionState.idle => 'idle',
  CompanionState.listening => 'listening',
  CompanionState.focused => 'thinking',
  CompanionState.speaking => 'speaking',
  CompanionState.happy => 'happy',
  CompanionState.alert => 'alert',
  CompanionState.celebrating => 'celebrating',
};

/// The `occasion` value for [look].
String occasionValue(OrbOccasionLook look) => look.name;

/// The `accessory` value for [accessory].
String accessoryValue(OrbAccessory accessory) => accessory.prefValue;

/// Everything the app tells the file, as plain values.
@immutable
class MascotInputs {
  /// Creates the inputs.
  const new({
    required this.mood,
    required this.occasion,
    required this.accessory,
    this.primary,
    this.secondary,
    this.persona = 'zado',
    this.stage = 3,
    this.outfit = 'none',
    this.asleep = false,
  });

  /// From the orb's own inputs, so the mascot and the orb never disagree.
  factory from({
    required CompanionState state,
    required OrbOccasion occasion,
    required OrbAccessory accessory,
    CompanionLook? look,
  }) => MascotInputs(
    mood: moodValue(state),
    occasion: occasionValue(occasion.look),
    accessory: accessoryValue(accessory),
    primary: occasion.primary,
    secondary: occasion.secondary,
    persona: look?.persona.id ?? 'zado',
    stage: (look?.stage ?? CompanionStage.companion).index.toDouble(),
    outfit: look?.outfit.id ?? 'none',
    asleep: look?.asleep ?? false,
  );

  /// `mood`.
  final String mood;

  /// `occasion`.
  final String occasion;

  /// `accessory`.
  final String accessory;

  /// `primary`; left as the file has it when null.
  final Color? primary;

  /// `secondary`; left as the file has it when null.
  final Color? secondary;

  /// `persona`.
  final String persona;

  /// `stage`, 0..4.
  final double stage;

  /// `outfit`.
  final String outfit;

  /// `asleep`.
  final bool asleep;

  @override
  bool operator ==(Object other) =>
      other is MascotInputs &&
      other.mood == mood &&
      other.occasion == occasion &&
      other.accessory == accessory &&
      other.primary == primary &&
      other.secondary == secondary &&
      other.persona == persona &&
      other.stage == stage &&
      other.outfit == outfit &&
      other.asleep == asleep;

  @override
  int get hashCode => Object.hash(
    mood,
    occasion,
    accessory,
    primary,
    secondary,
    persona,
    stage,
    outfit,
    asleep,
  );
}

/// Where the inputs go: the bound View Model in the app, a recorder in
/// tests (the Rive runtime is native and does not load under
/// `flutter test`).
abstract interface class MascotSink {
  /// Sets enum property [name] to [value]; false when the file has no such
  /// property.
  bool setEnum(String name, String value);

  /// Sets number property [name]; false when missing.
  bool setNumber(String name, double value);

  /// Sets colour property [name]; false when missing.
  bool setColor(String name, Color value);

  /// Sets boolean property [name]; false when missing.
  bool setBool(String name, {required bool value});

  /// Fires trigger [name]; false when missing.
  bool fire(String name);
}

/// Pushes [MascotInputs] into a [MascotSink], only what changed, and reports
/// each name the file turned out not to have — once — so a file built to an
/// older spec shows up in the log instead of as a mascot that ignores one
/// mood.
class MascotBinder {
  /// Creates a binder over a sink; [onMissing] hears each absent name once.
  new(this._sink, {void Function(String name)? onMissing})
    : _onMissing = onMissing ?? ((_) {});

  final MascotSink _sink;
  final void Function(String name) _onMissing;
  final Set<String> _missing = <String>{};
  MascotInputs? _last;
  double? _lastLevel;

  /// Names the file did not have.
  Set<String> get missing => Set<String>.unmodifiable(_missing);

  /// Applies [inputs]; the first call sets everything.
  void apply(MascotInputs inputs) {
    final last = _last;
    if (last == inputs) return;
    if (last?.mood != inputs.mood) {
      _check(
        MascotContract.mood,
        _sink.setEnum(MascotContract.mood, inputs.mood),
      );
    }
    if (last?.occasion != inputs.occasion) {
      _check(
        MascotContract.occasion,
        _sink.setEnum(MascotContract.occasion, inputs.occasion),
      );
    }
    if (last?.accessory != inputs.accessory) {
      _check(
        MascotContract.accessory,
        _sink.setEnum(MascotContract.accessory, inputs.accessory),
      );
    }
    if (last?.persona != inputs.persona) {
      _check(
        MascotContract.persona,
        _sink.setEnum(MascotContract.persona, inputs.persona),
      );
    }
    if (last?.stage != inputs.stage) {
      _check(
        MascotContract.stage,
        _sink.setNumber(MascotContract.stage, inputs.stage),
      );
    }
    if (last?.outfit != inputs.outfit) {
      _check(
        MascotContract.outfit,
        _sink.setEnum(MascotContract.outfit, inputs.outfit),
      );
    }
    if (last?.asleep != inputs.asleep) {
      _check(
        MascotContract.asleep,
        _sink.setBool(MascotContract.asleep, value: inputs.asleep),
      );
    }
    if (inputs.primary case final c? when last?.primary != c) {
      _check(MascotContract.primary, _sink.setColor(MascotContract.primary, c));
    }
    if (inputs.secondary case final c? when last?.secondary != c) {
      _check(
        MascotContract.secondary,
        _sink.setColor(MascotContract.secondary, c),
      );
    }
    _last = inputs;
  }

  /// The voice's loudness, clamped to 0..1; skipped when unchanged.
  void level(double value) {
    final v = value.clamp(0.0, 1.0);
    if (v == _lastLevel) return;
    _lastLevel = v;
    _check(MascotContract.level, _sink.setNumber(MascotContract.level, v));
  }

  /// The customer tapped Zad.
  void tap() => _check(MascotContract.tap, _sink.fire(MascotContract.tap));

  /// Blink twice.
  void blink() =>
      _check(MascotContract.blink, _sink.fire(MascotContract.blink));

  void _check(String name, bool found) {
    if (found || !_missing.add(name)) return;
    _onMissing(name);
  }
}
