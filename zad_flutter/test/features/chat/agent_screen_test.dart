// The agent's app_command, end to end on the client: every screen the server
// lets the model name opens something here, and the response is read the way
// zad-brain writes it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/chat/domain/agent_screen.dart';
import 'package:zad/shared/chat/domain/agent_turn.dart';

/// `APP_COMMAND_SCREENS` as zad-brain's validators.ts declares it.
List<String> _serverScreens() {
  final src = File('../supabase/functions/zad-brain/validators.ts')
      .readAsStringSync();
  final body = RegExp(
    r'APP_COMMAND_SCREENS = \[(.*?)\] as const',
    dotAll: true,
  ).firstMatch(src)!.group(1)!;
  final withoutComments = body.replaceAll(RegExp('//[^\n]*'), '');
  return RegExp('"([a-z_]+)"')
      .allMatches(withoutComments)
      .map((m) => m.group(1)!)
      .toList();
}

void main() {
  test('every screen the server accepts opens something here', () {
    final server = _serverScreens();
    expect(server, isNotEmpty);
    for (final s in server) {
      expect(AgentScreen.fromWire(s), isNotNull, reason: s);
    }
  });

  test('and every screen here is one the server accepts', () {
    final server = _serverScreens().toSet();
    for (final s in AgentScreen.values) {
      expect(server, contains(s.wireName), reason: s.name);
    }
  });

  test('wire names are unique', () {
    final names = AgentScreen.values.map((s) => s.wireName).toList();
    expect(names.toSet(), hasLength(names.length));
  });

  group('AgentTurn.fromJson reads app_commands', () {
    test('screen, action and highlight', () {
      final turn = AgentTurn.fromJson(<String, dynamic>{
        'reply': 'تمام',
        'app_commands': <Object?>[
          <String, dynamic>{
            'screen': 'shopping',
            'action': 'add_item',
            'highlight_name': ' لبن ',
          },
          <String, dynamic>{
            'screen': 'camera_receipt',
            'action': 'open',
            'highlight_name': null,
          },
        ],
      });
      expect(turn.appCommands, hasLength(2));
      expect(turn.appCommands[0].screen, AgentScreen.shopping);
      expect(turn.appCommands[0].action, AgentScreenAction.addItem);
      expect(turn.appCommands[0].highlightName, 'لبن');
      expect(turn.appCommands[1].screen, AgentScreen.cameraReceipt);
      expect(turn.appCommands[1].highlightName, isNull);
    });

    test('an unknown screen is dropped, an unknown action is an open', () {
      final turn = AgentTurn.fromJson(<String, dynamic>{
        'reply': 'تمام',
        'app_commands': <Object?>[
          <String, dynamic>{'screen': 'moon', 'action': 'open'},
          <String, dynamic>{'screen': 'debts', 'action': 'dance'},
          'garbage',
        ],
      });
      expect(turn.appCommands, hasLength(1));
      expect(turn.appCommands.single.screen, AgentScreen.debts);
      expect(turn.appCommands.single.action, AgentScreenAction.open);
    });

    test('absent means none', () {
      final turn = AgentTurn.fromJson(<String, dynamic>{'reply': 'تمام'});
      expect(turn.appCommands, isEmpty);
    });
  });

  group('a turn that changed the household refreshes its screens', () {
    AgentTurn turn(String tool, {bool ok = true}) => AgentTurn(
      reply: 'تمام',
      executed: <AgentExecuted>[
        AgentExecuted(tool: tool, summary: 'تم', ok: ok),
      ],
    );

    test('pantry, shopping, pharmacy and subscription tools', () {
      for (final tool in <String>[
        'add_inventory_item',
        'update_inventory_qty',
        'add_shopping_item',
        'complete_shopping_item',
        'add_pharmacy_item',
        'log_pharmacy_dose',
        'add_subscription',
      ]) {
        expect(turn(tool).touchedHousehold, isTrue, reason: tool);
      }
    });

    test('not money, not a failed write', () {
      expect(turn('log_transaction').touchedHousehold, isFalse);
      expect(turn('add_inventory_item', ok: false).touchedHousehold, isFalse);
      expect(turn('remember').touchedHousehold, isFalse);
    });
  });
}
