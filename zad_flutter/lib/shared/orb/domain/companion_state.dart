/// Kotlin's `CompanionState` (CompanionOrb.kt): the agent's mood, each with
/// the orb's two colours. The colours are identity, not theme tokens — "red
/// is an alert" stays red in the dark theme as a logo would.
library;

import 'dart:ui';

/// The orb's mood.
enum CompanionState {
  /// Emerald: calm.
  idle(Color(0xFF34D399), Color(0xFF064E3B), 'زاد: هادئ'),

  /// Cyan: listening.
  listening(Color(0xFF00E5FF), Color(0xFF0E7490), 'زاد: بيسمع'),

  /// Violet: thinking.
  focused(Color(0xFFB388FF), Color(0xFF4A148C), 'زاد: بيفكر'),

  /// Blue: speaking.
  speaking(Color(0xFF38BDF8), Color(0xFF1D4ED8), 'زاد: بيتكلم'),

  /// Light green: pleased.
  happy(Color(0xFF7CFFB2), Color(0xFF00B26A), 'زاد: مبسوط'),

  /// Red: an alert.
  alert(Color(0xFFFF8A80), Color(0xFFD32F2F), 'زاد: تنبيه'),

  /// Gold: celebrating.
  celebrating(Color(0xFFFFE066), Color(0xFFF59E0B), 'زاد: بيحتفل'),

  /// Dusty blue: sad — left hungry and thirsty for too long.
  sad(Color(0xFFA9BCD8), Color(0xFF41587A), 'زاد: زعلان'),

  /// Warm orange: hungry.
  hungry(Color(0xFFFFB27A), Color(0xFFD9622B), 'زاد: جعان'),

  /// Teal: thirsty.
  thirsty(Color(0xFF8EE3DA), Color(0xFF13827A), 'زاد: عطشان'),

  /// Lavender: sleepy.
  sleepy(Color(0xFFC9BCF2), Color(0xFF55469A), 'زاد: نعسان');

  new(this.sky, this.deep, this.description);

  /// The lit colour.
  final Color sky;

  /// The shadowed colour.
  final Color deep;

  /// What TalkBack says.
  final String description;

  /// A need of the virtual pet (`pet_care.dart`) rather than something the
  /// agent is doing: the character takes more of the mood's colour, so a
  /// hungry or sleepy pet reads at a glance.
  bool get isNeed =>
      this == sad || this == hungry || this == thirsty || this == sleepy;
}

const List<String> _alertToneWords = <String>[
  'تنبيه',
  'تحذير',
  'خطر',
  'حذر',
  'تجاوزت',
  'نفاد',
  'أوشك',
  'قارب على النفاد',
];

const List<String> _happyToneWords = <String>[
  'ممتاز',
  'أحسنت',
  'تهانينا',
  'مبروك',
  'رائع',
  'وفرت',
  'نجحت',
  'تحقيق هدف',
];

/// Kotlin's `companionStateForMessage`: the mood a chat reply leaves the orb
/// in, by keywords — no model call. The words are matched against the reply
/// text, so they stay Arabic.
CompanionState companionStateForMessage(String text) {
  if (_alertToneWords.any(text.contains)) return CompanionState.alert;
  if (_happyToneWords.any(text.contains)) return CompanionState.happy;
  return CompanionState.idle;
}

/// Kotlin's `smoothOrbLevel`: an exponential filter that rises faster (0.45)
/// than it falls (0.12), so the first syllable shows at once and a pause
/// between words does not drop the orb to nothing.
double smoothOrbLevel(double current, double raw) {
  final target = raw.clamp(0.0, 1.0);
  final factor = target > current ? 0.45 : 0.12;
  return current + (target - current) * factor;
}
