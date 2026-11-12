// A brand-new account's market reaches the screens the moment it is known.
//
// On 2026-11-12 a Saudi account was signed up on the emulator: the budget gate
// showed «السعودية — SAR», and the home ticker right after it still read the
// Egyptian «لسه مفيش». `accountCountryProvider` read `.cached()` off the
// repository, which is rebuilt on sign-in — when a new account's cache is
// still empty — and never again. These tests stage exactly that: the
// repository exists with nothing cached, then the first refresh lands.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/market/application/arabic_variant.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';

class _Remote implements SettingsRemote {
  Map<String, dynamic>? row;

  @override
  Future<Map<String, dynamic>?> fetch({required String userId}) async => row;

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> sent,
  ) async => <String, dynamic>{...?row, ...sent};
}

void main() {
  late Directory dir;
  late Box<String> documents;
  late _Remote remote;
  late SettingsRepository repo;
  late ProviderContainer container;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_country_follows');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents');
    final outbox = Outbox(
      box: await Hive.openBox<String>('outbox'),
      send: (_) async {},
    );
    remote = _Remote();
    repo = SettingsRepository(
      cache: documents,
      remote: remote,
      outbox: () => outbox,
      signedInUserId: () => 'new-saudi-account',
      now: DateTime.now,
    );
    container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'the first refresh moves the country, the zone and the Arabic',
    () async {
      // Signed in, nothing fetched yet: what the shell reads first.
      final countries = <String?>[];
      container.listen(
        accountCountryProvider,
        (_, next) => countries.add(next),
        fireImmediately: true,
      );
      // The zone is read only after the refresh: with no country it falls to
      // the budget snapshot, which this container does not have.
      final zones = <String>[];

      remote.row = <String, dynamic>{'country': 'SA', 'currency': 'SAR'};
      await repo.refresh();
      await settle();

      expect(countries, <String?>[null, 'SA']);
      container.listen(
        accountTimeZoneProvider,
        (_, next) => zones.add(next),
        fireImmediately: true,
      );
      expect(zones, <String>['Asia/Riyadh']);
      expect(
        arabicVariantFor(country: container.read(accountCountryProvider)),
        'SA',
      );
    },
  );

  test(
    'choosing a market later moves it too, and sign-out clears it',
    () async {
      remote.row = <String, dynamic>{'country': 'EG', 'currency': 'EGP'};
      await repo.refresh();
      await settle();
      expect(container.read(accountCountryProvider), 'EG');

      await repo.setMarket(country: 'SA', currency: 'SAR');
      await settle();
      expect(container.read(accountCountryProvider), 'SA');

      await repo.clear();
      await settle();
      expect(container.read(accountCountryProvider), isNull);
    },
  );
}
