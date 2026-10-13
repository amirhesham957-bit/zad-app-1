// A child taps their picture on the kids' home, picks an animal and a name,
// and it is saved through the family controller (owner, 2026-10-13).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/kids/presentation/kids_home.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/application/family_life_controller.dart';
import 'package:zad/shared/family/data/family_repository.dart';
import 'package:zad/shared/family/domain/family.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

const _kid = FamilyMember(
  id: 'm-kid',
  userId: 'kid',
  role: FamilyRole.child,
  alias: 'يويو',
);

class _KidFamily extends FamilyController {
  final List<({String alias, String? emoji})> saved =
      <({String alias, String? emoji})>[];

  @override
  FamilyView build() => const FamilyView(
    status: InFamily(
      Family(id: 'f1', inviteCode: 'ZAD-AAAA', members: <FamilyMember>[_kid]),
    ),
    userId: 'kid',
  );

  @override
  Future<void> refresh() async {}

  @override
  Future<bool> updateIdentity(
    FamilyMember member, {
    required String alias,
    required String? avatarEmoji,
  }) async {
    saved.add((alias: alias, emoji: avatarEmoji));
    return true;
  }
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
    dir = await Directory.systemTemp.createTemp('zad_kid_identity');
    Hive.init(dir.path);
    store = await ZadLocalStore.open();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  testWidgets(
    'tapping the picture picks an animal and a name, and saves both',
    (tester) async {
      await tester.runAsync(loadZadFonts);
      final family = _KidFamily();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWithValue(store),
            supabaseClientProvider.overrideWithValue(quietSupabase),
            familyControllerProvider.overrideWith(() => family),
            familyLifeControllerProvider.overrideWith(_QuietLife.new),
          ],
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: KidsHome(onOpenFamily: () {})),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(KidAvatar).first);
      await tester.pumpAndSettle();
      expect(find.text('غيّر صورتك واسمك'), findsOneWidget);

      // An empty name is refused in words, and nothing is saved.
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('اكتب اسمك'), findsOneWidget);
      expect(family.saved, isEmpty);

      await tester.tap(find.text('🦊').last);
      await tester.enterText(find.byType(TextField), 'يوسف');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(family.saved, <({String alias, String? emoji})>[
        (alias: 'يوسف', emoji: '🦊'),
      ]);
      expect(find.text('غيّر صورتك واسمك'), findsNothing);
    },
  );

  test("a picked emoji wins over the seed's animal; none falls back to it", () {
    const picked = KidAvatar(seed: 'm-kid', emoji: '🦄');
    const auto = KidAvatar(seed: 'm-kid');
    expect(picked.emoji, '🦄');
    expect(auto.emoji, isNull);
    expect(KidAvatar.choices, contains(KidAvatar.autoEmoji('m-kid')));
  });
}
