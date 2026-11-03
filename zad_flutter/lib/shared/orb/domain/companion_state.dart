/// Kotlin's `CompanionState` (CompanionOrb.kt): the agent's mood, each with
/// the orb's two colours. The colours are identity, not theme tokens — "red
/// is an alert" stays red in the dark theme as a logo would.
library;

import 'dart:ui';

import 'package:zad/core/l10n/l10n.dart';

/// The orb's mood.
enum CompanionState {
  /// Emerald: calm.
  idle(Color(0xFF34D399), Color(0xFF064E3B)),

  /// Cyan: listening.
  listening(Color(0xFF00E5FF), Color(0xFF0E7490)),

  /// Violet: thinking.
  focused(Color(0xFFB388FF), Color(0xFF4A148C)),

  /// Blue: speaking.
  speaking(Color(0xFF38BDF8), Color(0xFF1D4ED8)),

  /// Light green: pleased.
  happy(Color(0xFF7CFFB2), Color(0xFF00B26A)),

  /// Red: an alert.
  alert(Color(0xFFFF8A80), Color(0xFFD32F2F)),

  /// Gold: celebrating.
  celebrating(Color(0xFFFFE066), Color(0xFFF59E0B)),

  /// Dusty blue: sad — left hungry and thirsty for too long.
  sad(Color(0xFFA9BCD8), Color(0xFF41587A)),

  /// Warm orange: hungry.
  hungry(Color(0xFFFFB27A), Color(0xFFD9622B)),

  /// Teal: thirsty.
  thirsty(Color(0xFF8EE3DA), Color(0xFF13827A)),

  /// Lavender: sleepy.
  sleepy(Color(0xFFC9BCF2), Color(0xFF55469A));

  new(this.sky, this.deep);

  /// The lit colour.
  final Color sky;

  /// The shadowed colour.
  final Color deep;

  /// What TalkBack says, in [l10n]'s language (Arabic by default).
  String description([ZadL10n? l10n]) => (l10n ?? zadL10nArabic).orbMood(name);

  /// A need of the virtual pet (`pet_care.dart`) rather than something the
  /// agent is doing: the character takes more of the mood's colour, so a
  /// hungry or sleepy pet reads at a glance.
  bool get isNeed =>
      this == sad || this == hungry || this == thirsty || this == sleepy;
}

// Matched against the reply text.
// l10n: data-begin
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
// l10n: data-end

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
