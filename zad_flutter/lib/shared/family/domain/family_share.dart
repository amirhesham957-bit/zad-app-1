/// Following a family member — by their yes (owner's decision, 2026-10-01).
///
/// The family admin asks to follow a member's medicines, spending or tasks;
/// the member agrees or declines, and either of them can stop it at any time
/// (`zad_family_shares`, migration 20261001130000). Nothing is visible before
/// the yes, and the server, not this file, is what enforces it.
library;

import 'package:zad/shared/places/domain/places.dart' show ChildZone;

/// What can be followed.
enum FamilyShareScope {
  /// Medicines and today's doses.
  medicines('medicines', 'الأدوية'),

  /// The last 30 days' spending, as a total and top categories.
  spending('spending', 'المصروف'),

  /// Upcoming appointments and open chores.
  tasks('tasks', 'المهام والمواعيد'),

  /// Coming to and leaving the zones a parent sets (school, club) — for a
  /// child only. Google Play forbids following an adult's location, a
  /// spouse's included, even with their yes (migration 20261003110000).
  location('location', 'الأماكن (المدرسة…)');

  new(this.wire, this.label);

  /// The server's name for it.
  final String wire;

  /// What the screen calls it.
  final String label;

  /// The scope named [wire], or null.
  static FamilyShareScope? fromWire(String? wire) {
    for (final s in values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// Where a request stands.
enum FamilyShareStatus {
  /// Asked, not answered.
  pending,

  /// The member agreed.
  granted,

  /// The member said no.
  declined,

  /// One side stopped it.
  revoked;

  /// The status named [wire]; unknown values read as revoked (nothing shown).
  static FamilyShareStatus fromWire(String? wire) => switch (wire) {
    'pending' => pending,
    'granted' => granted,
    'declined' => declined,
    _ => revoked,
  };

  /// Whether a new request can be sent.
  bool get canAskAgain => this == declined || this == revoked;
}

/// What the member is asked, in full, before they answer: the scope's label
/// is too short to agree to.
String shareAskText(FamilyShareScope scope, String asker) => switch (scope) {
  FamilyShareScope.location =>
    '$asker عايز يعرف لما تدخل أو تخرج من أماكن هو يحددها (زي المدرسة)',
  _ => '$asker عايز يتابع ${scope.label}',
};

/// One row: [ownerId]'s [scope], followed by [viewerId].
class FamilyShare {
  /// Creates a share.
  const new({
    required this.id,
    required this.ownerId,
    required this.viewerId,
    required this.scope,
    required this.status,
  });

  /// Reads a `zad_family_shares` row; null for a scope this build does not
  /// know.
  static FamilyShare? fromJson(Map<String, dynamic> json) {
    final scope = FamilyShareScope.fromWire(json['scope'] as String?);
    if (scope == null) return null;
    return FamilyShare(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      viewerId: json['viewer_id'] as String,
      scope: scope,
      status: FamilyShareStatus.fromWire(json['status'] as String?),
    );
  }

  /// The row id.
  final String id;

  /// Whose data it is.
  final String ownerId;

  /// Who asked to follow it.
  final String viewerId;

  /// What.
  final FamilyShareScope scope;

  /// Where it stands.
  final FamilyShareStatus status;
}

/// A dose slot today, as the follower sees it.
enum FollowedDoseState {
  /// Recorded as taken.
  taken,

  /// Answered «مخدتهاش».
  skipped,

  /// Passed its window with nothing recorded.
  missed,

  /// Inside its window now.
  due,

  /// Later today.
  upcoming;

  /// The state named [wire].
  static FollowedDoseState fromWire(String? wire) => switch (wire) {
    'taken' => taken,
    'skipped' => skipped,
    'missed' => missed,
    'due' => due,
    _ => upcoming,
  };
}

/// A followed member's medicine.
typedef FollowedMedicine = ({
  String name,
  int? remaining,
  List<({String time, FollowedDoseState state})> today,
});

/// Where a child stands with one zone: the last thing their phone reported.
enum ZoneState {
  /// Last came in.
  inside,

  /// Last went out.
  left,

  /// Nothing reported yet.
  unknown;

  /// The state named [wire].
  static ZoneState fromWire(String? wire) => switch (wire) {
    'inside' => inside,
    'left' => left,
    _ => unknown,
  };
}

/// A zone a parent set for a child, as the parent sees it.
typedef FollowedZone = ({
  String id,
  String label,
  String kind,
  int radiusM,
  List<int> days,
  String? from,
  String? to,
  ZoneState state,
  DateTime? since,
});

/// The child zones this phone watches and who follows them
/// (`zad_family_my_zones`) — the second for the notice that stays up while
/// it is shared.
typedef MyZones = ({List<ChildZone> zones, List<String> watchers});

/// Reads `zad_family_my_zones`; anything malformed is skipped.
MyZones myZonesFromJson(Object? json) {
  if (json is! Map || json['ok'] != true) {
    return (zones: const <ChildZone>[], watchers: const <String>[]);
  }
  return (
    zones: <ChildZone>[
      for (final z in (json['zones'] as List?) ?? const <dynamic>[])
        if (z is Map &&
            z['id'] is String &&
            z['lat'] is num &&
            z['lng'] is num &&
            z['radius_m'] is num)
          (
            id: z['id'] as String,
            label: (z['label'] as String?) ?? '',
            lat: (z['lat'] as num).toDouble(),
            lon: (z['lng'] as num).toDouble(),
            radius: (z['radius_m'] as num).toDouble(),
          ),
    ],
    watchers: <String>[
      for (final w in (json['watchers'] as List?) ?? const <dynamic>[])
        if (w is String && w.isNotEmpty) w,
    ],
  );
}

/// What `zad_family_member_view` returned: each scope's status, and only the
/// granted scopes' data.
class FollowedMember {
  /// Creates the view.
  const new({
    this.shares =
        const <FamilyShareScope, ({String id, FamilyShareStatus status})>{},
    this.medicines,
    this.spent30d,
    this.topCategories = const <({String category, double amount})>[],
    this.appointments,
    this.choresOpen,
    this.canFollowLocation = false,
    this.zones,
  });

  /// Reads the function's answer.
  factory fromJson(Map<String, dynamic> json) {
    final shares =
        <FamilyShareScope, ({String id, FamilyShareStatus status})>{};
    final rawShares = json['shares'];
    if (rawShares is Map) {
      for (final MapEntry(:key, :value) in rawShares.entries) {
        final scope = FamilyShareScope.fromWire(key as String?);
        if (scope == null || value is! Map) continue;
        shares[scope] = (
          id: value['id'] as String,
          status: FamilyShareStatus.fromWire(value['status'] as String?),
        );
      }
    }
    final meds = json['medicines'];
    final spending = json['spending'];
    final tasks = json['tasks'];
    final location = json['location'];
    return FollowedMember(
      shares: shares,
      medicines: meds is List
          ? <FollowedMedicine>[
              for (final m in meds.whereType<Map<dynamic, dynamic>>())
                (
                  name: (m['name'] as String?) ?? '',
                  remaining: (m['remaining'] as num?)?.toInt(),
                  today: <({String time, FollowedDoseState state})>[
                    for (final t
                        in ((m['today'] as List?) ?? const <dynamic>[])
                            .whereType<Map<dynamic, dynamic>>())
                      (
                        time: (t['time'] as String?) ?? '',
                        state: FollowedDoseState.fromWire(
                          t['state'] as String?,
                        ),
                      ),
                  ],
                ),
            ]
          : null,
      spent30d: spending is Map
          ? (spending['spent_30d'] as num?)?.toDouble()
          : null,
      topCategories: spending is Map
          ? <({String category, double amount})>[
              for (final c
                  in ((spending['top'] as List?) ?? const <dynamic>[])
                      .whereType<Map<dynamic, dynamic>>())
                (
                  category: (c['category'] as String?) ?? '',
                  amount: (c['amount'] as num?)?.toDouble() ?? 0,
                ),
            ]
          : const <({String category, double amount})>[],
      appointments: tasks is Map
          ? <({String title, DateTime? startsAt})>[
              for (final a
                  in ((tasks['appointments'] as List?) ?? const <dynamic>[])
                      .whereType<Map<dynamic, dynamic>>())
                (
                  title: (a['title'] as String?) ?? '',
                  startsAt: DateTime.tryParse(
                    (a['starts_at'] as String?) ?? '',
                  ),
                ),
            ]
          : null,
      choresOpen: tasks is Map ? (tasks['chores_open'] as num?)?.toInt() : null,
      canFollowLocation: json['can_follow_location'] == true,
      zones: location is Map
          ? <FollowedZone>[
              for (final z
                  in ((location['zones'] as List?) ?? const <dynamic>[])
                      .whereType<Map<dynamic, dynamic>>())
                if (z['zone_id'] is String)
                  (
                    id: z['zone_id'] as String,
                    label: (z['zone'] as String?) ?? '',
                    kind: (z['kind'] as String?) ?? 'other',
                    radiusM: (z['radius_m'] as num?)?.toInt() ?? 150,
                    days: <int>[
                      for (final d in (z['days'] as List?) ?? const <dynamic>[])
                        if (d is num) d.toInt(),
                    ],
                    from: z['from'] as String?,
                    to: z['to'] as String?,
                    state: ZoneState.fromWire(z['state'] as String?),
                    since: DateTime.tryParse((z['since'] as String?) ?? ''),
                  ),
            ]
          : null,
    );
  }

  /// Each scope's request, when one was ever sent.
  final Map<FamilyShareScope, ({String id, FamilyShareStatus status})> shares;

  /// Granted medicines with today's slots; null when not shared.
  final List<FollowedMedicine>? medicines;

  /// The last 30 days' spending; null when not shared.
  final double? spent30d;

  /// Where most of it went.
  final List<({String category, double amount})> topCategories;

  /// Upcoming appointments; null when not shared.
  final List<({String title, DateTime? startsAt})>? appointments;

  /// Chores still open; null when not shared.
  final int? choresOpen;

  /// Whether the member is a child, the only one whose places may be
  /// followed (the server says so).
  final bool canFollowLocation;

  /// The child's zones and last state; null when not shared.
  final List<FollowedZone>? zones;

  /// The scopes that can be asked of this member: location only for a child.
  List<FamilyShareScope> get followable => <FamilyShareScope>[
    for (final s in FamilyShareScope.values)
      if (s != FamilyShareScope.location || canFollowLocation) s,
  ];

  /// Where [scope] stands, or null when it was never asked for.
  FamilyShareStatus? statusOf(FamilyShareScope scope) => shares[scope]?.status;
}
