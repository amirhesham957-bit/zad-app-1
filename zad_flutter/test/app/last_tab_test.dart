// The tab the customer was on survives Android killing the backgrounded app
// (owner, 2026-10-01: «عند الخروج بيرجع يحمل من أول»).

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/app/shell/last_tab.dart';
import 'package:zad/app/shell/zad_bottom_nav_bar.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1, 12);

  test('back within the hour: the same tab', () {
    expect(
      restoredTab('inventory', '2026-10-01T11:30:00Z', now),
      ZadNavDestination.inventory,
    );
  });

  test('later, nothing saved, a stranger value or a clock gone back: home', () {
    expect(
      restoredTab('inventory', '2026-10-01T10:30:00Z', now),
      ZadNavDestination.home,
    );
    expect(restoredTab(null, null, now), ZadNavDestination.home);
    expect(
      restoredTab('settings', '2026-10-01T11:59:00Z', now),
      ZadNavDestination.home,
    );
    expect(
      restoredTab('money', '2026-10-01T13:00:00Z', now),
      ZadNavDestination.home,
    );
  });
}
