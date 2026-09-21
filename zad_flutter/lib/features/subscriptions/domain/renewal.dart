/// When a subscription next renews — the client's copy of the server's answer.
///
/// Mirror of `public.zad_subscription_next_renewal(text, int, text, date)`,
/// added by `20260815180000_subscriptions_reach_committed` and read back off
/// the deployed function on 2026-09-21 (identical to the file). That function
/// decides what the budget reserves: a subscription counts toward "committed"
/// when this date is not null and falls inside the cycle. If the two drift,
/// the list shows a renewal the budget is not holding money for — or holds
/// money for one the list says is next month — and nothing in the build says
/// so. Change both sides in one commit; `renewal_test.dart` pins the cases.
///
/// Its quirks are copied on purpose, not tidied:
///
/// * An ISO date that does not exist (`2026-02-31`) is not an error. It falls
///   through to the day-of-month branch, which takes the **first one or two
///   digits** of the text — `20`, from the year.
/// * Yearly steps use Postgres interval arithmetic: 29 Feb + 1 year is 28 Feb,
///   and it stays 28 Feb in later years. Monthly steps re-apply the anchor day,
///   so the 31st comes back after February.
/// * An unknown cycle (`QUARTERLY`, empty) is stepped monthly.
library;

/// The billing cycles the server distinguishes.
enum BillingCycle {
  /// Every month on the anchor day, clamped to short months.
  monthly('MONTHLY'),

  /// Every year.
  yearly('YEARLY'),

  /// Every seven days.
  weekly('WEEKLY');

  new(this.wireName);

  /// The value written to `zad_subscriptions.billing_cycle`.
  final String wireName;

  /// Reads the column the way the SQL `case` does: `upper(coalesce(x,
  /// 'MONTHLY'))`, with `ANNUAL` as a synonym and anything unknown monthly.
  static BillingCycle fromWire(String? value) =>
      switch ((value ?? 'MONTHLY').toUpperCase()) {
        'YEARLY' || 'ANNUAL' => yearly,
        'WEEKLY' => weekly,
        _ => monthly,
      };
}

/// The step limit, as in the SQL loop guard.
const int _maxSteps = 600;

final RegExp _isoPrefix = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _firstDigits = RegExp(r'\d{1,2}');

/// The next renewal on or after [asOf], or null when the row does not say
/// which day it renews on.
///
/// [asOf] is a civil date in the account's market zone; only its year, month
/// and day are read. The answer is a UTC-midnight `DateTime` standing for a
/// civil date.
DateTime? nextRenewal({
  required String? renewalDate,
  required int? dueDay,
  required String? billingCycle,
  required DateTime asOf,
}) {
  final today = _date(asOf.year, asOf.month, asOf.day);
  final cycle = BillingCycle.fromWire(billingCycle);

  // 1. A real ISO date, read from the first ten characters.
  var anchor = _isoAnchor(renewalDate);
  int day;

  if (anchor == null) {
    // 2. A day of the month: the column, else the first digits in the text.
    final fromText = _firstDigits.firstMatch(renewalDate ?? '')?.group(0);
    final resolved = dueDay ?? (fromText == null ? null : int.parse(fromText));
    if (resolved == null || resolved < 1 || resolved > 31) return null;
    day = resolved;
    anchor = _date(
      today.year,
      today.month,
      _min(day, _daysIn(today.year, today.month)),
    );
  } else {
    day = anchor.day;
  }

  // 3. Forward to the first occurrence that has not already happened.
  var next = anchor;
  for (var guard = 0; next.isBefore(today) && guard < _maxSteps; guard++) {
    next = step(next, cycle: cycle, anchorDay: day);
  }
  return next.isBefore(today) ? null : next;
}

/// One cycle on from [from], exactly as the SQL loop steps.
///
/// [anchorDay] is the day of the month a monthly schedule returns to; yearly
/// and weekly steps ignore it, as the SQL does.
DateTime step(
  DateTime from, {
  required BillingCycle cycle,
  required int anchorDay,
}) {
  switch (cycle) {
    case BillingCycle.yearly:
      // `date + interval '1 year'`: the same month and day, clamped.
      final year = from.year + 1;
      return _date(year, from.month, _min(from.day, _daysIn(year, from.month)));
    case BillingCycle.weekly:
      return from.add(const Duration(days: 7));
    case BillingCycle.monthly:
      final year = from.month == 12 ? from.year + 1 : from.year;
      final month = from.month == 12 ? 1 : from.month + 1;
      return _date(year, month, _min(anchorDay, _daysIn(year, month)));
  }
}

/// The anchor day a row's schedule uses — what [step] needs to keep a monthly
/// renewal on the 31st across February. Null when the row has no schedule.
int? anchorDayOf({required String? renewalDate, required int? dueDay}) {
  final iso = _isoAnchor(renewalDate);
  if (iso != null) return iso.day;
  final fromText = _firstDigits.firstMatch(renewalDate ?? '')?.group(0);
  final resolved = dueDay ?? (fromText == null ? null : int.parse(fromText));
  if (resolved == null || resolved < 1 || resolved > 31) return null;
  return resolved;
}

/// What a charge costs per month, for a total across cycles.
///
/// The Kotlin app's `monthlyEquivalentCost`, figure for figure — 4.345 weeks
/// to the month — so the two clients print the same total.
double monthlyEquivalent(double amount, BillingCycle cycle) => switch (cycle) {
  BillingCycle.yearly => amount / 12,
  BillingCycle.weekly => amount * 4.345,
  BillingCycle.monthly => amount,
};

/// The ISO date in the first ten characters, or null when there is none or it
/// is not a real day (the SQL's `exception when others`).
DateTime? _isoAnchor(String? renewalDate) {
  if (renewalDate == null || renewalDate.length < 10) return null;
  final head = renewalDate.substring(0, 10);
  if (!_isoPrefix.hasMatch(head)) return null;

  final year = int.parse(head.substring(0, 4));
  final month = int.parse(head.substring(5, 7));
  final day = int.parse(head.substring(8, 10));
  // Year 0 is out of range for a Postgres date, so the cast fails there too.
  if (year < 1 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > _daysIn(year, month)) {
    return null;
  }
  return _date(year, month, day);
}

DateTime _date(int year, int month, int day) => DateTime.utc(year, month, day);

int _daysIn(int year, int month) => DateTime.utc(year, month + 1, 0).day;

int _min(int a, int b) => a < b ? a : b;
