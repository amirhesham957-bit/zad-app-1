// The bottom bar wears a running occasion's colours — the mic orb its
// gradient, the selected tab its first colour — and is زاد green otherwise.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/app/shell/zad_bottom_nav_bar.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/zad_theme.dart';

const LinearGradient _halloween = LinearGradient(
  colors: <Color>[Color(0xFF4C1D95), Color(0xFF9A3412)],
);

Future<void> _pump(WidgetTester tester, LinearGradient? accent) =>
    tester.pumpWidget(
      MaterialApp(
        theme: ZadTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            bottomNavigationBar: ZadBottomNavBar(
              current: ZadNavDestination.home,
              onNavigate: (_) {},
              onOpenCamera: () {},
              onOpenVoice: () {},
              accent: accent,
            ),
          ),
        ),
      ),
    );

Iterable<Gradient?> _orbGradients(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .where((d) => d.shape == BoxShape.circle && d.gradient != null)
    .map((d) => d.gradient);

Color? _selectedTint(WidgetTester tester) => tester
    .widgetList<Icon>(find.byType(Icon))
    .firstWhere(
      (i) =>
          i.color == ZadColors.forestEmerald ||
          i.color == _halloween.colors.first,
    )
    .color;

void main() {
  testWidgets("the occasion's colours on the orb and the selected tab", (
    tester,
  ) async {
    await _pump(tester, _halloween);
    expect(_orbGradients(tester), contains(_halloween));
    expect(_selectedTint(tester), _halloween.colors.first);
  });

  testWidgets('no occasion: زاد green, as it was', (tester) async {
    await _pump(tester, null);
    expect(_orbGradients(tester), isNot(contains(_halloween)));
    expect(_selectedTint(tester), ZadColors.forestEmerald);
  });
}
