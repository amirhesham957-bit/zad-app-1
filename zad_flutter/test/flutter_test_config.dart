// Runs before every test file under test/: wires the app's contracts the
// way `bootstrap()` does on the phone, so a test exercises the same
// connections — a queued write reaches its repository, a tap on another
// feature's row opens that feature's screen.
import 'dart:async';

import 'package:zad/app/wiring/zad_wiring.dart';
import 'package:zad/core/design/components/zad_network_image.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  wireZad();
  // The disk cache needs plugins a test host does not have.
  ZadNetworkImage.diskCache = false;
  await testMain();
}
