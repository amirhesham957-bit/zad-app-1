// No «اقتراحات التسوق» on a child's home (owner, 2026-10-13): olive oil and
// the rest of the household's groceries are not a child's shop window. The
// catalogue is served with products in it, so a returning row would show.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/kids/presentation/kids_home.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/application/family_life_controller.dart';
import 'package:zad/shared/family/data/family_repository.dart';
import 'package:zad/shared/family/domain/family.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

class _KidFamily extends FamilyController {
  @override
  FamilyView build() => const FamilyView(
    status: InFamily(
      Family(
        id: 'f1',
        inviteCode: 'ZAD-AAAA',
        members: <FamilyMember>[
          FamilyMember(
            id: 'm-kid',
            userId: 'kid',
            role: FamilyRole.child,
            alias: 'يويو',
          ),
        ],
      ),
    ),
    userId: 'kid',
  );

  @override
  Future<void> refresh() async {}
}

class _QuietLife extends FamilyLifeController {
  @override
  FamilyLifeView build() => const FamilyLifeView(isLoading: false);

  @override
  Future<void> refresh() async {}
}

void main() {
  late Directory dir;
  late ZadLocalStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_kids_no_shopping');
    Hive.init(dir.path);
    store = await ZadLocalStore.open();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  testWidgets('a child home shows no shopping suggestions', (tester) async {
    await tester.runAsync(loadZadFonts);
    await tester.binding.setSurfaceSize(const Size(412, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          supabaseClientProvider.overrideWithValue(quietSupabase),
          familyControllerProvider.overrideWith(_KidFamily.new),
          familyLifeControllerProvider.overrideWith(_QuietLife.new),
          affiliateProductsProvider.overrideWith(
            (ref) async => kDefaultAffiliateProducts,
          ),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: KidsHome(onOpenFamily: () {})),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(KidsHome), findsOneWidget);
    expect(find.text('اقتراحات التسوق'), findsNothing);
    expect(find.text(kDefaultAffiliateProducts.first.nameAr), findsNothing);
  });
}
