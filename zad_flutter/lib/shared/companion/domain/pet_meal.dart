/// An expense card dropped on رفيق زاد (ZAD_PLAN ٥.٣): the drag carries this,
/// the pet logs it and eats. It lives here so a feature can hand the pet a
/// card without knowing the pet, and the pet can take one without knowing
/// the feature.
library;

import 'package:flutter/foundation.dart';

/// What a dragged expense brings the pet.
@immutable
class PetMeal {
  /// Creates it.
  const new({required this.label, required this.log});

  /// What it is, for the drag's chip.
  final String label;

  /// Logs it — the same as the card's own «تأكيد».
  final VoidCallback log;
}
