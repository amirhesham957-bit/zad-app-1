/// Kotlin's `StatementCsvImporter`: banks export CSVs in no shared format, so
/// nothing is guessed — the user maps date, description and amount to the
/// file's own headers and reviews every row before anything is written. PDF is
/// deliberately unsupported (vision OCR misreads multi-page money tables).
library;

import 'package:zad/core/money/money.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// A read CSV: the header row and the rest.
typedef CsvTable = ({List<String> headers, List<List<String>> rows});

/// Which column is which.
typedef ColumnMapping = ({
  int date,
  int title,
  int amount,
  int? category,
  bool invertSign,
});

/// One row as it will be imported.
typedef PreviewRow = ({
  int rowIndex,
  DateTime? date,
  String title,
  double? amount,
  bool isExpense,
  String category,
  bool hasError,
});

/// The title Kotlin gives a row with a blank description.
const String kImportedTitle = 'معاملة مستوردة';

/// Reads [text] as CSV; null when it has no lines.
CsvTable? readCsv(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .map(_parseLine)
      .toList();
  if (lines.isEmpty) return null;
  return (headers: lines.first, rows: lines.skip(1).toList());
}

/// A simple CSV line parser that respects "quoted, fields".
List<String> _parseLine(String line) {
  final fields = <String>[];
  final current = StringBuffer();
  var inQuotes = false;
  for (final c in line.split('')) {
    if (c == '"') {
      inQuotes = !inQuotes;
    } else if (c == ',' && !inQuotes) {
      fields.add(current.toString().trim());
      current.clear();
    } else {
      current.write(c);
    }
  }
  fields.add(current.toString().trim());
  return fields;
}

/// Kotlin's six accepted date shapes, tried in its order.
DateTime? parseStatementDate(String raw) {
  final t = raw.trim();
  DateTime? ymd(String y, String m, String d) {
    final yy = int.tryParse(y);
    final mm = int.tryParse(m);
    final dd = int.tryParse(d);
    if (yy == null || mm == null || dd == null) return null;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
    final date = DateTime(yy, mm, dd);
    return date.month == mm && date.day == dd ? date : null;
  }

  // yyyy-MM-dd, yyyy/MM/dd
  var m = RegExp(r'^(\d{4})[-/](\d{2})[-/](\d{2})$').firstMatch(t);
  if (m != null) {
    final sep1 = t[4];
    final sep2 = t[7];
    if (sep1 == sep2) return ymd(m[1]!, m[2]!, m[3]!);
  }
  // dd/MM/yyyy, dd-MM-yyyy, dd.MM.yyyy — then MM/dd/yyyy
  m = RegExp(r'^(\d{2})([/.-])(\d{2})\2(\d{4})$').firstMatch(t);
  if (m != null) {
    return ymd(m[4]!, m[3]!, m[1]!) ??
        (m[2] == '/' ? ymd(m[4]!, m[1]!, m[3]!) : null);
  }
  return null;
}

/// Kotlin's amount cleaning: thousands commas and the riyal marks dropped.
double? parseStatementAmount(String raw) {
  final cleaned = raw
      .trim()
      .replaceAll(',', '')
      .replaceAll(RegExp('SAR', caseSensitive: false), '')
      .replaceAll('ر.س', '')
      .trim();
  return double.tryParse(cleaned)?.asMoney;
}

/// `SaBankParser.categoryRules`, used as `classify(title, null)` does.
///
/// ⚠️ Matching data, not UI text: these are matched against the statement's
/// own description and the category names are what `zad_transactions`
/// stores. Never translate them.
const List<(String, List<String>)> _categoryRules = <(String, List<String>)>[
  ('الراتب', <String>['راتب', 'مرتب', 'salary']),
  (
    'البقالة',
    <String>[
      'بقالة',
      'بقاله',
      'تموين',
      'تموينات',
      'سوبرماركت',
      'سوبر ماركت',
      'خضار', //
      'فواكه', 'لحوم', 'هايبر', 'ماركت', 'بنده', 'العثيم', 'الدانوب', 'لولو',
      'كارفور', 'تميمي', 'محطة الجزيرة', 'جولف', 'grocery', 'supermarket',
      'hypermarket', 'panda', 'danube', 'carrefour', 'lulu', 'farmers',
    ],
  ),
  (
    'المطاعم',
    <String>[
      'مطعم', 'كافيه', 'وجبات', 'hungerstation', 'mrsool', 'jahez', //
      'توصيل طعام',
      'طلبات',
      'مأكولات',
      'ستاربكس',
      'ماكدونالدز',
      'البيك',
      'كودو',
      'هرفي', 'دومينوز', 'starbucks', 'mcdonald', 'albaik', 'kudu', 'herfy',
      'restaurant', 'cafe',
    ],
  ),
  (
    'الفواتير',
    <String>[
      'كهرب',
      'فواتير',
      'المياه',
      'اتصالات',
      'mobily',
      'zain',
      'موبايلي',
      'زين', //
      'الكهرباء', 'المياه الوطنية', 'electricity', 'water bill',
    ],
  ),
  (
    'الرعاية الصحية',
    <String>[
      'علاج',
      'صيدلية',
      'مستشفى',
      'عيادة',
      'دواء',
      'النهدي',
      'الدواء',
      'nahdi', //
      'pharmacy', 'hospital', 'clinic',
    ],
  ),
  (
    'المواصلات',
    <String>[
      'مواصلات',
      'أوبر',
      'كريم',
      'uber',
      'careem',
      'taxi',
      'نقل',
      'طيران',
      'باص', //
      'قطار', 'flight', 'المطار',
    ],
  ),
  (
    'التعليم',
    <String>[
      'تعليم', 'مدرسة', 'جامعة', 'دورة', 'تدريب', 'منصة تعليم', 'school', //
      'university', 'course', 'udemy',
    ],
  ),
  (
    'الأقساط',
    <String>[
      'تابي', 'تمارة', 'فاليو', 'قسط', 'أقساط', 'tabby', 'tamara', 'valu', //
      'installment', 'دفعة من',
    ],
  ),
  (
    'الاشتراكات',
    <String>[
      'نتفلكس', 'netflix', 'شاهد', 'shahid', 'spotify', 'youtube premium', //
      'apple music', 'اشتراك شهري', 'اشتراك سنوي', 'subscription', 'anghami',
      'أنغامي', 'osn', 'prime',
    ],
  ),
  (
    'الوقود',
    <String>[
      'محطة', 'بنزين', 'وقود', 'ديزل', 'ساسكو', 'الدريس', 'نفط', 'petrol', //
      'fuel', 'sasco', 'aldrees', 'naft',
    ],
  ),
  ('تحويلات', <String>['حوالة', 'تحويل', 'transfer', 'stc pay']),
];

/// The category for a description with no mapped category column.
String classifyStatementTitle(String title) {
  final t = title.toLowerCase();
  for (final (category, keywords) in _categoryRules) {
    if (keywords.any(t.contains)) return category;
  }
  return 'أخرى';
}

/// Every row of [table] under [mapping].
List<PreviewRow> buildPreview(CsvTable table, ColumnMapping mapping) =>
    <PreviewRow>[
      for (final (index, row) in table.rows.indexed)
        _previewRow(index, row, mapping),
    ];

PreviewRow _previewRow(int index, List<String> row, ColumnMapping mapping) {
  String col(int i) => i < row.length ? row[i].trim() : '';
  final date = parseStatementDate(col(mapping.date));
  final rawTitle = col(mapping.title);
  final title = rawTitle.isEmpty ? kImportedTitle : rawTitle;
  var amount = parseStatementAmount(col(mapping.amount));
  if (mapping.invertSign && amount != null) amount = -amount;
  final mapped = mapping.category == null ? '' : col(mapping.category!);
  return (
    rowIndex: index,
    date: date,
    title: title,
    amount: amount?.abs(),
    isExpense: (amount ?? 0) < 0,
    category: mapped.isNotEmpty ? mapped : classifyStatementTitle(title),
    hasError: amount == null || date == null,
  );
}

bool _isGeneric(String? title) =>
    title == null || title.trim().isEmpty || title == kImportedTitle;

bool _descriptionsCompatible(String? existing, String imported) {
  if (_isGeneric(existing) || _isGeneric(imported)) return true;
  final e = existing!.trim().toLowerCase();
  final i = imported.trim().toLowerCase();
  return e.contains(i) || i.contains(e);
}

/// Kotlin's `isDuplicateOfExisting`: same direction, amount within 0.005,
/// same day, and a description that fits — two coffees for the same price
/// on the same day are two rows, not one.
bool isDuplicateOf(ZadTransaction tx, PreviewRow row) {
  final amount = row.amount;
  final date = row.date;
  if (amount == null || date == null) return false;
  // Kotlin compares the stored row's UTC date with the statement's day.
  final c = tx.createdAt.toUtc();
  return tx.isExpense == row.isExpense &&
      (tx.amount - amount).abs() < 0.005 &&
      c.year == date.year &&
      c.month == date.month &&
      c.day == date.day &&
      _descriptionsCompatible(tx.merchantName ?? tx.title, row.title);
}
