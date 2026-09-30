// «موجز زاد النهارده»: the dose first, then money, then what ran out — and
// nothing at all when nothing needs the customer.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/home/domain/daily_brief.dart';
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
}
