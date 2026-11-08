// «مدار أماكنك»: the most visited shop sits closest to home, every shop opens
// under the finger, and the screen says the distance is not a real one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/places/domain/my_places.dart';
import 'package:zad/features/places/presentation/places_orbit.dart';

const List<PlaceHabit> _habits = <PlaceHabit>[
  (name: 'كارفور', visits: 9, usualWeekday: DateTime.thursday),
  (name: 'العزبي', visits: 3, usualWeekday: null),
];

void main() {
  group('placeOrbit', () {
    test('more visits sit closer to home, and every distance fits', () {
      final nodes = placeOrbit(_habits);
      expect(nodes.first.distance, lessThan(nodes.last.distance));
      for (final n in nodes) {
        expect(n.distance, inInclusiveRange(0.45, 1));
      }
    });

    test('one shop, or equal visits, stays on the near ring', () {
      expect(placeOrbit(_habits.take(1).toList()).single.distance, 0.45);
    });

    test('at most eight shops, so the orbit stays readable', () {
      final many = <PlaceHabit>[
        for (var i = 0; i < 12; i++)
          (name: 'محل $i', visits: 20 - i, usualWeekday: null),
      ];
      expect(placeOrbit(many), hasLength(8));
    });

    test('nothing learned, nothing drawn', () {
      expect(placeOrbit(const <PlaceHabit>[]), isEmpty);
    });
  });

  group('on screen', () {
    late List<String> haptics;
    late List<String> opened;

    setUp(() {
      haptics = <String>[];
      opened = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              haptics.add(call.arguments as String);
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: ZadL10n.localizationsDelegates,
          supportedLocales: ZadL10n.supportedLocales,
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Directionality(textDirection: TextDirection.rtl, child: c!),
          ),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a shop buzzes and opens, and the caption tells the truth', (
      tester,
    ) async {
      await pump(
        tester,
        PlacesOrbit(
          habits: _habits,
          onOpen: (h) {
            opened.add(h.name);
          },
        ),
      );

      expect(
        find.text('الأقرب للبيت هو اللي بتروحه أكتر، مش المسافة الحقيقية.'),
        findsOneWidget,
      );
      await tester.tap(find.text('كارفور'));
      await tester.pump();
      expect(opened, <String>['كارفور']);
      expect(haptics, contains('HapticFeedbackType.selectionClick'));
    });

    testWidgets('a card says how often and opens the shop', (tester) async {
      await pump(
        tester,
        PlaceHabitCards(
          habits: _habits,
          onOpen: (h) {
            opened.add(h.name);
          },
        ),
      );

      expect(find.text('9 مرات · غالباً الخميس'), findsOneWidget);
      expect(find.text('3 مرات'), findsOneWidget);
      await tester.tap(find.text('العزبي'));
      await tester.pump();
      expect(opened, <String>['العزبي']);
    });
  });
}
