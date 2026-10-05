/// حارس المستندات (ZAD_LIVING_BRAIN.md الشريحة ٣٢): الجواز والبطاقة والإقامة
/// والرخص — نوعها وصاحبها وتاريخ انتهائها بس، من غير رقم ولا صورة. صف في
/// `zad_documents`.
///
/// المراحل هي نفس `zad-brain/documents.ts` بالظبط: الجواز ١٨٠ / ٣٠ / ٧ / يوم
/// الانتهاء، والباقي ٣٠ / ٧ / يوم الانتهاء. السيرفر بيكتب ملاحظة للعقل، والموبايل
/// بيرن إشعار محلي يوم كل مرحلة. لو غيّرت واحد غيّر التاني.
library;

/// The kinds `zad_documents.kind` accepts.
enum DocumentKind {
  /// جواز السفر.
  passport('passport', 'جواز السفر'),

  /// البطاقة الشخصية.
  nationalId('national_id', 'البطاقة الشخصية'),

  /// الإقامة.
  residence('residence', 'الإقامة'),

  /// رخصة القيادة.
  drivingLicense('driving_license', 'رخصة القيادة'),

  /// رخصة العربية.
  vehicleLicense('vehicle_license', 'رخصة العربية'),

  /// غيره — محتاج اسم.
  other('other', 'مستند تاني');

  new(this.wire, this.label);

  /// The value in the column.
  final String wire;

  /// What the screen calls it.
  final String label;

  /// The kind named [wire], or null for one this build does not know.
  static DocumentKind? fromWire(Object? wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }

  /// Days before expiry that get a reminder, farthest first; 0 is the day
  /// itself. Many countries want six months left on a passport to let you
  /// in, so a passport starts at 180.
  List<int> get stages =>
      this == passport ? const <int>[180, 30, 7, 0] : const <int>[30, 7, 0];
}

/// One document.
class ImportantDocument {
  /// Creates one.
  const new({
    required this.id,
    required this.kind,
    required this.expiresOn,
    this.holder = '',
    this.label = '',
  });

  /// Reads a row; null when the kind or the date is unknown.
  static ImportantDocument? fromRow(Map<String, dynamic> row) {
    final kind = DocumentKind.fromWire(row['kind']);
    final raw = '${row['expires_on'] ?? ''}';
    final date = raw.length >= 10
        ? DateTime.tryParse(raw.substring(0, 10))
        : null;
    if (kind == null || date == null) return null;
    return ImportantDocument(
      id: '${row['id']}',
      kind: kind,
      expiresOn: DateTime.utc(date.year, date.month, date.day),
      holder: '${row['holder'] ?? ''}',
      label: '${row['label'] ?? ''}',
    );
  }

  /// The row id.
  final String id;

  /// What it is.
  final DocumentKind kind;

  /// The last valid day, as a UTC midnight: calendar arithmetic on local
  /// times loses an hour across a daylight-saving change.
  final DateTime expiresOn;

  /// Whose — empty is the customer.
  final String holder;

  /// The name of an [DocumentKind.other].
  final String label;

  /// «جواز السفر» or the name given to an other one.
  String get title =>
      kind == DocumentKind.other && label.isNotEmpty ? label : kind.label;

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Days from [today] (its calendar date) to the expiry; negative once it
  /// has passed.
  int daysLeft(DateTime today) => expiresOn.difference(_day(today)).inDays;

  /// The stage reached on [today] — the smallest stage at or above the days
  /// left — or null while it is still early.
  int? stageOn(DateTime today) {
    final left = daysLeft(today);
    int? reached;
    for (final s in kind.stages) {
      if (left <= s) reached = s;
    }
    return reached;
  }

  /// The days the phone reminds on, after [today]: one per stage still
  /// ahead. A stage already reached is the screen's and the brain's to say.
  List<(int stage, DateTime day)> reminderDays(DateTime today) {
    final from = _day(today);
    return <(int, DateTime)>[
      for (final s in kind.stages)
        if (expiresOn.subtract(Duration(days: s)).isAfter(from))
          (s, expiresOn.subtract(Duration(days: s))),
    ];
  }

  /// The ISO date the column takes.
  String get expiresOnIso {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${expiresOn.year}-${two(expiresOn.month)}-${two(expiresOn.day)}';
  }
}
