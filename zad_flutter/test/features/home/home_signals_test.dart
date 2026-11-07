// ZAD_PLAN ٦.٤: what only the server's «حالة البيت» knows joins the brief —
// a medicine running out, the budget in danger before it goes below zero,
// the season ahead — each in its place, never doubling the phone's own line.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/brain/data/home_signals_controller.dart';
import 'package:zad/shared/brain/domain/daily_brief.dart';
import 'package:zad/shared/brain/domain/home_signals.dart';
import 'package:zad/shared/brain/presentation/daily_brief_lines.dart';

Map<String, dynamic> _state({
  String threat = 'SAFE',
  num? available = 900,
  List<Map<String, dynamic>> meds = const <Map<String, dynamic>>[],
  Map<String, dynamic>? ahead,
  String? now,
}) => <String, dynamic>{
  'money': <String, dynamic>{
    'threat': threat,
    'currency': 'ج.م',
    'available': available,
    'days_left': 12,
    'daily_left': 75,
  },
  'health': <String, dynamic>{'next_doses': <dynamic>[], 'medicines_low': meds},
  'season': <String, dynamic>{'now': now, 'ahead': ahead},
};

const _renewal = BriefItem(
  kind: BriefKind.renewal,
  title: 'Netflix بكرة',
  detail: '120 ج.م',
);
const _dose = BriefItem(kind: BriefKind.doseDue, title: 'جرعة', detail: '');
const _over = BriefItem(kind: BriefKind.overspent, title: 'صرفت', detail: '');

class _Session extends SessionController {
  @override
  String? build() => 'u1';
}

void main() {
  final l10n = lookupZadL10n(const Locale('ar'));

  test('malformed or missing parts are simply absent', () {
    final s = HomeSignals.fromState(const <String, dynamic>{
      'money': 'nope',
      'health': <String, dynamic>{
        'medicines_low': <dynamic>[
          <String, dynamic>{'name': ' ', 'days': 1},
          <String, dynamic>{'name': 'كونكور', 'days': 2},
          'junk',
        ],
      },
    });
    expect(s.threat, isNull);
    expect(s.medicinesLow, <LowMedicine>[(name: 'كونكور', days: 2)]);
    expect(s.seasonAhead, isNull);
  });

  test('each server line falls in beside the phone line of its weight', () {
    final merged = withHomeSignals(
      const <BriefItem>[_dose, _renewal],
      HomeSignals.fromState(
        _state(
          threat: 'DANGER',
          meds: <Map<String, dynamic>>[
            <String, dynamic>{'name': 'كونكور', 'days': 3},
          ],
          ahead: <String, dynamic>{'kind': 'ramadan', 'in_days': 18},
        ),
      ),
      l10n,
    );
    expect(merged.map((b) => b.kind), <BriefKind>[
      BriefKind.doseDue,
      BriefKind.medicineLow,
      BriefKind.budgetDanger,
      BriefKind.renewal,
      BriefKind.seasonAhead,
    ]);
    expect(merged[1].title, 'كونكور هيخلص بعد 3 يوم');
    expect(merged[2].title, 'الميزانية في خطر: باقي 75 ج.م في اليوم لـ12 يوم');
    expect(merged[4].title, 'رمضان بعد 18 يوم');
    expect(
      briefWhyText(l10n, merged[2].why!),
      startsWith('المتاح 900 ج.م على 12 يوم = 75 ج.م في اليوم'),
    );
  });

  test('«صرفت أكتر» already said it: no «في خطر» on top', () {
    final merged = withHomeSignals(
      const <BriefItem>[_over],
      HomeSignals.fromState(_state(threat: 'DANGER')),
      l10n,
    );
    expect(merged.map((b) => b.kind), <BriefKind>[BriefKind.overspent]);
  });

  test('safe, watch, or a season already here add nothing', () {
    for (final s in <Map<String, dynamic>>[
      _state(),
      _state(threat: 'WATCH'),
      _state(
        now: 'ramadan',
        ahead: <String, dynamic>{'kind': 'dhul_hijjah', 'in_days': 10},
      ),
      _state(ahead: <String, dynamic>{'kind': 'ramadan', 'in_days': 30}),
      _state(ahead: <String, dynamic>{'kind': 'school', 'in_days': 5}),
    ]) {
      expect(
        withHomeSignals(
          const <BriefItem>[_renewal],
          HomeSignals.fromState(s),
          l10n,
        ),
        <BriefItem>[_renewal],
      );
    }
    expect(
      withHomeSignals(const <BriefItem>[_renewal], null, l10n),
      <BriefItem>[_renewal],
    );
  });

  group('the cached row', () {
    late Directory dir;
    late Box<String> device;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('zad_home_signals');
      Hive.init(dir.path);
      device = await Hive.openBox<String>('device');
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    ProviderContainer container(HomeStateRead read) {
      final store = ZadLocalStore(
        outbox: device,
        transactions: device,
        documents: device,
        chat: device,
        inventory: device,
        shopping: device,
        pharmacy: device,
        subscriptions: device,
        device: device,
      );
      final c = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          sessionControllerProvider.overrideWith(_Session.new),
          homeStateReadProvider.overrideWithValue(read),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('read once, kept, and shown offline next time', () async {
      var reads = 0;
      final online = container((uid) async {
        reads++;
        return _state(threat: 'DANGER');
      });
      expect(online.read(homeSignalsControllerProvider), isNull);
      await pumpEventQueue();
      expect(online.read(homeSignalsControllerProvider)?.threat, 'DANGER');
      // Inside five minutes nothing is asked again; a pull always asks.
      await online.read(homeSignalsControllerProvider.notifier).refresh();
      expect(reads, 1);
      await online
          .read(homeSignalsControllerProvider.notifier)
          .refresh(force: true);
      expect(reads, 2);

      final offline = container((uid) async => throw Exception('offline'));
      expect(offline.read(homeSignalsControllerProvider)?.threat, 'DANGER');
      await pumpEventQueue();
      expect(offline.read(homeSignalsControllerProvider)?.threat, 'DANGER');
    });
  });
}
