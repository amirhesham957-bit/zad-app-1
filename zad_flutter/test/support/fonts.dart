/// The app's real fonts, for golden tests — see
/// `test/design/design_system_golden_test.dart` for why each one is needed.
library;

import 'package:flutter/services.dart';

/// Loads Cairo, Inter and the Lucide icon font.
Future<void> loadZadFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }

  await load('Cairo', 'assets/fonts/cairo_variable.ttf');
  await load('Inter', 'assets/fonts/inter_variable.ttf');
  await load(
    'packages/lucide_icons_flutter/Lucide',
    'packages/lucide_icons_flutter/assets/lucide.ttf',
  );
}
