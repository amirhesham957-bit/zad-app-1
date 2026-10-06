/// حارس الطوارئ المنزلية (ZAD_LIVING_BRAIN.md الشريحة ٤٣): الفنيين اللي
/// العميل بيثق فيهم (`zad_trusted_technicians`)، وكلمات طوارئ البيت اللي
/// بتفتحهم بنقرة من الشات.
library;

/// A technician's trade, as the table stores it.
enum TechnicianTrade {
  /// سباك.
  plumber('plumber', 'سباك'),

  /// كهربائي.
  electrician('electrician', 'كهربائي'),

  /// غاز.
  gas('gas', 'فني غاز'),

  /// تكييف.
  ac('ac', 'تكييف'),

  /// نجار.
  carpenter('carpenter', 'نجار'),

  /// مفاتيح وكوالين.
  locksmith('locksmith', 'كوالين ومفاتيح'),

  /// أجهزة.
  appliances('appliances', 'أجهزة'),

  /// تاني.
  other('other', 'تاني');

  new(this.wire, this.label);

  /// The stored value.
  final String wire;

  /// What the customer reads.
  final String label;

  /// From the stored value; unknown → [other].
  static TechnicianTrade fromWire(String? w) => values.firstWhere(
    (t) => t.wire == w,
    orElse: () => TechnicianTrade.other,
  );
}

/// One saved technician.
typedef TrustedTechnician = ({
  String id,
  String name,
  TechnicianTrade trade,
  String phone,
  String notes,
});

/// Reads a row.
TrustedTechnician technicianFromJson(Map<String, dynamic> j) => (
  id: '${j['id']}',
  name: (j['name'] as String?) ?? '',
  trade: TechnicianTrade.fromWire(j['trade'] as String?),
  phone: (j['phone'] as String?) ?? '',
  notes: (j['notes'] as String?) ?? '',
);

/// The table's phone rule, so the dialog refuses what the server would.
final RegExp kTechnicianPhone = RegExp(r'^\+?[0-9][0-9 -]{5,19}$');

String _norm(String s) => s
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'\s+'), ' ');

// Phrases, not single words: «اشتري ميه» and «الغاز خلص» are not emergencies.
// Gas first — when two match, safety decides.
final List<(TechnicianTrade, RegExp)> _emergencies =
    <(TechnicianTrade, RegExp)>[
      (
        TechnicianTrade.gas,
        RegExp('ريحه (ال)?غاز|تسريب (ال)?غاز|(ال)?غاز (بيسرب|بيهرب|مسرب)'),
      ),
      (
        TechnicianTrade.electrician,
        RegExp(
          'ماس كهرب|فيه ماس|شرار|(ال)?كهربا (قطعت|فصلت|مقطوعه|ضربت)|'
          'مفيش كهربا|السكينه (نزلت|فصلت)|(ال)?فيوز (ضرب|اتحرق)|ريحه حريق',
        ),
      ),
      (
        TechnicianTrade.plumber,
        RegExp(
          'ميه بتنزل|ميه (بتنقط|بتخر)|تسريب (ال)?مي|'
          '(ال)?ماسوره (ضربت|اتكسرت|بتسرب)|'
          'البلاعه (طفحت|مسدوده)|(الحوض|الحمام|التواليت) (مسدود|غرق)|البيت غرق|'
          'السيفون (بايظ|بيسرب)|مفيش ميه',
        ),
      ),
      (
        TechnicianTrade.locksmith,
        RegExp('الباب اتقفل|اتقفل (علي|عليا)|المفتاح (ضاع|اتكسر)|نسيت المفتاح'),
      ),
      (TechnicianTrade.ac, RegExp('التكييف (بايظ|عطلان|وقف|مش بيبرد|بينقط)')),
      (
        TechnicianTrade.appliances,
        RegExp(
          '(التلاجه|الغساله|السخان|البوتاجاز) '
          '(بايظ|بايظه|عطلان|عطلانه|وقف|وقفت|فاصل|فاصله|بيسرب|بتسرب|مش بتبرد)',
        ),
      ),
    ];

/// The trade a message calls for, or null when it is not a home emergency.
TechnicianTrade? homeEmergencyTrade(String message) {
  final m = _norm(message);
  for (final (trade, words) in _emergencies) {
    if (words.hasMatch(m)) return trade;
  }
  return null;
}

/// Said before any number for gas: the call can wait a minute, the valve
/// and the windows cannot.
const String kGasSafetyLine =
    'ريحة غاز؟ اقفل المحبس وافتح الشبابيك وماتشغّلش ولا تطفّي أي كهربا — '
    'وبعدين اتصل.';
