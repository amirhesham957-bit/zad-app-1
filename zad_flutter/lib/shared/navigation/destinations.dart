/// Where a screen opened through ZadScreens lands: which tab of البيت, of عقل
/// زاد والعائلة, which camera.
library;

import 'package:flutter/widgets.dart';

/// Which part of the household is showing.
enum HouseholdSection {
  /// What is in the kitchen.
  pantry,

  /// What to buy.
  shopping,

  /// Medicines and doses.
  pharmacy,

  /// What to cook from what is in the kitchen.
  recipes,
}

/// Asks the household screen around a section to show another one in place
/// — the pantry's «نواقص المخزون» banner opens «التسوق» this way, since the
/// shortages live on the shopping list (one list, the owner 2026-11-04).
class OpenHouseholdSection extends Notification {
  /// Creates the request.
  const new(this.section);

  /// The section to show.
  final HouseholdSection section;
}

/// The two tabs.
enum BrainFamilyTab {
  /// عقل زاد.
  intelligence,

  /// العائلة.
  family,
}

/// What the screen scans.
enum CameraMode {
  /// The pantry.
  inventory,

  /// A receipt.
  receipt,

  /// A medicine box.
  pharmacy,
}
