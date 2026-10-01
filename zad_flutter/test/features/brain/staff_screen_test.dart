// «فريق زاد»: the staff's morning notes, by who wrote them — and never a
// tool's own receipt, which «سجل تعديلات زاد» already shows.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/brain/presentation/staff_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  final rows = <Map<String, dynamic>>[
    <String, dynamic>{
      'sender': 'pharmacy',
      'subject': 'كورس خلص ولسه في الصيدلية: مضاد حيوي',
      'detail': 'الكمية صفر والدوا مش متجدد.',
      'created_at': '2026-10-01T05:00:00Z',
    },
    <String, dynamic>{
      'sender': 'pantry',
      'subject': 'نفّذ add_shopping_item',
      'detail': 'ضفت لبن',
      'created_at': '2026-10-01T06:00:00Z',
    },
    <String, dynamic>{
      'sender': 'brain',
      'subject': 'تليجرام مش مربوط',
      'detail': '',
      'created_at': '2026-10-01T07:00:00Z',
    },
  ];

  test('notes by who wrote them, newest first, receipts left out', () {
    final feed = staffFeed(rows);
    expect(feed.map((n) => n.role), <String>['مدرّب الإعداد', 'الممرضة']);
    expect(feed.any((n) => n.subject.startsWith('نفّذ')), isFalse);
    expect(staffMember('research').role, 'الباحث');
  });

  Future<void> pump(WidgetTester tester, List<StaffNote> notes) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [staffNotesProvider.overrideWith((ref) async => notes)],
          child: MaterialApp(
            theme: ZadTheme.light(),
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: StaffScreen(),
            ),
          ),
        ),
      );

  testWidgets('the page shows each note with its staff member', (tester) async {
    await pump(tester, staffFeed(rows));
    await tester.pump();
    expect(find.text('كورس خلص ولسه في الصيدلية: مضاد حيوي'), findsOneWidget);
    expect(find.textContaining('الممرضة'), findsOneWidget);
    expect(find.text('نفّذ add_shopping_item'), findsNothing);
  });

  testWidgets('a quiet round says so', (tester) async {
    await pump(tester, const <StaffNote>[]);
    await tester.pump();
    expect(find.text('الفريق مالقاش حاجة تستاهل'), findsOneWidget);
  });
}
