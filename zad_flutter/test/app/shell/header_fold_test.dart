import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/app/shell/zad_chrome.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';

import '../../support/fonts.dart';

void main() {
  setUpAll(loadZadFonts);

  // ZAD_PLAN ١٠.٨: the large title folds into the bar as the tab scrolls.
  testWidgets('the large title folds into the bar and opens again', (
    tester,
  ) async {
    final fold = ValueNotifier<double>(0);
    addTearDown(fold.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: ZadL10n.localizationsDelegates,
          supportedLocales: ZadL10n.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ZadTopHeader(
                title: 'فلوسي',
                onOpenDrawer: () {},
                onNotifications: () {},
                onAvatar: () {},
                fold: fold,
              ),
            ),
          ),
        ),
      ),
    );
    final open = tester.getSize(find.byType(ZadTopHeader)).height;
    Opacity small() => tester.widget<Opacity>(
      find.ancestor(
        of: find.text('فلوسي').first,
        matching: find.byType(Opacity),
      ),
    );
    expect(small().opacity, 0);

    fold.value = 1;
    await tester.pump();
    final folded = tester.getSize(find.byType(ZadTopHeader)).height;
    expect(open - folded, greaterThan(40));
    expect(small().opacity, 1);
    expect(tester.takeException(), isNull);

    fold.value = 0;
    await tester.pump();
    expect(tester.getSize(find.byType(ZadTopHeader)).height, open);
  });
}
