/// Kotlin's `OrbAccessory`: Zad's orb dresses up as the family grows — each
/// accessory unlocks at a family size (the user counts). No invite tracking:
/// a member who actually joined is the proof.
library;

import 'package:zad/core/l10n/l10n.dart';

/// One accessory and the family size that unlocks it.
enum OrbAccessory {
  /// Bare.
  none('none', 1),

  /// A bow.
  bow('bow', 2),

  /// Glasses.
  glasses('glasses', 3),

  /// A flower.
  flower('flower', 4),

  /// A crown.
  crown('crown', 5);

  new(this.prefValue, this.familySizeNeeded);

  /// What the device box stores.
  final String prefValue;

  /// Family members needed, the user included.
  final int familySizeNeeded;

  /// The name under the preview, in [l10n]'s language (Arabic by default).
  String label([ZadL10n? l10n]) =>
      (l10n ?? zadL10nArabic).orbAccessoryLabel(name);

  /// Whether a family of [familySize] has it.
  bool isUnlocked(int familySize) => familySize >= familySizeNeeded;

  /// Reads a stored value; anything unknown is [none].
  static OrbAccessory from(String? value) => OrbAccessory.values.firstWhere(
    (a) => a.prefValue == value,
    orElse: () => OrbAccessory.none,
  );

  /// The nearest one still locked, for «فاضل … وتفتح …».
  static OrbAccessory? nextLocked(int familySize) {
    for (final a in OrbAccessory.values) {
      if (!a.isUnlocked(familySize)) return a;
    }
    return null;
  }
}
