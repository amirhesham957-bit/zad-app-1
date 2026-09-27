/// The app's real fonts, for golden tests — see
/// `test/design/design_system_golden_test.dart` for why each one is needed.
library;

import 'package:flutter/services.dart';

/// Loads Cairo, Inter and the Material icon font.
Future<void> loadZadFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }

  await load('Cairo', 'assets/fonts/cairo_variable.ttf');
  await load('Inter', 'assets/fonts/inter_variable.ttf');
  // The app's icons are Material's since 596576c3; without the font every
  // one renders as a tofu box.
  await load('MaterialIcons', 'fonts/MaterialIcons-Regular.otf');
}
