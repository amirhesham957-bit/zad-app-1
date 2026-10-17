// The bank message corpus (ZAD_DREAM_PLAN.md ح١) on the phone's side of the
// channel. The same file is read by the server's gate test, so a message added
// there for Egypt or Saudi is checked here too.
//
// What the phone owes the server: every message where money moved reaches it,
// with the right amount; codes and declined payments never leave the phone.
// Ads may still reach it — the server's gate is what rejects those.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/bank/domain/bank_notification.dart';
import 'package:zad/shared/bank/domain/tracked_financial_apps.dart';

List<Map<String, dynamic>> _corpus() {
  final file = File(
    '../supabase/functions/zad-brain/testdata/bank_corpus.json',
  );
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return (json['cases'] as List).cast<Map<String, dynamic>>();
}

bool _sent(Map<String, dynamic> c) {
  final verdict = classifyBankNotification(
    title: c['title'] as String,
    text: c['text'] as String,
  );
  return shouldSendToBrain(
    classification: verdict.classification,
    reason: verdict.reason,
    isTrackedFinancialApp: isTrackedFinancialApp(c['package'] as String),
  );
}

void main() {
  final corpus = _corpus();

  test('the corpus has Egypt and Saudi, money and noise', () {
    final markets = corpus.map((c) => c['market']).toSet();
    expect(markets, containsAll(<String>['EG', 'SA']));
    expect(corpus.where((c) => c['expect'] == 'money'), isNotEmpty);
    expect(corpus.where((c) => c['expect'] == 'ignore'), isNotEmpty);
  });

  test('every message where money moved reaches the server', () {
    final dropped = [
      for (final c in corpus)
        if (c['expect'] == 'money' && !_sent(c)) c['id'],
    ];
    expect(dropped, isEmpty);
  });

  test('every reminder reaches the server, which turns it into a reminder', () {
    final dropped = [
      for (final c in corpus)
        if (c['expect'] == 'reminder' && !_sent(c)) c['id'],
    ];
    expect(dropped, isEmpty);
  });

  test('the amount read from the message is the amount that moved', () {
    final wrong = <String>[];
    for (final c in corpus) {
      final want = c['amount'] as num?;
      if (want == null) continue;
      final got = classifyBankNotification(
        title: c['title'] as String,
        text: c['text'] as String,
      ).amount;
      if (got != want.toDouble()) wrong.add('${c['id']}: got $got, want $want');
    }
    expect(wrong, isEmpty);
  });

  test('verification codes never leave the phone', () {
    final leaked = [
      for (final c in corpus)
        if ((c['id'] as String).endsWith('-otp') && _sent(c)) c['id'],
    ];
    expect(leaked, isEmpty);
  });

  test('a declined payment reaches the server only as a failed one', () {
    // Sent on purpose (Kotlin parity): the server records why, it never
    // proposes a transaction from it.
    final wrong = [
      for (final c in corpus)
        if ((c['id'] as String).endsWith('-declined') &&
            classifyBankNotification(
                  title: c['title'] as String,
                  text: c['text'] as String,
                ).classification !=
                BankNotificationClass.failedOrPendingTransaction)
          c['id'],
    ];
    expect(wrong, isEmpty);
  });
}
