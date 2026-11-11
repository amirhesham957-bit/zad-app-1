// Same wiring as test/flutter_test_config.dart, for the renders in tool/screens.
import 'dart:async';

import 'package:zad/app/wiring/zad_wiring.dart';
import 'package:zad/core/design/components/zad_network_image.dart';
import 'package:zad/shared/inventory/presentation/item_photo.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  wireZad();
  ZadNetworkImage.diskCache = false;
  ZadItemPhoto.loops = false;
  await testMain();
}
