import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/bootstrap.dart';
import 'package:zad/app/zad_app.dart';

Future<void> main() async {
  await bootstrap(() => const ProviderScope(child: ZadApp()));
}
