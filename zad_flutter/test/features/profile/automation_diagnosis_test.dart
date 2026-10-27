import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/profile/domain/automation_diagnosis.dart';

void main() {
  final now = DateTime(2026, 10, 28, 12);
  const working = PhoneBank(
    granted: true,
    connected: true,
    lastSeenAnyAt: null,
    pending: 0,
  );
  PhoneBank phone({
    bool granted = true,
    bool connected = true,
    Duration seenAgo = const Duration(minutes: 5),
    int pending = 0,
  }) => PhoneBank(
    granted: granted,
    connected: connected,
    lastSeenAnyAt: now.subtract(seenAgo),
    pending: pending,
  );
  IngestRow row(String status, {String? reason, String? txn}) =>
      IngestRow(at: now, status: status, reason: reason, transactionId: txn);

  group('bank chain: the first broken link, in order', () {
    test('the phone links come before anything on the server', () {
      expect(bankBreak(phone(granted: false), [], now), BankBreak.noAccess);
      expect(
        bankBreak(phone(connected: false), [], now),
        BankBreak.serviceNotBound,
      );
      expect(bankBreak(working, [], now), BankBreak.serviceSilent);
      expect(
        bankBreak(phone(seenAgo: const Duration(days: 3)), [], now),
        BankBreak.serviceSilent,
      );
      expect(bankBreak(phone(pending: 2), [], now), BankBreak.stuckOnPhone);
    });

    test('then what the server did with what arrived', () {
      expect(bankBreak(phone(), [], now), BankBreak.nothingReachedServer);
      // 2026-10-27's live health: four arrived, all judged adverts.
      final ads = List.filled(
        4,
        row('ignored', reason: 'gate:promo_or_ad:1.00'),
      );
      expect(bankBreak(phone(), ads, now), BankBreak.allSetAside);
      expect(
        bankBreak(phone(), [...ads, row('awaiting_confirmation')], now),
        BankBreak.waitingForYou,
      );
      expect(
        bankBreak(phone(), [...ads, row('processed', txn: 't1')], now),
        BankBreak.none,
      );
    });
  });

  group('proactive chain', () {
    MomentRow m(String status, {String? error}) => MomentRow(
      at: now,
      moment: 'morning_greeting',
      status: status,
      error: error,
    );

    test('no Telegram and no push token is the first break', () {
      expect(
        proactiveBreak(
          telegramLinked: false,
          hasPushToken: false,
          moments: [m('sent')],
        ),
        ProactiveBreak.noChannel,
      );
    });

    test('then nothing queued, then mostly failing', () {
      expect(
        proactiveBreak(telegramLinked: true, hasPushToken: false, moments: []),
        ProactiveBreak.nothingQueued,
      );
      expect(
        proactiveBreak(
          telegramLinked: false,
          hasPushToken: true,
          moments: [m('failed'), m('failed'), m('sent')],
        ),
        ProactiveBreak.failing,
      );
      expect(
        proactiveBreak(
          telegramLinked: true,
          hasPushToken: true,
          moments: [m('sent'), m('failed')],
        ),
        ProactiveBreak.none,
      );
    });
  });

  test('every server reason is named, in the server order', () {
    expect(
      ingestReason(row('ignored', reason: 'gate:promo_or_ad:1.00')),
      IngestReason.promo,
    );
    final odd = row('ignored', reason: 'gate:bill_reminder:0.90');
    expect(ingestReason(odd), IngestReason.otherKind);
    expect(ingestKind(odd), 'bill_reminder');
    expect(
      ingestReason(row('ignored', reason: 'informational_only')),
      IngestReason.informational,
    );
    expect(
      ingestReason(row('ambiguous', reason: 'needs_confirmation')),
      IngestReason.waiting,
    );
    expect(
      ingestReason(row('received', reason: 'proposal_insert_failed')),
      IngestReason.serverError,
    );
    expect(
      ingestReason(row('ignored', reason: 'merged_cross_channel:x')),
      IngestReason.merged,
    );
    expect(ingestReason(row('processed', txn: 't')), IngestReason.recorded);
    expect(ingestReason(row('received')), IngestReason.reviewing);
    expect(
      momentOutcome(
        MomentRow(
          at: now,
          moment: 'good_night',
          status: 'failed',
          error: 'no channel (not composed)',
        ),
      ),
      MomentOutcome.noChannel,
    );
    expect(
      momentOutcome(MomentRow(at: now, moment: 'x', status: 'skipped')),
      MomentOutcome.skipped,
    );
  });
}
