/// Everything that must be true before the first frame is drawn.
library;

import 'package:flutter/widgets.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Prepares the app and hands back the widget to run.
///
/// The work here is deliberately small and deliberately synchronous-feeling:
/// it runs before `runApp`, so every millisecond is a millisecond of blank
/// screen. Only two things qualify, and both are cheap:
///
/// * the timezone database, because a budget period read without it is either
///   wrong or an exception, and
/// * the local boxes, because the first frame is supposed to draw the figures
///   we already have rather than a spinner.
///
/// `latest_all` and not `latest`: several markets this app serves resolve
/// through zone *links* — `Asia/Aden`, `Asia/Kuwait`, `Asia/Bahrain`,
/// `Asia/Muscat`, `Asia/Qatar` — and the trimmed database drops them.
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  tz_data.initializeTimeZones();
  await Hive.initFlutter();

  runApp(builder());
}
