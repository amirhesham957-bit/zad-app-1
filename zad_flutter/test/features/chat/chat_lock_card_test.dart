// When the attempts run out, the chat reply carries its way out (ZAD_PLAN
// ٢.٨): the server's `entitlement` block becomes a card under the reply with
// the ad, the time the attempts come back, and the plans.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/chat/domain/agent_turn.dart';
import 'package:zad/shared/chat/domain/chat_message.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

final _now = DateTime.utc(2026, 10, 19, 9);

Map<String, dynamic> _refused(String reason, {String? resetAt}) =>
    <String, dynamic>{
      'ok': true,
      'reply': '🔒 خلص رصيد محاولاتك دلوقتي.',
      'entitlement': <String, dynamic>{
        'allowed': false,
        'reason': reason,
        'cost': 1,
        'left': 0,
        'cycle_reset_at': ?resetAt,
      },
    };

Future<void> _pump(WidgetTester tester, AgentLock lock) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nowProvider.overrideWithValue(() => _now),
        // The ad button's own providers are its own test's business.
        adsAllowedProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: ChatLockCard(lock: lock)),
        ),
      ),
    ),
  );
}

void main() {
  test('a refused turn carries its lock; an answered one carries none', () {
    final refused = AgentTurn.fromJson(
      _refused('insufficient', resetAt: '2026-10-19T11:10:00Z'),
    );
    expect(refused.lock?.reason, 'insufficient');
    expect(refused.lock?.refillAt, DateTime.utc(2026, 10, 19, 11, 10));
    expect(refused.lock?.adCanHelp, isTrue);

    final answered = AgentTurn.fromJson(<String, dynamic>{
      'reply': 'تمام',
      'entitlement': <String, dynamic>{'allowed': true, 'reason': 'ok'},
    });
    expect(answered.lock, isNull);
    expect(AgentTurn.fromJson(<String, dynamic>{'reply': 'x'}).lock, isNull);
  });

  test('a paid month or a premium feature is not bought back by an ad', () {
    expect(
      AgentLock.fromJson(_refused('quota_exhausted')['entitlement'])!.adCanHelp,
      isFalse,
    );
    expect(
      AgentLock.fromJson(_refused('premium_only')['entitlement'])!.adCanHelp,
      isFalse,
    );
  });

  test('the lock survives the chat cache', () {
    final message = ChatMessage(
      id: 'm1',
      text: 'خلص رصيدك',
      isUser: false,
      createdAt: _now,
      lock: AgentLock(reason: 'insufficient', refillAt: _now),
    );
    final back = ChatMessage.fromJson(message.toJson());
    expect(back.lock?.reason, 'insufficient');
    expect(back.lock?.refillAt, _now);
    final plain = ChatMessage.fromJson(
      ChatMessage(id: 'm2', text: 'x', isUser: false, createdAt: _now).toJson(),
    );
    expect(plain.lock, isNull);
  });

  test('the refill is said as a span of time', () {
    expect(
      refillPhrase(_now.add(const Duration(hours: 2, minutes: 10)), _now),
      'رصيدك بيتجدد بعد ساعتين و10 دقيقة',
    );
    expect(
      refillPhrase(_now.add(const Duration(minutes: 40)), _now),
      'رصيدك بيتجدد بعد 40 دقيقة',
    );
    expect(
      refillPhrase(_now.add(const Duration(hours: 1)), _now),
      'رصيدك بيتجدد بعد ساعة',
    );
    expect(
      refillPhrase(_now.add(const Duration(days: 9)), _now),
      'رصيدك بيتجدد بعد 9 أيام',
    );
    expect(refillPhrase(_now, _now), 'رصيدك رجع — ابعت رسالتك تاني');
  });

  testWidgets(
    'the card offers the refill time and the plans, and the plans open',
    (tester) async {
      var plans = 0;
      ZadScreens.showPaywallScreen = (_) async => plans++;
      await _pump(
        tester,
        AgentLock(
          reason: 'insufficient',
          refillAt: _now.add(const Duration(minutes: 40)),
        ),
      );
      expect(find.text('رصيدك بيتجدد بعد 40 دقيقة'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-lock-subscribe')),
      );
      expect(plans, 1);
    },
  );

  testWidgets('once the attempts are back, the card is gone', (tester) async {
    await _pump(
      tester,
      AgentLock(
        reason: 'insufficient',
        refillAt: _now.subtract(const Duration(minutes: 1)),
      ),
    );
    expect(find.byKey(const ValueKey<String>('chat-lock')), findsNothing);
  });

  testWidgets('a premium-only refusal asks to subscribe for the feature', (
    tester,
  ) async {
    await _pump(tester, const AgentLock(reason: 'premium_only'));
    expect(find.text('اشترك وفعّل الميزة دي'), findsOneWidget);
  });
}
