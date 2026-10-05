/// A quiet period the customer told زاد about — someone ill at home, an
/// emergency, an exam period (docs/agent/ZAD_LIVING_BRAIN.md slice 29).
/// Until it ends, the reminders that can wait, wait; doses, appointments and
/// safety alerts do not. Only the kind and the end are kept — never what the
/// circumstance is.
library;

/// One quiet period.
class LifeCircumstance {
  /// Creates a circumstance.
  const new({required this.id, required this.kind, required this.endsAt});

  /// From a `zad_life_circumstances` row; null if it is not a quiet one.
  static LifeCircumstance? fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    final endsAt = DateTime.tryParse('${json['ends_at']}');
    if ((kind != 'exceptional' && kind != 'exams') || endsAt == null) {
      return null;
    }
    return LifeCircumstance(
      id: '${json['id']}',
      kind: kind as String,
      endsAt: endsAt,
    );
  }

  /// The row's id, for «رجّع التنبيهات».
  final String id;

  /// `exceptional` or `exams`.
  final String kind;

  /// When it ends on its own.
  final DateTime endsAt;

  /// The banner's line, in the account's local time [localEnd].
  String banner(DateTime localEnd) {
    final until = '${localEnd.day}/${localEnd.month}';
    return kind == 'exams'
        ? 'فترة امتحانات — زاد مهدّي التنبيهات لحد $until'
        : 'زاد مهدّي التنبيهات لحد $until — الجرعات والمواعيد زي ما هي';
  }
}
