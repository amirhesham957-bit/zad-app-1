// Crowd prices on the phone. Pinned: a report is checked against the server's
// own bounds before it is queued, so the queue never holds one the server will
// refuse; it is queued under the id the server records, so a replay is not a
// second vote; a refusal with a reason is a dead letter the customer is shown,
// while "too many this hour" waits; and the list is read in the account's
// currency.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/prices/application/prices_controller.dart';
import 'package:zad/features/prices/data/prices_remote.dart';
import 'package:zad/features/prices/data/prices_repository.dart';
import 'package:zad/features/prices/domain/prices.dart';
import 'package:zad/features/settings/data/settings_repository.dart';

class _Server implements PricesRemote {
  final List<Map<String, Object?>> reports = <Map<String, Object?>>[];
  final List<(String, String?)> cheapestAsked = <(String, String?)>[];
  Map<String, dynamic> answer = <String, dynamic>{'ok': true, 'id': 1};
  List<Object?> rows = <Object?>[
    <String, dynamic>{
      'item_name': 'طماطم',
      'min_price': 10,
      'avg_price': 11.5,
      'reports': 3,
      'cheapest_location': 'القاهرة',
      'cheapest_store': 'كارفور',
      'last_reported': '2026-09-21T10:00:00Z',
    },
    <String, dynamic>{'item_name': '', 'min_price': 5},
    <String, dynamic>{'item_name': 'لبن', 'min_price': 0},
  ];
  Exception? failWith;

  @override
  Future<Map<String, dynamic>> report({
    required String reportId,
    required String item,
    required double price,
    String? currency,
    String? city,
    String? store,
  }) async {
    if (failWith case final e?) throw e;
    reports.add(<String, Object?>{
      'id': reportId,
      'item': item,
      'price': price,
      'currency': currency,
      'city': city,
      'store': store,
    });
    return answer;
  }

  @override
  Future<List<Object?>> cheapest({
    required String currency,
    String? city,
  }) async {
    if (failWith case final e?) throw e;
    cheapestAsked.add((currency, city));
    return rows;
  }

  @override
  Future<List<Object?>> leaderboard({required String currency}) async =>
      <Object?>[
        <String, dynamic>{'rank': 1, 'reports': 9, 'is_me': false},
        <String, dynamic>{'rank': 2, 'reports': 4, 'is_me': true},
      ];
}

class _NoSettings implements SettingsRemote {
  @override
  Future<Map<String, dynamic>?> fetch({required String userId}) async => null;

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;
}

void main() {
  group('what a report may say', () {
    test("the server's bounds, before anything is queued", () {
      ReportProblem? check(String item, double? price, {String? store}) =>
          checkReport(item: item, price: price, store: store);

      expect(check('طماطم', 12), isNull);
      expect(check(' ط ', 12), ReportProblem.itemTooShort);
      expect(check('ط' * 61, 12), ReportProblem.itemTooLong);
      expect(check('طماطم', null), ReportProblem.noPrice);
      expect(check('طماطم', 0), ReportProblem.noPrice);
      expect(check('طماطم', 1000001), ReportProblem.priceTooHigh);
      expect(check('طماطم', 12, store: 'م' * 61), ReportProblem.storeTooLong);
    });

    test('a row with no name or no price is not shown', () {
      expect(CheapestPrice.fromJson(<String, dynamic>{'min_price': 5}), isNull);
      expect(
        CheapestPrice.fromJson(<String, dynamic>{
          'item_name': 'لبن',
          'min_price': 0,
        }),
        isNull,
      );
    });
  });

  group('on the phone', () {
    late Directory dir;
    late Box<String> documents;
    late Box<String> outboxBox;
    late _Server server;
    late Outbox outbox;
    late PricesRepository prices;
    var ids = 0;
    var run = 0;
    final now = DateTime.utc(2026, 9, 21, 18);

    setUp(() async {
      run++;
      ids = 0;
      dir = await Directory.systemTemp.createTemp('zad_prices_test');
      Hive.init(dir.path);
      documents = await Hive.openBox<String>('documents$run');
      outboxBox = await Hive.openBox<String>('outbox$run');
      server = _Server();
      outbox = Outbox(
        box: outboxBox,
        send: (entry) async => switch (entry.kind) {
          OutboxKind.reportPrice => await prices.sendQueuedReport(entry),
          _ => null,
        },
        clock: () => now,
      );
      prices = PricesRepository(
        cache: documents,
        remote: server,
        outbox: () => outbox,
        newId: () => 'r${ids++}',
        signedInUserId: () => 'user-1',
        now: () => now,
      );
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    List<OutboxEntry> queued() => outbox
        .entries()
        .where((e) => e.kind == OutboxKind.reportPrice)
        .toList();

    test('a report is queued, tidied, under the id the server keeps', () async {
      await prices.report(
        item: '  طماطم   بلدي ',
        price: 12.5,
        currency: 'EGP',
        store: '  ',
        city: ' القاهرة ',
      );

      final entry = queued().single;
      expect(entry.id, 'price_report:r0');
      expect(entry.payload, <String, dynamic>{
        'user_id': 'user-1',
        'report_id': 'r0',
        'item': 'طماطم بلدي',
        'price': 12.5,
        'currency': 'EGP',
        'city': 'القاهرة',
      });
      expect(prices.lastCity(), 'القاهرة');
      expect(server.reports, isEmpty);
    });

    test('two reports are two entries, one never replaces another', () async {
      await prices.report(item: 'طماطم', price: 12);
      await prices.report(item: 'طماطم', price: 11);

      expect(queued(), hasLength(2));
    });

    test('a bad report never reaches the queue', () async {
      await expectLater(
        prices.report(item: 'ط', price: 12),
        throwsArgumentError,
      );
      expect(queued(), isEmpty);
    });

    test('sent, it leaves the queue; a replay is the same report', () async {
      await prices.report(item: 'طماطم', price: 12);
      final entry = queued().single;

      await outbox.flush();
      expect(queued(), isEmpty);

      // The server answers a replay `duplicate`; the phone takes that as sent.
      server.answer = <String, dynamic>{'ok': true, 'duplicate': true, 'id': 1};
      await prices.sendQueuedReport(entry);
      expect(server.reports.map((r) => r['id']), <String>['r0', 'r0']);
    });

    test('a refusal with a reason is a dead letter, shown so', () async {
      server.answer = <String, dynamic>{'ok': false, 'reason': 'invalid_input'};
      await prices.report(item: 'طماطم', price: 12);

      await outbox.flush();

      expect(queued().single.state, OutboxState.dead);
      expect(prices.queuedReports().single.refused, isTrue);
    });

    test('"too many this hour" waits instead', () async {
      server.answer = <String, dynamic>{'ok': false, 'reason': 'too_many'};
      await prices.report(item: 'طماطم', price: 12);

      await outbox.flush();

      expect(queued().single.state, OutboxState.pending);
      expect(prices.queuedReports().single.refused, isFalse);
    });

    test('no signal keeps the report', () async {
      server.failWith = const SocketException('offline');
      await prices.report(item: 'طماطم', price: 12);

      await outbox.flush();

      expect(queued().single.state, OutboxState.pending);
    });

    group('the screen', () {
      Future<ProviderContainer> container({String? country = 'EG'}) async {
        if (country != null) {
          await documents.put(
            'account_settings',
            jsonEncode(<String, dynamic>{'country': country}),
          );
        }
        final c = ProviderContainer(
          overrides: [
            nowProvider.overrideWithValue(() => now),
            outboxProvider.overrideWithValue(outbox),
            pricesRepositoryProvider.overrideWithValue(prices),
            settingsRepositoryProvider.overrideWithValue(
              SettingsRepository(
                cache: documents,
                remote: _NoSettings(),
                outbox: () => outbox,
                signedInUserId: () => 'user-1',
                now: () => now,
              ),
            ),
          ],
        );
        addTearDown(c.dispose);
        return c;
      }

      test("reads in the account's currency, and keeps the answer", () async {
        final c = await container();
        await c.read(pricesControllerProvider.notifier).refresh();

        expect(server.cheapestAsked.last, ('EGP', null));
        final view = c.read(pricesControllerProvider);
        expect(view.rows.single.itemName, 'طماطم');
        expect(view.leaderboard.firstWhere((r) => r.isMe).rank, 2);
        expect(prices.cachedCheapest()?.rows, hasLength(1));
      });

      test('a city filter asks for that city, and the chip stays', () async {
        final c = await container();
        final controller = c.read(pricesControllerProvider.notifier);

        await controller.setCity(' الجيزة ');

        expect(server.cheapestAsked.last, ('EGP', 'الجيزة'));
        expect(c.read(pricesControllerProvider).city, 'الجيزة');
      });

      test('a report that cannot be sent says why, queues nothing', () async {
        final c = await container();
        final controller = c.read(pricesControllerProvider.notifier);

        expect(
          await controller.report(item: 'طماطم', priceText: 'كام'),
          ReportProblem.noPrice,
        );
        expect(queued(), isEmpty);

        // Arabic digits are digits.
        expect(
          await controller.report(
            item: 'طماطم',
            priceText: '١٢٫٥',
            city: 'القاهرة',
          ),
          isNull,
        );
        expect(queued().single.payload['price'], 12.5);
        expect(c.read(pricesControllerProvider).queued, hasLength(1));
        expect(c.read(pricesControllerProvider).lastCity, 'القاهرة');
      });

      test('without a market there is nothing to compare in', () async {
        final c = await container(country: null);
        await c.read(pricesControllerProvider.notifier).refresh();

        expect(server.cheapestAsked, isEmpty);
        expect(c.read(pricesControllerProvider).rows, isEmpty);
      });
    });
  });
}
