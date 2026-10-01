/// The tab the customer was on, kept across a process death.
///
/// Back hides the app instead of closing it (4e98c054), but Android still
/// kills a backgrounded app when it needs the memory, and the next open
/// started on الرئيسية again — the owner: «عند الخروج بيرجع يحمل من أول»
/// (2026-10-01). The tab is written when the app goes to the background and
/// restored on the next start if that was within [kRestoreWithin]; after
/// that, home is the right place to start.
library;

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/app/shell/zad_bottom_nav_bar.dart';

/// How long a backgrounded tab is worth returning to.
const Duration kRestoreWithin = Duration(hours: 1);

const String _tabKey = 'shell_last_tab';
const String _atKey = 'shell_last_tab_at';

/// The tab to open with: [saved] if it was saved within [kRestoreWithin] of
/// [now] and is a real tab, else home. Pure.
ZadNavDestination restoredTab(String? saved, String? savedAt, DateTime now) {
  final at = DateTime.tryParse(savedAt ?? '');
  if (saved == null || at == null) return ZadNavDestination.home;
  if (now.difference(at) > kRestoreWithin || now.isBefore(at)) {
    return ZadNavDestination.home;
  }
  for (final d in ZadNavDestination.values) {
    if (d.name == saved) return d;
  }
  return ZadNavDestination.home;
}

/// Reads the saved tab from [box].
ZadNavDestination readLastTab(Box<String> box, DateTime now) =>
    restoredTab(box.get(_tabKey), box.get(_atKey), now);

/// Saves [tab] at [now] in [box]. Never throws.
Future<void> saveLastTab(
  Box<String> box,
  ZadNavDestination tab,
  DateTime now,
) async {
  try {
    await box.putAll(<String, String>{
      _tabKey: tab.name,
      _atKey: now.toUtc().toIso8601String(),
    });
  } on Object {
    // A tab not remembered is a start on home — never a failure.
  }
}
