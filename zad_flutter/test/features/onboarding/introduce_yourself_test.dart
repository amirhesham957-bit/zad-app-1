// «عرّفني بيك»: every account says who it is, how to be addressed, its place
// in the home and who it looks after — and nobody is asked twice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/onboarding/application/introduction_gate.dart';
import 'package:zad/features/onboarding/presentation/introduce_yourself_screen.dart';
import 'package:zad/shared/brain/application/memory_controller.dart';
import 'package:zad/shared/brain/data/memory_repository.dart';
import 'package:zad/shared/brain/domain/customer_profile.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/profile/application/profile_controller.dart';

class _Memory extends MemoryController {
  new(this.profile, {this.fetched = true});

  final CustomerProfile? profile;
  final bool fetched;
  CustomerProfile? saved;

  @override
  MemoryView build() => MemoryView(
    snapshot: MemorySnapshot(profile: profile),
    hasFetched: fetched,
  );

  @override
  Future<void> refresh() async {}

  @override
  Future<MemoryWriteFailure?> saveProfile(CustomerProfile profile) async {
    saved = profile;
    return null;
  }
}

class _Profile extends ProfileController {
  @override
  ProfileView build() => const ProfileView(name: 'أمير');
}

const _complete = CustomerProfile(
  preferredName: 'أمير',
  gender: 'male',
  householdRole: 'son',
  caresFor: <String>['parents'],
);

void main() {
  group('who is asked', () {
    bool needs(CustomerProfile? p, {bool fetched = true, bool kids = false}) {
      final c = ProviderContainer(
        overrides: [
          memoryControllerProvider.overrideWith(
            () => _Memory(p, fetched: fetched),
          ),
          kidsModeActiveProvider.overrideWithValue(kids),
        ],
      );
      addTearDown(c.dispose);
      return c.read(needsIntroductionProvider);
    }

    test('an account with no profile, once the server said so', () {
      expect(needs(null), isTrue);
    });

    test('never on a read that has not happened or failed', () {
      expect(needs(null, fetched: false), isFalse);
    });

    test('a profile missing who they look after is not complete', () {
      const noCare = CustomerProfile(
        preferredName: 'أمير',
        gender: 'male',
        householdRole: 'son',
      );
      expect(needs(noCare), isTrue);
    });

    test('a complete profile — «nobody» counts as an answer', () {
      expect(needs(_complete), isFalse);
      const alone = CustomerProfile(
        preferredName: 'سارة',
        gender: 'female',
        householdRole: 'single',
        caresFor: <String>[],
      );
      expect(needs(alone), isFalse);
    });

    test('not in kids mode', () {
      expect(needs(null, kids: true), isFalse);
    });
  });

  group('the profile carries who they look after', () {
    test('read from the row and written back only when known', () {
      final p = CustomerProfile.fromJson(const <String, dynamic>{
        'cares_for': <dynamic>['parents', 'children'],
      });
      expect(p.caresFor, <String>['parents', 'children']);
      expect(p.toFormJson()['cares_for'], <String>['parents', 'children']);
      // An older form that never asked must not wipe the answer.
      expect(
        const CustomerProfile(gender: 'male').toFormJson(),
        isNot(contains('cares_for')),
      );
      expect(
        const CustomerProfile(caresFor: <String>['parents', 'pets', 'parents'])
            .normalized()
            .caresFor,
        <String>['parents'],
      );
    });
  });

  testWidgets('a son who looks after his parents says so in four taps', (
    tester,
  ) async {
    final memory = _Memory(null);
    tester.view
      ..physicalSize = const Size(1080, 3600)
      ..devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryControllerProvider.overrideWith(() => memory),
          profileControllerProvider.overrideWith(_Profile.new),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: IntroduceYourselfScreen(),
          ),
        ),
      ),
    );

    // The sign-up name is already there.
    expect(find.text('أمير'), findsOneWidget);
    FilledButton go() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'يلا بينا'),
    );
    expect(go().onPressed, isNull);

    // «ابن» answers the address question too.
    await tester.tap(find.text('ابن'));
    await tester.pump();
    await tester.tap(find.text('أبويا أو أمي'));
    await tester.pump();
    expect(go().onPressed, isNotNull);

    // Payday is optional; the 5th here.
    await tester.ensureVisible(find.byType(DropdownButtonFormField<int?>));
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('يوم 5').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('يلا بينا'));
    await tester.tap(find.text('يلا بينا'));
    await tester.pump();
    expect(memory.saved?.preferredName, 'أمير');
    expect(memory.saved?.gender, 'male');
    expect(memory.saved?.householdRole, 'son');
    expect(memory.saved?.caresFor, <String>['parents']);
    expect(memory.saved?.payDay, 5);
  });
}
