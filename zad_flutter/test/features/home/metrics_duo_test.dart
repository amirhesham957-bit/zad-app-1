import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/home/presentation/metrics_duo.dart';

void main() {
  test('the safe daily spend spreads what is spendable over the days left', () {
    expect(safeDailySpend(spendable: 3000, daysLeft: 10), 300);
  });

  test("on the last day all of it is today's", () {
    // Kotlin's rule: no division by zero, the whole figure instead.
    expect(safeDailySpend(spendable: 450, daysLeft: 0), 450);
  });
}
