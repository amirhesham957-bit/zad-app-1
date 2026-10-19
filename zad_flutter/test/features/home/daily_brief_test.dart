// «موجز زاد النهارده»: the dose first, then money, then what ran out — and
// nothing at all when nothing needs the customer.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/brain/domain/daily_brief.dart';
import 'package:zad/shared/inventory/domain/consumption_rate.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/pharmacy/domain/dose_time.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';

final _today = DateTime.utc(2026, 9, 10);
final _now = DateTime.utc(2026, 9, 10, 9, 5);

DoseSlot _dose(String name, DateTime at, {DateTime? taken}) => DoseSlot(
  medicine: Medicine(id: name, userId: 'u', name: name),
  time: DoseTime.parse('${at.hour.toString().padLeft(2, '0')}:00')!,
  scheduledAt: at,
  takenAt: taken,
);

InventoryItem _item(String name, int qty) => InventoryItem(
  id: name,
  userId: 'u',
  itemName: name,
  quantity: qty,
  lowStockThreshold: 2,
);

void main() {
  test('nothing urgent is an empty brief', () {
    expect(
      dailyBrief(
        pantry: <InventoryItem>[_item('رز', 5)],
        doses: <DoseSlot>[
          _dose('بنادول', DateTime.utc(2026, 9, 10, 8), taken: _now),
        ],
        subscriptions: const <Subscription>[],
        today: _today,
        now: _now,
        spendable: 900,
      ),
      isEmpty,
    );
  });

  test('a due dose leads and carries the slot «خدتها» records', () {
    final brief = dailyBrief(
      pantry: <InventoryItem>[_item('مياه نوفا', 0), _item('ماء العين', 1)],
      doses: <DoseSlot>[
        _dose('بنادول', DateTime.utc(2026, 9, 10, 9)),
        _dose('فيتامين', DateTime.utc(2026, 9, 9, 20)),
      ],
      subscriptions: const <Subscription>[
        Subscription(
          id: 't',
          userId: 'u',
          title: 'Tabby نون',
          amount: 250,
          dueDay: 11,
        ),
      ],
      today: _today,
      now: _now,
      spendable: -120,
      currency: 'ج.م',
    );
    expect(brief.map((b) => b.kind), <BriefKind>[
      BriefKind.doseDue,
      BriefKind.dosesMissed,
      BriefKind.overspent,
      BriefKind.renewal,
      BriefKind.shortage,
    ]);
    expect(brief.first.dose?.medicine.name, 'بنادول');
    expect(brief[2].title, contains('120 ج.م'));
    expect(brief[3].title, 'قسط تابي بكرة');
    // Two brands of water are one shortage, under the staple's name.
    expect(brief[4].title, 'ناقصك مياه');
  });

  test('a renewal further than three days away waits', () {
    final brief = dailyBrief(
      pantry: const <InventoryItem>[],
      doses: const <DoseSlot>[],
      subscriptions: const <Subscription>[
        Subscription(
          id: 'n',
          userId: 'u',
          title: 'Netflix',
          amount: 120,
          dueDay: 20,
        ),
      ],
      today: _today,
      now: _now,
    );
    expect(brief, isEmpty);
  });

  test('a family-chat need is one line naming who asked, carrying the items '
      '«ضيفهم» adds', () {
    final brief = dailyBrief(
      pantry: const <InventoryItem>[],
      doses: const <DoseSlot>[],
      subscriptions: const <Subscription>[],
      today: _today,
      now: _now,
      familyNeeds: const <FamilyNeed>[
        (id: 'i1', item: 'عيش', who: 'ماما'),
        (id: 'i2', item: 'بيض', who: 'ماما'),
      ],
    );
    expect(brief.single.kind, BriefKind.familyNeed);
    expect(brief.single.title, 'من شات العيلة: عيش، بيض');
    expect(brief.single.detail, 'ماما قال إنهم ناقصين — ضيفهم لقايمة التسوق؟');
    expect(brief.single.needs.map((n) => n.id), <String>['i1', 'i2']);
  });

  test('family needs come after what is more urgent', () {
    final brief = dailyBrief(
      pantry: <InventoryItem>[_item('رز', 0)],
      doses: const <DoseSlot>[],
      subscriptions: const <Subscription>[],
      today: _today,
      now: _now,
      spendable: -50,
      familyNeeds: const <FamilyNeed>[(id: 'i1', item: 'عيش', who: null)],
    );
    expect(brief.map((b) => b.kind), <BriefKind>[
      BriefKind.overspent,
      BriefKind.shortage,
      BriefKind.familyNeed,
    ]);
    expect(brief.last.detail, 'اتقال إنهم ناقصين — ضيفهم لقايمة التسوق؟');
  });

  group('«هيخلص إمتى؟» (ZAD_PLAN ٣.٥)', () {
    List<BriefItem> brief(
      List<InventoryItem> pantry,
      Map<String, ConsumptionRate> rates,
    ) => dailyBrief(
      pantry: pantry,
      doses: const <DoseSlot>[],
      subscriptions: const <Subscription>[],
      today: _today,
      now: _now,
      rates: rates,
    );

    test('a rate turns «ناقصك» into the day it runs out, soonest first', () {
      // The owner's pantry on 2026-10-19: cheese 1 at 0.70/day, toast 1 at
      // 0.27, and water out with no rate.
      final lines = brief(
        <InventoryItem>[
          _item('توست', 1),
          _item('جبنة', 1),
          _item('مياه نوفا', 0),
        ],
        <String, ConsumptionRate>{
          'توست': (perDay: 0.27, known: false),
          ' جبنة ': (perDay: 0.70, known: true),
          'مياه نوفا': (perDay: 1.1, known: false),
        }.map((k, v) => MapEntry(rateKey(k), v)),
      );
      expect(lines.map((l) => l.kind), <BriefKind>[
        BriefKind.shortage,
        BriefKind.runningOut,
      ]);
      // Out of stock is «ناقصك», not a forecast.
      expect(lines[0].title, 'ناقصك مياه نوفا');
      expect(lines[1].title, 'هيخلص قريب: جبنة بكرة، توست حوالي بعد 3 أيام');
      expect(lines[1].detail, startsWith('تقدير'));
    });

    test('far off is not news, and no rate keeps the plain line', () {
      final lines = brief(
        <InventoryItem>[_item('رز', 5), _item('زيت', 1)],
        <String, ConsumptionRate>{'رز': (perDay: 0.5, known: true)},
      );
      expect(lines.single.kind, BriefKind.shortage);
      expect(lines.single.title, 'ناقصك زيت');
    });

    test('brands of one staple run out together, at their summed rate', () {
      final lines = brief(
        <InventoryItem>[_item('مياه نوفا', 3), _item('مياه العين', 3)],
        <String, ConsumptionRate>{
          rateKey('مياه نوفا'): (perDay: 1, known: true),
          rateKey('مياه العين'): (perDay: 1, known: true),
        },
      );
      expect(lines.single.title, 'هيخلص قريب: مياه بعد 3 أيام');
      expect(lines.single.detail, startsWith('من معدل'));
    });
  });
}
