// BNPL is its own thing, per market: valU in Egypt, Tabby and Tamara in the
// Gulf — not a car loan filed under «أقساط» for everybody (2026-09-30).

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/subscriptions/domain/bnpl.dart';

void main() {
  test('each market is offered its own companies', () {
    final eg = bnplProvidersFor('EG').map((p) => p.provider);
    expect(eg, containsAll(<String>['valU', 'Sympl', 'Souhoola']));
    expect(eg, isNot(contains('Tamara')));
    final sa = bnplProvidersFor('sa').map((p) => p.provider);
    expect(sa, containsAll(<String>['Tabby', 'Tamara']));
    expect(sa, isNot(contains('valU')));
    expect(bnplProvidersFor(null).map((p) => p.provider), <String>[
      'Tabby',
      'Tamara',
    ]);
  });

  test('a row is BNPL by its title or provider, in either script', () {
    expect(bnplProviderOf('قسط تابي')?.provider, 'Tabby');
    expect(bnplProviderOf('Phone', 'valU')?.provider, 'valU');
    expect(bnplProviderOf('فاليو - موبايل')?.provider, 'valU');
    expect(bnplProviderOf('TAMARA order #12')?.provider, 'Tamara');
  });

  test('whole words only', () {
    expect(bnplProviderOf('أمانة جدة'), isNull);
    expect(bnplProviderOf('Kamani store'), isNull);
    expect(bnplProviderOf('قسط العربية'), isNull);
    expect(bnplProviderOf('أمان')?.provider, 'aman');
  });
}
