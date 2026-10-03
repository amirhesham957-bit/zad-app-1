// A child's phone keeping its zones and the sharing notice in step with the
// server (docs/agent/ZAD_LIVING_BRAIN.md slice 2).

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/alerts/data/push_platform.dart';
import 'package:zad/shared/family/data/family_shares_remote.dart';
import 'package:zad/shared/family/domain/family_share.dart';
import 'package:zad/shared/places/application/child_zones.dart';
import 'package:zad/shared/places/domain/places.dart';

class _Remote implements FamilySharesRemote {
  MyZones zones = (zones: const <ChildZone>[], watchers: const <String>[]);

  @override
  Future<MyZones> myZones() async => zones;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Notice implements SharingNotice {
  String? shown;
  bool cleared = false;

  @override
  Future<void> show({
    required List<String> watchers,
    required List<String> places,
  }) async {
    shown = '${watchers.join('+')}: ${places.join('+')}';
    cleared = false;
  }

  @override
  Future<void> clear() async {
    shown = null;
    cleared = true;
  }
}

void main() {
  const school = (
    id: 'z1',
    label: 'المدرسة',
    lat: 30.05,
    lon: 31.24,
    radius: 150.0,
  );

  test('a zone shared puts the notice up with who follows and where', () async {
    final remote = _Remote()
      ..zones = (
        zones: const <ChildZone>[school],
        watchers: const <String>['بابا'],
      );
    final notice = _Notice();
    await ChildZonesSync(remote: remote, engine: null, notice: notice).sync();
    expect(notice.shown, 'بابا: المدرسة');
  });

  test('nothing shared takes it down', () async {
    final notice = _Notice()..shown = 'قديم';
    await ChildZonesSync(
      remote: _Remote(),
      engine: null,
      notice: notice,
    ).sync();
    expect(notice.cleared, isTrue);
  });

  test('the notice says what is shared and what is not', () {
    final text = sharingNoticeText(
      watchers: const <String>['بابا', 'ماما'],
      places: const <String>['المدرسة', 'النادي'],
    );
    expect(text.body, contains('بابا وماما'));
    expect(text.body, contains('المدرسة، النادي'));
    expect(text.body, contains('مش مكانك طول الوقت'));
    expect(text.body, contains('«عيلتي»'));
  });

  test('zad_family_my_zones reads, skipping anything malformed', () {
    final mine = myZonesFromJson(const <String, dynamic>{
      'ok': true,
      'zones': <dynamic>[
        <String, dynamic>{
          'id': 'z1',
          'label': 'المدرسة',
          'lat': 30.05,
          'lng': 31.24,
          'radius_m': 150,
        },
        <String, dynamic>{'id': 'z2', 'label': 'ناقص'},
      ],
      'watchers': <dynamic>['بابا', '', 3],
    });
    expect(mine.zones, const <ChildZone>[school]);
    expect(mine.watchers, <String>['بابا']);
    expect(
      myZonesFromJson(const <String, dynamic>{'ok': false}).zones,
      isEmpty,
    );
    expect(myZonesFromJson(null).zones, isEmpty);
  });
}
