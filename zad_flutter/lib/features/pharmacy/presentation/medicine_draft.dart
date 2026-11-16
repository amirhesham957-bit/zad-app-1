/// What the medicine form hands back, and how it opens. The one form serves
/// the customer's own medicines and the head's edits of a member's, so what
/// it saves into is the caller's: `onSave` gets the draft and answers a
/// failure reason (the form says it and stays open) or null when it saved.
library;

/// A filled-in medicine form.
class MedicineDraft {
  /// Creates a draft.
  const new({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.dailyDoseCount,
    required this.doseTimes,
    required this.unitsPerDose,
    this.expiry,
    this.price = 0,
    this.activeIngredient,
    this.dosage,
    this.category,
    this.recurring = false,
    this.memberId,
    this.forPerson,
  });

  /// What it is called.
  final String name;

  /// Units in the box.
  final int quantity;

  /// The unit.
  final String unit;

  /// Doses a day.
  final int dailyDoseCount;

  /// `HH:mm,HH:mm` as the server's regex wants it, or empty.
  final String doseTimes;

  /// Units one dose takes.
  final double unitsPerDose;

  /// The expiry date.
  final DateTime? expiry;

  /// The box's price.
  final double price;

  /// The active ingredient.
  final String? activeIngredient;

  /// Strength and instructions.
  final String? dosage;

  /// The category.
  final String? category;

  /// An ongoing medicine.
  final bool recurring;

  /// The family member it is for.
  final String? memberId;

  /// «لمين؟» by name.
  final String? forPerson;
}

/// Saves a draft; answers a failure reason, or null when saved.
typedef MedicineDraftSave = Future<String?> Function(MedicineDraft draft);
