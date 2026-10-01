/// Following a family member — by their yes (owner's decision, 2026-10-01).
///
/// The family admin asks to follow a member's medicines, spending or tasks;
/// the member agrees or declines, and either of them can stop it at any time
/// (`zad_family_shares`, migration 20261001130000). Nothing is visible before
/// the yes, and the server, not this file, is what enforces it.
library;

/// What can be followed.
enum FamilyShareScope {
  /// Medicines and today's doses.
  medicines('medicines', 'الأدوية'),

  /// The last 30 days' spending, as a total and top categories.
  spending('spending', 'المصروف'),

  /// Upcoming appointments and open chores.
  tasks('tasks', 'المهام والمواعيد');

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

  /// Where [scope] stands, or null when it was never asked for.
  FamilyShareStatus? statusOf(FamilyShareScope scope) => shares[scope]?.status;
}
