/// Kotlin's `OrbAccessory`: Zad's orb dresses up as the family grows — each
/// accessory unlocks at a family size (the user counts). No invite tracking:
/// a member who actually joined is the proof.
library;

/// One accessory and the family size that unlocks it.
enum OrbAccessory {
  /// Bare.
  none('none', 1, 'من غير'),

  /// A bow.
  bow('bow', 2, 'فيونكة'),

  /// Glasses.
  glasses('glasses', 3, 'نضارة'),

  /// A flower.
  flower('flower', 4, 'وردة'),

  /// A crown.
  crown('crown', 5, 'تاج');

  new(this.prefValue, this.familySizeNeeded, this.label);

  /// What the device box stores.
  final String prefValue;

  /// Family members needed, the user included.
  final int familySizeNeeded;

  /// The Arabic name under the preview.
  final String label;

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
