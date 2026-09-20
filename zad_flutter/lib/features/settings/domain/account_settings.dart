/// The handful of `zad_users` columns the customer is allowed to set.
///
/// Deliberately not the whole row. `zad_users` also carries what the brain
/// infers and what other screens own — the location, the avatar, the emergency
/// fund — and a settings screen that round-tripped all of it would overwrite
/// those fields with whatever it happened to be holding.
///
/// Note what these values are *not*: they are not the budget. The budget is
/// `zad_budget_state()`'s answer and nothing here recomputes it — see
/// `BudgetSnapshot`'s note on `single_budget_authority`. These are the inputs
/// the customer gives that function, and the figures come back from the server.
library;

import 'package:zad/core/period/payday.dart';

/// The account's own configuration.
class AccountSettings {
  /// Creates a settings reading.
  const new({
    this.monthlyLimit,
    this.limitConfirmedAt,
    this.cycleStartDay,
    this.cycleAnchor = CycleAnchor.dayOfMonth,
    this.currency,
    this.country,
  });

  /// Reads a `zad_users` row.
  factory fromJson(Map<String, dynamic> json) => AccountSettings(
    monthlyLimit: (json['monthly_limit'] as num?)?.toDouble(),
    limitConfirmedAt: switch (json['limit_confirmed_at']) {
      final String s => DateTime.parse(s).toUtc(),
      _ => null,
    },
    cycleStartDay: (json['cycle_start_day'] as num?)?.toInt(),
    cycleAnchor: CycleAnchor.fromWire(json['cycle_anchor'] as String?),
    currency: json['currency'] as String?,
    country: json['country'] as String?,
  );

  /// The ceiling the customer says they have for a cycle.
  ///
  /// Null means never set. It is not zero: the server answers `remaining:
  /// null` for an account with no confirmed limit precisely so no client
  /// prints a confident figure at somebody who never told us what they earn.
  final double? monthlyLimit;

  /// When the customer last confirmed [monthlyLimit].
  ///
  /// The server treats a limit with no confirmation as unconfirmed, which is
  /// why every write of the number sets this in the same statement.
  final DateTime? limitConfirmedAt;

  /// Which day of the month the salary cycle turns over on.
  ///
  /// Null means the cycle has not been established, and both clients then fall
  /// back to the calendar month — see `CycleMath.cycleStart` on the Kotlin side
  /// and `periodPayday` here. Null is therefore a real, working state and the
  /// screen says so rather than showing an empty field as though something
  /// were broken.
  final int? cycleStartDay;

  /// How [cycleStartDay] is placed inside its month.
  final CycleAnchor cycleAnchor;

  /// The account's currency code, as the brain and the bot read it.
  final String? currency;

  /// The account's country. Set elsewhere; carried here so a settings write
  /// never has to send it back.
  final String? country;

  /// Whether there is a confirmed limit to report.
  bool get hasConfirmedLimit =>
      monthlyLimit != null && monthlyLimit! > 0 && limitConfirmedAt != null;

  /// Whether the cycle follows a salary day rather than the calendar month.
  bool get hasSalaryCycle => cycleStartDay != null;

  /// A copy with the given fields replaced.
  ///
  /// `clearCycleStartDay` exists because null is a meaningful value here —
  /// "back to the calendar month" — and a plain null argument cannot say
  /// whether it means that or "leave it alone".
  AccountSettings copyWith({
    double? monthlyLimit,
    DateTime? limitConfirmedAt,
    int? cycleStartDay,
    CycleAnchor? cycleAnchor,
    String? currency,
    String? country,
    bool clearCycleStartDay = false,
  }) => AccountSettings(
    monthlyLimit: monthlyLimit ?? this.monthlyLimit,
    limitConfirmedAt: limitConfirmedAt ?? this.limitConfirmedAt,
    cycleStartDay: clearCycleStartDay
        ? null
        : (cycleStartDay ?? this.cycleStartDay),
    cycleAnchor: cycleAnchor ?? this.cycleAnchor,
    currency: currency ?? this.currency,
    country: country ?? this.country,
  );

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'monthly_limit': monthlyLimit,
    'limit_confirmed_at': limitConfirmedAt?.toIso8601String(),
    'cycle_start_day': cycleStartDay,
    'cycle_anchor': cycleAnchor.wireName,
    'currency': currency,
    'country': country,
  };

  /// The columns a settings read asks the server for.
  ///
  /// One list, used by the select and by nothing else, so the read and this
  /// class cannot drift apart silently.
  static const List<String> columns = <String>[
    'monthly_limit',
    'limit_confirmed_at',
    'cycle_start_day',
    'cycle_anchor',
    'currency',
    'country',
  ];
}
