// One ad per AI request (owner, 11/11): the recipe the chef writes carries an
// inline ad under its steps; while it loads, and when it fails, there is none.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/recipes/application/recipes_controller.dart';
import 'package:zad/features/recipes/domain/recipe.dart';
import 'package:zad/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/presentation/inline_ad.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';

import '../../support/quiet_household.dart';

class _Recipes extends RecipesController {
  @override
  RecipesView build() => const RecipesView();
}

void main() {
  var status = 200;
  Completer<void>? gate;
  // Built outside the tests: its auth client starts a timer the fake clock
  // would otherwise count as pending.
  final client = SupabaseClient(
    'https://example.supabase.co',
    'anon',
    httpClient: MockClient((request) async {
      await gate?.future;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'ok': true,
          'text': 'المقادير:\n• بيض\n\nطريقة التحضير:\n1. اطبخ',
        }),
        status,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
  );

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsAllowedProvider.overrideWithValue(false),
          supabaseClientProvider.overrideWithValue(client),
          recipesControllerProvider.overrideWith(_Recipes.new),
          pantryControllerProvider.overrideWith(QuietPantry.new),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            // No saved steps: the text has to come from the model.
            child: Scaffold(
              body: RecipeDetailDialog(recipe: Recipe(name: 'فطير')),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  setUp(() {
    status = 200;
    gate = null;
  });

  testWidgets('the chef recipe carries one inline ad, once it lands', (
    tester,
  ) async {
    gate = Completer<void>();
    await open(tester);
    await settle(tester);
    expect(find.byType(ZadInlineAd), findsNothing);

    gate!.complete();
    await settle(tester);
    expect(find.text('اطبخ'), findsOneWidget);
    expect(find.byType(ZadInlineAd), findsOneWidget);
  });

  testWidgets('a recipe that failed to load shows no ad', (tester) async {
    status = 500;
    await open(tester);
    await settle(tester);
    expect(find.textContaining('عذراً'), findsOneWidget);
    expect(find.byType(ZadInlineAd), findsNothing);
  });
}
