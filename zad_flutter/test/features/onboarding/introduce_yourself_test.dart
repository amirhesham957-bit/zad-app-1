// «عرّفني بيك»: every account says who it is, how to be addressed, its place
// in the home and who it looks after — and nobody is asked twice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/app_language.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/onboarding/application/first_steps_controller.dart';
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

class _Steps extends FirstStepsController {
  bool armed = false;

  @override
  bool build() => false;

  @override
  void arm() => armed = true;
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

  testWidgets('a son who looks after his parents says so in five taps', (
    tester,
  ) async {
    final memory = _Memory(null);
    final steps = _Steps();
    tester.view
      ..physicalSize = const Size(1080, 3600)
      ..devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryControllerProvider.overrideWith(() => memory),
          profileControllerProvider.overrideWith(_Profile.new),
          firstStepsControllerProvider.overrideWith(() => steps),
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
    // How many live at home is asked too (ZAD_PLAN ١٠.١): the pantry's
    // forecasts scale with it.
    expect(go().onPressed, isNull);
    await tester.ensureVisible(find.text('4'));
    await tester.tap(find.text('4'));
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
    expect(memory.saved?.householdSize, 4);
    // The first steps (ZAD_PLAN 2.9) follow the introduction.
    expect(steps.armed, isTrue);
  });

  Future<_Memory> pumpIntro(WidgetTester tester, {Locale? locale}) async {
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
          firstStepsControllerProvider.overrideWith(_Steps.new),
        ],
        child: MaterialApp(
          // The test device speaks English; the account's Arabic is chosen.
          locale: locale ?? const Locale('ar'),
          supportedLocales: kZadLocales,
          localizationsDelegates: ZadL10n.localizationsDelegates,
          home: const IntroduceYourselfScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return memory;
  }

  testWidgets('living alone answers the household question as one', (
    tester,
  ) async {
    final memory = await pumpIntro(tester);
    // Living alone says nothing about gender, so that is asked as usual.
    await tester.tap(find.text('راجل'));
    await tester.pump();
    await tester.tap(find.text('عايش لوحدي'));
    await tester.pump();
    await tester.tap(find.text('محدش — مسؤول عن نفسي بس'));
    await tester.pump();
    await tester.ensureVisible(find.text('يلا بينا'));
    await tester.tap(find.text('يلا بينا'));
    await tester.pump();
    expect(memory.saved?.householdRole, 'single');
    expect(memory.saved?.householdSize, 1);
  });

  testWidgets('seven or more is stored as seven', (tester) async {
    final memory = await pumpIntro(tester);
    await tester.tap(find.text('أب'));
    await tester.pump();
    await tester.tap(find.text('أولادي'));
    await tester.pump();
    await tester.ensureVisible(find.text('7 أو أكتر'));
    await tester.tap(find.text('7 أو أكتر'));
    await tester.pump();
    await tester.ensureVisible(find.text('يلا بينا'));
    await tester.tap(find.text('يلا بينا'));
    await tester.pump();
    expect(memory.saved?.householdSize, 7);
  });

  testWidgets('a Saudi account reads the introduction in Saudi', (
    tester,
  ) async {
    await pumpIntro(tester, locale: kSaudiArabic);
    expect(find.text('عرّفني عليك'), findsOneWidget);
    expect(find.text('وش أناديك؟'), findsOneWidget);
    expect(find.text('عيالي'), findsOneWidget);
    expect(find.text('كم شخص ساكن في البيت؟'), findsOneWidget);
    // Nothing Egyptian left on the screen.
    for (final egyptian in <String>[
      'أناديك بإيه؟',
      'غير كده',
      'مش ثابت / مش عايز أقول',
      'يلا بينا',
    ]) {
      expect(find.text(egyptian), findsNothing, reason: egyptian);
    }
  });
}
