/// Kotlin's `StatementCsvImporter`: banks export CSVs in no shared format, so
/// nothing is guessed — the user maps date, description and amount to the
/// file's own headers and reviews every row before anything is written.
///
/// A photo or a PDF of the statement (ZAD_PLAN ٣.٣) is read on the server
/// (`analyze_statement`). PDF used to be left out because vision misreads
/// money tables; the server now checks every row against the statement's own
/// running balance, and a row that does not add up starts unticked.
library;

import 'package:zad/core/money/money.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

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
  // The statement's printed balance agrees with this row (true), does not
  // (false), or there was none to check (null; always null for a CSV).
  bool? balanceOk,
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

/// Every row of [table] under [mapping]. A row with no mapped category takes
/// the customer's own category for its merchant ([customCategory], Kotlin's
/// MerchantCategoryOverrides) before the keyword guess.
List<PreviewRow> buildPreview(
  CsvTable table,
  ColumnMapping mapping, {
  String? Function(String title)? customCategory,
}) => <PreviewRow>[
  for (final (index, row) in table.rows.indexed)
    _previewRow(index, row, mapping, customCategory),
];

PreviewRow _previewRow(
  int index,
  List<String> row,
  ColumnMapping mapping,
  String? Function(String title)? customCategory,
) {
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
    category: mapped.isNotEmpty
        ? mapped
        : customCategory?.call(title) ?? classifyStatementTitle(title),
    hasError: amount == null || date == null,
    balanceOk: null,
  );
}

/// How a picked or shared file is imported.
enum StatementFileKind {
  /// Mapped by hand on the phone.
  csv,

  /// Read on the server.
  pdf,

  /// Read on the server.
  image,
}

/// The kind of file [name] is, by its extension; null for anything else.
StatementFileKind? statementFileKind(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'csv' || 'txt' => StatementFileKind.csv,
    'pdf' => StatementFileKind.pdf,
    'jpg' ||
    'jpeg' ||
    'png' ||
    'webp' ||
    'heic' ||
    'heif' => StatementFileKind.image,
    _ => null,
  };
}

/// The mime type `analyze_statement` is told, from the file's name.
String statementMimeType(String name) {
  final ext = name.substring(name.lastIndexOf('.') + 1).toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => 'image/jpeg',
  };
}

/// What the statement's own balance says about the rows as read.
enum StatementCheck {
  /// Opening + credits − debits = closing, or every running balance fits.
  balanced,

  /// Something does not add up — every row wants a look.
  mismatch,

  /// The statement prints no balance to check against.
  unknown,
}

/// A statement read off a photo or a PDF.
typedef ScannedStatement = ({
  List<PreviewRow> rows,
  StatementCheck check,
  // Rows the server could not read (no date, no amount) and left out.
  int dropped,
  String? currency,
});

/// Reads `analyze_statement`'s `statement` object; null when it holds no row.
ScannedStatement? readScannedStatement(
  Map<String, dynamic> json, {
  String? Function(String title)? customCategory,
}) {
  final raw = json['rows'];
  final rows = <PreviewRow>[];
  if (raw is List) {
    for (final item in raw) {
      if (item is! Map) continue;
      final date = parseStatementDate('${item['date'] ?? ''}');
      final amount = (item['amount'] as num?)?.toDouble().asMoney;
      if (date == null || amount == null || amount <= 0) continue;
      final description = item['description'];
      final title = description is String && description.trim().isNotEmpty
          ? description.trim()
          : kImportedTitle;
      final balanceOk = item['balance_ok'];
      rows.add((
        rowIndex: rows.length,
        date: date,
        title: title,
        amount: amount,
        isExpense: item['direction'] != 'credit',
        category: customCategory?.call(title) ?? classifyStatementTitle(title),
        hasError: false,
        balanceOk: balanceOk is bool ? balanceOk : null,
      ));
    }
  }
  if (rows.isEmpty) return null;
  final currency = json['currency'];
  return (
    rows: rows,
    check: switch (json['check']) {
      'balanced' => StatementCheck.balanced,
      'mismatch' => StatementCheck.mismatch,
      _ => StatementCheck.unknown,
    },
    dropped: (json['dropped'] as num?)?.toInt() ?? 0,
    currency: currency is String && currency.isNotEmpty ? currency : null,
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
