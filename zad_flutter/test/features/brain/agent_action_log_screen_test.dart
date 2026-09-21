// What the log promises: every action in words, an undo button only where the
// server can undo, a question before anything is taken back, and the answer
// said out loud.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/brain/application/agent_actions_controller.dart';
import 'package:zad/features/brain/data/agent_actions_repository.dart';
import 'package:zad/features/brain/domain/agent_action.dart';
import 'package:zad/features/brain/presentation/agent_action_log_screen.dart';
import 'package:zad/features/brain/presentation/brain_hub_screen.dart';

class _Actions extends AgentActionsController {
  new(this.items, {this.outcome = const Undone('zad_transactions')});

  final List<AgentAction> items;
  final UndoOutcome outcome;
  final List<String> undone = <String>[];

  @override
  AgentActionsView build() => AgentActionsView(items: items);

  @override
  Future<void> refresh() async {}

  @override
  Future<UndoOutcome?> undo(AgentAction action) async {
    undone.add(action.id);
    return outcome;
  }
}

AgentAction _a(
  String id,
  String tool, {
  String status = 'applied',
  String? table = 'zad_transactions',
}) => AgentAction(
  id: id,
  toolName: tool,
  source: 'voice',
  status: status,
  createdAt: DateTime.utc(2026, 9, 21, 11),
  targetTable: table,
  targetId: 'row-$id',
  resultSummary: 'ملخص $id',
);

void main() {
  late _Actions fake;

  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });

  Future<void> pump(
    WidgetTester tester,
    List<AgentAction> items, {
    UndoOutcome outcome = const Undone('zad_transactions'),
    Widget home = const AgentActionLogScreen(),
  }) async {
    fake = _Actions(items, outcome: outcome);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentActionsControllerProvider.overrideWith(() => fake),
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 9, 21, 12)),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: Directionality(textDirection: TextDirection.rtl, child: home),
        ),
      ),
    );
  }

  testWidgets('an empty log says so', (tester) async {
    await pump(tester, <AgentAction>[]);
    expect(find.text('لسه مفيش تعديلات'), findsOneWidget);
  });

  testWidgets('each action in words, and the door it came in by', (
    tester,
  ) async {
    await pump(tester, <AgentAction>[_a('1', 'add_obligation')]);

    expect(find.text('تسجيل التزام'), findsOneWidget);
    expect(find.textContaining('رسالة صوتية'), findsOneWidget);
    expect(find.text('ملخص 1'), findsOneWidget);
    expect(find.textContaining('add_obligation'), findsNothing);
  });

  testWidgets('undo only where the server can undo', (tester) async {
    await pump(tester, <AgentAction>[
      _a('1', 'log_transaction'),
      _a('2', 'add_appointment', table: 'zad_appointments'),
      _a('3', 'log_transaction', status: 'undone'),
    ]);

    expect(find.text('ارجع فيه'), findsOneWidget);
    expect(find.text('اترجع فيه'), findsOneWidget);
  });

  testWidgets('an undo is asked first, and "wait" does nothing', (
    tester,
  ) async {
    await pump(tester, <AgentAction>[_a('1', 'log_transaction')]);

    await tester.tap(find.text('ارجع فيه'));
    await tester.pumpAndSettle();
    expect(find.text('ترجع في «تسجيل معاملة»؟'), findsOneWidget);

    await tester.tap(find.text('استنى'));
    await tester.pumpAndSettle();
    expect(fake.undone, isEmpty);
  });

  testWidgets('a confirmed undo is sent and its result said', (tester) async {
    await pump(tester, <AgentAction>[_a('1', 'log_transaction')]);

    await tester.tap(find.text('ارجع فيه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ارجع فيه').last);
    await tester.pumpAndSettle();

    expect(fake.undone, <String>['1']);
    expect(find.text('رجعت في «تسجيل معاملة»'), findsOneWidget);
  });

  testWidgets('a refusal is said in words', (tester) async {
    await pump(tester, <AgentAction>[
      _a('1', 'log_transaction'),
    ], outcome: const UndoRefused(UndoFailure.newerActionExists));

    await tester.tap(find.text('ارجع فيه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ارجع فيه').last);
    await tester.pumpAndSettle();

    expect(find.text(UndoFailure.newerActionExists.message), findsOneWidget);
  });

  testWidgets('the hub opens the log', (tester) async {
    await pump(tester, <AgentAction>[], home: const BrainHubScreen());

    await tester.tap(find.text('سجل تعديلات زاد'));
    await tester.pumpAndSettle();
    expect(find.text('لسه مفيش تعديلات'), findsOneWidget);
  });
}
