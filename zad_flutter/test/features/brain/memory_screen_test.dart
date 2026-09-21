// The screen's promises: what زاد knows is shown in Arabic, nothing is
// forgotten or wiped without a question, and every answer is said.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/brain/application/memory_controller.dart';
import 'package:zad/features/brain/data/memory_repository.dart';
import 'package:zad/features/brain/domain/customer_profile.dart';
import 'package:zad/features/brain/domain/habits.dart';
import 'package:zad/features/brain/domain/memory_note.dart';
import 'package:zad/features/brain/presentation/memory_screen.dart';

class _Memory extends MemoryController {
  new(this.initial, {this.failure});

  final MemorySnapshot initial;
  final MemoryWriteFailure? failure;
  final List<String> calls = <String>[];

  @override
  MemoryView build() =>
      MemoryView(snapshot: initial, currency: 'EGP', hasFetched: true);

  @override
  Future<void> refresh() async {}

  @override
  Future<MemoryWriteFailure?> forget(MemoryNote note) async {
    calls.add('forget:${note.id}');
    return failure;
  }

  @override
  Future<MemoryWriteFailure?> clearOutings() async {
    calls.add('clear');
    return failure;
  }

  @override
  Future<MemoryWriteFailure?> saveProfile(CustomerProfile profile) async {
    calls.add('save:${profile.preferredName}:${profile.gender}');
    return failure;
  }
}

const _note = MemoryNote(
  id: 'n1',
  scope: 'spending_pattern',
  note: 'بيصرف أكتر يوم الخميس',
  evidenceCount: 3,
);

void main() {
  late _Memory fake;

  Future<void> pump(
    WidgetTester tester,
    MemorySnapshot snapshot, {
    MemoryWriteFailure? failure,
  }) async {
    fake = _Memory(snapshot, failure: failure);
    // A tall phone: the screen is one scrolling column of three cards, and
    // the default 800x600 surface cuts it off above the notes.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoryControllerProvider.overrideWith(() => fake)],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MemoryScreen(),
          ),
        ),
      ),
    );
  }

  testWidgets('nothing known yet says so, in every section', (tester) async {
    await pump(tester, const MemorySnapshot());

    expect(find.text('لسه مش عارفاه'), findsWidgets);
    await tester.scrollUntilVisible(find.text('لسه مفيش ذكريات'), 200);
    expect(find.text('لسه مفيش ذكريات'), findsOneWidget);
    expect(find.textContaining('لسه بيتعلم عاداتك'), findsOneWidget);
    expect(find.text('امسح خروجاتي'), findsNothing);
  });

  testWidgets('a note shows its scope in Arabic and how often it held', (
    tester,
  ) async {
    await pump(tester, const MemorySnapshot(notes: <MemoryNote>[_note]));
    await tester.scrollUntilVisible(find.text(_note.note), 200);

    expect(find.text('صرفك'), findsOneWidget);
    expect(find.text('اتأكدت 3 مرة'), findsOneWidget);
    expect(find.textContaining('spending_pattern'), findsNothing);
  });

  testWidgets('forgetting is asked first; "wait" keeps the note', (
    tester,
  ) async {
    await pump(tester, const MemorySnapshot(notes: <MemoryNote>[_note]));
    await tester.scrollUntilVisible(find.byTooltip('انسى دي'), 200);

    await tester.tap(find.byTooltip('انسى دي'));
    await tester.pumpAndSettle();
    expect(find.text('تنسى الملاحظة دي؟'), findsOneWidget);
    await tester.tap(find.text('استنى'));
    await tester.pumpAndSettle();
    expect(fake.calls, isEmpty);

    await tester.tap(find.byTooltip('انسى دي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('انساها'));
    await tester.pumpAndSettle();
    expect(fake.calls, <String>['forget:n1']);
    expect(find.text('اتنسيت'), findsOneWidget);
  });

  testWidgets('a forget that did not happen says why', (tester) async {
    await pump(
      tester,
      const MemorySnapshot(notes: <MemoryNote>[_note]),
      failure: MemoryWriteFailure.offline,
    );
    await tester.scrollUntilVisible(find.byTooltip('انسى دي'), 200);

    await tester.tap(find.byTooltip('انسى دي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('انساها'));
    await tester.pumpAndSettle();
    expect(find.text(MemoryWriteFailure.offline.message), findsOneWidget);
    expect(find.text('اتنسيت'), findsNothing);
  });

  testWidgets('outings: the figures, and a wipe that is asked first', (
    tester,
  ) async {
    await pump(
      tester,
      MemorySnapshot(
        behavior: const <String, dynamic>{'avg_weekly_spending': 700},
        visits: <PlaceVisit>[
          PlaceVisit(
            returnedAt: DateTime.utc(2026, 9, 20),
            spentTotal: 150,
            places: const <String>['كارفور'],
          ),
        ],
      ),
    );

    expect(find.text('700 EGP'), findsOneWidget);
    expect(find.text('1 خروجة'), findsOneWidget);
    expect(find.text('كارفور'), findsOneWidget);

    await tester.tap(find.text('امسح خروجاتي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('امسحها'));
    await tester.pumpAndSettle();
    expect(fake.calls, <String>['clear']);
    expect(find.text('اتمسحت خروجاتك'), findsOneWidget);
  });

  testWidgets('the profile shows in words and saves what was chosen', (
    tester,
  ) async {
    await pump(
      tester,
      const MemorySnapshot(
        profile: CustomerProfile(
          preferredName: 'أمير',
          householdRole: 'father',
          payDay: 25,
          payFrequency: 'monthly',
        ),
      ),
    );
    expect(find.text('أمير'), findsOneWidget);
    expect(find.text('أب'), findsOneWidget);
    expect(find.text('يوم 25 · شهري'), findsOneWidget);

    await tester.tap(find.text('تعديل'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('ذكر'));
    await tester.pump();
    await tester.ensureVisible(find.text('احفظ'));
    await tester.pump();
    await tester.tap(find.text('احفظ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(fake.calls, <String>['save:أمير:male']);
    expect(find.text('اتحفظ'), findsOneWidget);
  });
}
