// حارس الطوارئ المنزلية (الشريحة ٤٣): الكلمات اللي بتفتح الفنيين، والترتيب.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/maintenance/presentation/trusted_technicians_sheet.dart';
import 'package:zad/shared/household/domain/home_emergency.dart';

void main() {
  test('each home emergency calls for its trade', () {
    const cases = <String, TechnicianTrade>{
      'الحقني المية بتنزل من السقف': TechnicianTrade.plumber,
      'الحمام غرق': TechnicianTrade.plumber,
      'البلاعة طفحت في المطبخ': TechnicianTrade.plumber,
      'فيه ماس كهربا في الصالة': TechnicianTrade.electrician,
      'الكهربا قطعت في نص البيت بس': TechnicianTrade.electrician,
      'السكينة نزلت ومش راضية تطلع': TechnicianTrade.electrician,
      'فيه ريحة غاز في المطبخ': TechnicianTrade.gas,
      'الباب اتقفل والمفتاح جوه': TechnicianTrade.locksmith,
      'نسيت المفتاح': TechnicianTrade.locksmith,
      'التكييف مش بيبرد خالص': TechnicianTrade.ac,
      'التلاجة فاصلة من امبارح': TechnicianTrade.appliances,
    };
    cases.forEach((message, trade) {
      expect(homeEmergencyTrade(message), trade, reason: message);
    });
  });

  test('gas wins when a message names two', () {
    expect(homeEmergencyTrade('ريحة غاز والكهربا قطعت'), TechnicianTrade.gas);
  });

  test('ordinary words about water, gas and power are not emergencies', () {
    for (final m in <String>[
      'اشتري ميه معدنية',
      'الغاز خلص هشتري أنبوبة',
      'فاتورة الكهربا جت ٤٥٠',
      'دفعت المية',
      'عايز تكييف جديد',
    ]) {
      expect(homeEmergencyTrade(m), isNull, reason: m);
    }
  });

  test('the phone rule matches the table', () {
    for (final ok in <String>['01001234567', '+20 100 123 4567', '2-345-678']) {
      expect(kTechnicianPhone.hasMatch(ok), isTrue, reason: ok);
    }
    for (final bad in <String>['اتصل بيا', '123', '+', '0100abc4567']) {
      expect(kTechnicianPhone.hasMatch(bad), isFalse, reason: bad);
    }
  });

  test('the emergency trade comes first, the rest keep their order', () {
    TrustedTechnician t(String id, TechnicianTrade trade) =>
        (id: id, name: id, trade: trade, phone: '01001234567', notes: '');
    final all = <TrustedTechnician>[
      t('a', TechnicianTrade.electrician),
      t('b', TechnicianTrade.plumber),
      t('c', TechnicianTrade.ac),
      t('d', TechnicianTrade.plumber),
    ];
    expect(
      technicianOrder(all, TechnicianTrade.plumber).map((x) => x.id),
      <String>['b', 'd', 'a', 'c'],
    );
    expect(technicianOrder(all, null).map((x) => x.id), <String>[
      'a',
      'b',
      'c',
      'd',
    ]);
  });
}
