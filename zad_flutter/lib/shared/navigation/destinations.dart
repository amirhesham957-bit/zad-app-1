/// Where a screen opened through ZadScreens lands: which tab of البيت, of عقل
/// زاد والعائلة, which camera.
library;

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
