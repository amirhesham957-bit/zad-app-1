// The home greets the customer by the name they asked for in «أناديك بإيه؟»,
// not the sign-up name (emulator, 2026-11-12: «أهلاً يا SaudiTest» for an
// account that asked to be called something else).

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/profile/application/call_name.dart';

void main() {
  test('the chosen name wins over the account name', () {
    expect(callNameFrom(preferred: 'أبو فهد', account: 'SaudiTest'), 'أبو فهد');
  });

  test('a blank choice falls back to the account name', () {
    expect(callNameFrom(preferred: '  ', account: ' سارة '), 'سارة');
    expect(callNameFrom(account: 'سارة'), 'سارة');
  });

  test('nothing known is null, so the header shows its placeholder', () {
    expect(callNameFrom(), isNull);
    expect(callNameFrom(preferred: '', account: ''), isNull);
  });
}
