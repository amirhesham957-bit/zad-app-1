/// A birthday or an anniversary زاد remembers (`zad_memory_occasions`,
/// migration 20261006000000): a memory note with a yearly date. The brain
/// writes them from the chat (`remember_occasion`); the phone only reads, and
/// works out "today" and "in three days" itself — the same rule as the
/// server's `zad-brain/occasions.ts`.
library;

import 'package:flutter/foundation.dart';

/// Which kind.
enum MemoryOccasionKind {
  /// عيد ميلاد.
  birthday,

  /// ذكرى جواز.
  anniversary,
}

/// One remembered occasion.
@immutable
class MemoryOccasion {
  /// Creates an occasion.
  const new({required this.kind, required this.md, this.forName});

  /// From a `zad_memory_occasions` row or the cache; null when unreadable.
  static MemoryOccasion? fromJson(Map<String, dynamic> json) {
    final kind = switch (json['occasion']) {
      'birthday' => MemoryOccasionKind.birthday,
      'anniversary' => MemoryOccasionKind.anniversary,
      _ => null,
    };
    final md = json['occasion_md'];
    if (kind == null || md is! String || !_md.hasMatch(md)) return null;
    final name = json['occasion_for'];
    return MemoryOccasion(
      kind: kind,
      md: md,
      forName: name is String && name.trim().isNotEmpty ? name.trim() : null,
    );
  }

  static final RegExp _md = RegExp(r'^(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$');

  /// Which.
  final MemoryOccasionKind kind;

  /// Every year on this day, `MM-DD`.
  final String md;

  /// Whose; null is the customer.
  final String? forName;

  /// The customer's own.
  bool get isOwn => forName == null;

  /// The cache's shape — the row's.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'occasion': kind.name,
    'occasion_md': md,
    'occasion_for': forName,
  };

  /// Days from [today] (a civil date) to the next one; 0 is today. 29
  /// February falls on the 28th in a common year.
  int daysFrom(DateTime today) {
    final month = int.parse(md.substring(0, 2));
    final day = int.parse(md.substring(3));
    final from = DateTime.utc(today.year, today.month, today.day);
    DateTime on(int year) => DateTime.utc(
      year,
      month,
      month == 2 && day == 29 && !_leap(year) ? 28 : day,
    );
    var next = on(from.year);
    if (next.isBefore(from)) next = on(from.year + 1);
    return next.difference(from).inDays;
  }

  /// The date of the next one from [today].
  DateTime nextFrom(DateTime today) => DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).add(Duration(days: daysFrom(today)));

  static bool _leap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  @override
  bool operator ==(Object other) =>
      other is MemoryOccasion &&
      other.kind == kind &&
      other.md == md &&
      other.forName == forName;

  @override
  int get hashCode => Object.hash(kind, md, forName);
}

const List<String> _months = <String>[
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', //
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// «8 أكتوبر».
String occasionDateLabel(DateTime day) =>
    '${day.day} ${_months[day.month - 1]}';
