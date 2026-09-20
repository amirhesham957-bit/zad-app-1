// The platform boundary, pinned from both sides.
//
// Everything above this package is already covered: `notification_drain_test`
// fakes `ZadBankListener` at the class boundary and proves the app decides
// correctly. What no test reached was the boundary itself — the method-name
// strings, the argument maps, and the column names `peek` decodes. Those are
// strings on one side and strings in Kotlin on the other, so a rename is not a
// compile error anywhere. It is a channel that answers `MissingPluginException`
// on a real phone while every test on the machine passes.
//
// That is this project's recurring failure: a mechanism built in full with one
// call site quietly missing it. So there are two halves here. The first mocks
// the channel and holds the Dart side to the exact wire shape. The second
// reads `ZadBankListenerPlugin.kt` and `CapturedNotificationStore.kt` and
// fails if the Kotlin has stopped answering to those names — a parity test in
// the same spirit as the ones guarding `SaBankParser`.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad_bank_listener/zad_bank_listener.dart';

/// A fixed capture instant: 2026-09-19T17:20:00Z, as epoch milliseconds.
///
/// `StatusBarNotification.postTime` is milliseconds, and it is an instant —
/// not a wall-clock reading in anybody's zone.
const int _postedAtMillis = 1758300000000;

/// One row shaped exactly as `CapturedNotificationStore.peek` emits it.
Map<String, Object> _row({
  int id = 1,
  String packageName = 'com.google.android.apps.messaging',
  String title = 'الأهلي',
  String text = 'شراء بمبلغ 250.00 ج.م',
  int postedAt = _postedAtMillis,
}) => <String, Object>{
  'id': id,
  'package_name': packageName,
  'title': title,
  'text': text,
  'posted_at': postedAt,
};

/// The package's own directory, whether the suite was started from here or
/// from the app root above it.
Directory _packageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zad_bank_listener')) {
      return dir;
    }
    final nested = Directory('${dir.path}/packages/zad_bank_listener');
    if (File('${nested.path}/pubspec.yaml').existsSync()) return nested;
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  throw StateError('could not locate the zad_bank_listener package root');
}

String _kotlin(String name) => File(
  '${_packageRoot().path}/android/src/main/kotlin/com/aistudio/zad/'
  'banklistener/$name',
).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const listener = ZadBankListener();
  late List<MethodCall> calls;
  Object? answer;

  setUp(() {
    calls = <MethodCall>[];
    answer = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ZadBankListener.channel, (call) async {
          calls.add(call);
          return answer;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ZadBankListener.channel, null);
  });

  group('the wire shape', () {
    test('the channel name is the one the plugin registers', () {
      expect(ZadBankListener.channel.name, 'com.aistudio.zad/bank_listener');
    });

    test('isPermissionGranted asks by name and takes the answer', () async {
      answer = true;
      expect(await listener.isPermissionGranted(), isTrue);
      expect(calls.single.method, 'isPermissionGranted');
      expect(calls.single.arguments, isNull);
    });

    test('openPermissionSettings asks by name', () async {
      await listener.openPermissionSettings();
      expect(calls.single.method, 'openPermissionSettings');
    });

    test('requestRebind asks by name', () async {
      answer = true;
      expect(await listener.requestRebind(), isTrue);
      expect(calls.single.method, 'requestRebind');
    });

    test('peek sends the limit the Kotlin reads', () async {
      answer = <Object>[_row()];
      final rows = await listener.peek(limit: 25);

      expect(calls.single.method, 'peek');
      expect(calls.single.arguments, <String, Object>{'limit': 25});
      expect(rows.single.id, 1);
    });

    test('acknowledge sends a plain list under "ids"', () async {
      await listener.acknowledge(<int>{7, 9});

      expect(calls.single.method, 'acknowledge');
      // A Set would not survive the codec as a list, and the Kotlin reads
      // `call.argument<List<Number>>("ids")`. This is the assertion that
      // catches somebody passing the iterable straight through.
      expect(calls.single.arguments, <String, Object>{
        'ids': <int>[7, 9],
      });
    });

    test('pendingCount asks by name', () async {
      answer = 4;
      expect(await listener.pendingCount(), 4);
      expect(calls.single.method, 'pendingCount');
    });
  });

  group('a platform that answers null', () {
    // Every one of these has a real cause: an older build of the plugin, a
    // method that returned before setting a result, a host that registered no
    // plugin at all. None of them should throw on a null in a screen.
    test('reads as not granted, not rebound, nothing pending, no rows',
        () async {
      expect(await listener.isPermissionGranted(), isFalse);
      expect(await listener.requestRebind(), isFalse);
      expect(await listener.pendingCount(), 0);
      expect(await listener.peek(), isEmpty);
    });
  });

  group('decoding a captured row', () {
    test('reads the column names the store actually emits', () {
      final row = CapturedNotification.fromMap(_row());

      expect(row.id, 1);
      expect(row.packageName, 'com.google.android.apps.messaging');
      expect(row.title, 'الأهلي');
      expect(row.text, 'شراء بمبلغ 250.00 ج.م');
    });

    test('postedAt is UTC, not the device zone', () {
      // `postTime` is epoch milliseconds. Decoding it as local time would shift
      // every captured notification by the phone's offset — three hours, in the
      // markets this app serves — and the transactions list groups by day.
      final row = CapturedNotification.fromMap(_row());

      expect(row.postedAt.isUtc, isTrue);
      expect(row.postedAt.millisecondsSinceEpoch, _postedAtMillis);
    });
  });

  group('parity with the Kotlin', () {
    test('the plugin answers to every method Dart invokes', () {
      final source = _kotlin('ZadBankListenerPlugin.kt');

      for (final method in <String>[
        'isPermissionGranted',
        'openPermissionSettings',
        'requestRebind',
        'peek',
        'acknowledge',
        'pendingCount',
      ]) {
        expect(
          source,
          contains('"$method" ->'),
          reason:
              'ZadBankListenerPlugin.kt has no branch for "$method", so the '
              'call would come back as notImplemented on a device.',
        );
      }
    });

    test('the plugin registers the channel name Dart opens', () {
      expect(
        _kotlin('ZadBankListenerPlugin.kt'),
        contains('const val CHANNEL = "${ZadBankListener.channel.name}"'),
      );
    });

    test('the plugin reads the argument keys Dart sends', () {
      final source = _kotlin('ZadBankListenerPlugin.kt');

      expect(source, contains('call.argument<Int>("limit")'));
      expect(source, contains('call.argument<List<Number>>("ids")'));
    });

    test('the store emits the column names fromMap reads', () {
      final source = _kotlin('CapturedNotificationStore.kt');

      for (final column in <String>[
        'id',
        'package_name',
        'title',
        'text',
        'posted_at',
      ]) {
        expect(
          source,
          contains('"$column" to'),
          reason:
              'CapturedNotificationStore.peek no longer emits "$column", '
              'which CapturedNotification.fromMap reads with a non-null '
              'assertion — so a peek would throw rather than degrade.',
        );
      }
    });

    test('the store is a single instance per process', () {
      // Two SQLiteOpenHelper instances on one file are two connections, and
      // the lock that serialises writes is per instance. The service inserts
      // while the plugin drains, so the collision is the ordinary case, not a
      // rare one — and the service swallows the exception, losing the message.
      final source = _kotlin('CapturedNotificationStore.kt');

      expect(source, contains('private constructor'));
      expect(source, contains('fun get(context: Context)'));

      for (final caller in <String>[
        'ZadNotificationListenerService.kt',
        'ZadBankListenerPlugin.kt',
      ]) {
        expect(
          _kotlin(caller),
          contains('CapturedNotificationStore.get('),
          reason: '$caller must not construct its own store.',
        );
      }
    });
  });
}
