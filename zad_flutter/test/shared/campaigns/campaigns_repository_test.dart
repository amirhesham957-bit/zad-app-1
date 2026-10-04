// The campaign catalog: cached for the first frame, replaced by a successful
// read, and left alone by a failed one.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/shared/campaigns/application/campaigns_controller.dart';
import 'package:zad/shared/campaigns/data/campaigns_repository.dart';

Map<String, dynamic> _row(String id) => <String, dynamic>{
  'id': id,
  'event_key': 'halloween',
  'from_md': '10-25',
  'to_md': '10-31',
  'theme_primary': '#4C1D95',
  'theme_secondary': '#9A3412',
  'banner_title': 'title',
  'banner_body': 'body',
  'cta_text': 'cta',
  'cta_prompt': 'prompt',
};

class _Remote implements CampaignsRemote {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  bool offline = false;
  int reads = 0;

  @override
  Future<List<Map<String, dynamic>>> campaigns() async {
    reads++;
    if (offline) throw const SocketException('offline');
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> seasonWindows() async {
    if (offline) throw const SocketException('offline');
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'start_date': '2027-02-08T00:00:00+00:00',
        'end_date': '2027-03-09T00:00:00+00:00',
        'seasonal_events': <String, dynamic>{
          'slug': 'ramadan',
          'family_id': null,
        },
      },
    ];
  }
}

void main() {
  late Directory dir;
  late Box<String> box;
  late _Remote remote;
  var run = 0;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_campaigns_test');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('documents${run++}');
    remote = _Remote();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('empty before the first read', () {
    final repository = CampaignsRepository(cache: box, remote: remote);
    expect(repository.cached().campaigns, isEmpty);
  });

  test('a read is cached for the next start', () async {
    remote.rows = <Map<String, dynamic>>[_row('a'), _row('b')];
    await CampaignsRepository(cache: box, remote: remote).refresh();

    final nextStart = CampaignsRepository(cache: box, remote: _Remote());
    final cached = nextStart.cached();
    expect(cached.campaigns.map((c) => c.id), <String>['a', 'b']);
    expect(cached.seasons.single.slug, 'ramadan');
  });

  test('a failed read leaves the cache as it was', () async {
    remote.rows = <Map<String, dynamic>>[_row('a')];
    final repository = CampaignsRepository(cache: box, remote: remote);
    await repository.refresh();
    remote.offline = true;
    await expectLater(repository.refresh(), throwsA(anything));
    expect(repository.cached().campaigns.single.id, 'a');
  });

  test('a campaign switched off on the dashboard disappears', () async {
    remote.rows = <Map<String, dynamic>>[_row('a'), _row('b')];
    final repository = CampaignsRepository(cache: box, remote: remote);
    await repository.refresh();
    remote.rows = <Map<String, dynamic>>[_row('b')];
    await repository.refresh();
    expect(repository.cached().campaigns.single.id, 'b');
  });

  test('the controller shows the cache, then the server', () async {
    remote.rows = <Map<String, dynamic>>[_row('old')];
    final repository = CampaignsRepository(cache: box, remote: remote);
    await repository.refresh();
    remote.rows = <Map<String, dynamic>>[_row('new')];

    final container = ProviderContainer(
      overrides: [campaignsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(campaignsControllerProvider, (_, _) {});
    addTearDown(sub.close);
    expect(sub.read().campaigns.single.id, 'old');
    await pumpEventQueue();
    expect(sub.read().campaigns.single.id, 'new');
  });

  test('the controller keeps the cache when offline', () async {
    remote.rows = <Map<String, dynamic>>[_row('kept')];
    final repository = CampaignsRepository(cache: box, remote: remote);
    await repository.refresh();
    remote.offline = true;

    final container = ProviderContainer(
      overrides: [campaignsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(campaignsControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    expect(sub.read().campaigns.single.id, 'kept');
  });
}
