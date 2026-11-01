import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';

void main() {
  // The clock and battery were near-invisible on the light onboarding screens
  // (emulator, 2026-11-01): a transparent AppBar left the icon colour to a
  // guess, and nothing set it for screens with no AppBar at all.
  test('the light theme draws dark status-bar icons', () {
    expect(
      ZadTheme.light().appBarTheme.systemOverlayStyle,
      SystemUiOverlayStyle.dark,
    );
    expect(
      ZadTheme.overlayStyleFor(Brightness.light),
      SystemUiOverlayStyle.dark,
    );
  });

  test('the dark theme draws light status-bar icons', () {
    expect(
      ZadTheme.dark().appBarTheme.systemOverlayStyle,
      SystemUiOverlayStyle.light,
    );
  });
}
