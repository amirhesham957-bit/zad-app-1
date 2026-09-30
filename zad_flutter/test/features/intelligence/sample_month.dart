import 'package:zad/shared/transactions/domain/transaction.dart';

/// A September cycle for a family of four, plus a lighter August before it —
/// the fixture the monthly-report tests and the PDF render check share.
final DateTime sampleStart = DateTime.utc(2026, 9);

/// End of the sample cycle.
final DateTime sampleEnd = DateTime.utc(2026, 10);

var _n = 0;

ZadTransaction _out(
  int day,
  String title,
  double amount,
  String? category, {
  int month = 9,
}) => ZadTransaction.expense(
  id: 'e${_n++}',
  userId: 'u',
  amount: amount,
  title: title,
  createdAt: DateTime.utc(2026, month, day, 12),
  wallet: Wallet.card,
  category: category,
);

/// All of it, both months.
List<ZadTransaction> sampleMonth() => <ZadTransaction>[
  ZadTransaction.income(
    id: 'i1',
    userId: 'u',
    amount: 18000,
    title: 'المرتب',
    createdAt: DateTime.utc(2026, 9, 1, 9),
    wallet: Wallet.bank,
    category: 'الراتب',
  ),
  // House.
  _out(2, 'كارفور', 2400, 'البقالة'),
  _out(9, 'خضار وفاكهة', 450, 'البقالة'),
  _out(16, 'كارفور', 1900, 'البقالة'),
  _out(5, 'فاتورة الكهرباء', 780, 'الفواتير'),
  _out(6, 'الإنترنت', 350, 'الفواتير'),
  _out(1, 'الإيجار', 5000, 'إيجار'),
  // The same thing twice in one week.
  _out(10, 'زيت وسكر', 320, 'البقالة'),
  _out(13, 'زيت وسكر', 300, 'البقالة'),
  // Kids.
  _out(3, 'مصاريف المدرسة', 2500, 'التعليم'),
  _out(8, 'حفاضات', 380, 'أطفال'),
  _out(20, 'حفاضات', 390, 'أطفال'),
  _out(12, 'ألعاب', 250, 'أطفال'),
  // Pharmacy.
  _out(4, 'صيدلية العزبي', 420, 'صيدلية'),
  _out(18, 'دواء الضغط', 310, 'الرعاية الصحية'),
  // Family outings.
  _out(7, 'مطعم كبدة', 600, 'المطاعم'),
  _out(21, 'سينما', 400, 'ترفيه'),
  _out(27, 'النادي', 900, 'ترفيه'),
  // Transport, one outlier trip.
  _out(2, 'أوبر', 90, 'المواصلات'),
  _out(5, 'أوبر', 85, 'المواصلات'),
  _out(11, 'أوبر', 110, 'المواصلات'),
  _out(15, 'أوبر للمطار', 650, 'المواصلات'),
  _out(19, 'بنزين', 500, 'المواصلات'),
  _out(25, 'أوبر', 95, 'المواصلات'),
  // Small purchases that add up.
  for (final d in <int>[2, 4, 6, 9, 11, 14, 17, 20, 23, 26])
    _out(d, 'قهوة', 35, 'مشروبات'),
  // August, lighter.
  _out(3, 'كارفور', 2600, 'البقالة', month: 8),
  _out(5, 'فاتورة الكهرباء', 690, 'الفواتير', month: 8),
  _out(1, 'الإيجار', 5000, 'إيجار', month: 8),
  _out(8, 'أوبر', 300, 'المواصلات', month: 8),
  _out(12, 'مطعم', 500, 'المطاعم', month: 8),
  _out(14, 'صيدلية', 380, 'صيدلية', month: 8),
  _out(10, 'قهوة', 120, 'مشروبات', month: 8),
];
