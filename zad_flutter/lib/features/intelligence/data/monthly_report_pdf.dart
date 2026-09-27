/// The monthly report as an A4 PDF — Kotlin's `ZadReportPdfBuilder` grown
/// into a full strategic report: a red header with the cycle, an overview
/// strip (spend, income, budget usage, count), then
///   1. the household groups (house, children, pharmacy, family outings) as
///      coloured cards with their share and top items,
///   2. habit alerts (repeat purchases inside a week, costly transport,
///      small purchases that add up) next to the AI's observations,
///   3. savings: next month's projected saving, a month-on-month table with
///      a cap per category, practical steps and the AI's advice,
/// and the round «معتمد من عقل زاد» stamp after the last line. Every number
/// comes from [MonthlyAnalysis], computed from the transactions on the
/// phone; the model only writes the words.
///
/// Pure Dart (`package:pdf`) — the caller hands in the font bytes, so the
/// builder runs the same in a unit test as on the phone. `package:pdf` shapes
/// the Arabic and lays the lines right-to-left itself, and two defects in that
/// shaper are worked around here, not patched in the library:
///
/// - The font is `cairo_pdf.ttf`, a static Cairo built from the app's own
///   variable font by `tool/make_pdf_font.py`: it gives every isolated letter
///   form Cairo lacks a cmap entry (the library aliases «ي» to the wrong one,
///   so a lone «ي» drew nothing) and adds an empty U+200C glyph.
/// - Every word is bracketed with that U+200C ([pdfWords]). A right-to-left
///   line is mirrored word by word using each word's ink box instead of its
///   advance, so a side bearing on a word's end glyph (Cairo's «ر» reaches
///   left of its origin) shifted the word — the space after «تقرير» vanished.
///   An inkless, zero-width glyph at both ends makes ink box and advance agree.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart' show NumberFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:zad/features/intelligence/domain/monthly_analysis.dart';
import 'package:zad/features/intelligence/domain/monthly_report.dart';

/// The bundled font the PDF is drawn with.
const String monthlyReportFontAsset = 'assets/fonts/cairo_pdf.ttf';

const PdfColor _zadRed = PdfColor.fromInt(0xFFC62828);
const PdfColor _body = PdfColor.fromInt(0xFF1E1E1E);
const PdfColor _muted = PdfColor.fromInt(0xFF5A5A5A);
const PdfColor _hairline = PdfColor.fromInt(0xFFE3E3E0);
const PdfColor _surface = PdfColor.fromInt(0xFFF7F7F5);
const PdfColor _track = PdfColor.fromInt(0xFFE9E9E6);
const PdfColor _white = PdfColor.fromInt(0xFFFFFFFF);
const PdfColor _tableHead = PdfColor.fromInt(0xFF263238);
const PdfColor _good = PdfColor.fromInt(0xFF2E7D32);
const PdfColor _goodTint = PdfColor.fromInt(0xFFE8F5E9);
const PdfColor _warn = PdfColor.fromInt(0xFFE65100);
const PdfColor _warnTint = PdfColor.fromInt(0xFFFFF3E0);

/// Each household group's accent and card tint.
const Map<FamilyGroup, (PdfColor, PdfColor)> _groupColors =
    <FamilyGroup, (PdfColor, PdfColor)>{
      FamilyGroup.house: (
        PdfColor.fromInt(0xFF2E7D32),
        PdfColor.fromInt(0xFFEDF7EE),
      ),
      FamilyGroup.kids: (
        PdfColor.fromInt(0xFF1565C0),
        PdfColor.fromInt(0xFFE8F1FB),
      ),
      FamilyGroup.pharmacy: (
        PdfColor.fromInt(0xFFAD1457),
        PdfColor.fromInt(0xFFFCEAF1),
      ),
      FamilyGroup.activities: (
        PdfColor.fromInt(0xFF6A1B9A),
        PdfColor.fromInt(0xFFF4EAF8),
      ),
    };

/// Builds the PDF. [cycle] is the budget cycle's month label (`سبتمبر 2026`),
/// shown under the title when given. [analysis] adds the overview strip and
/// sections 1–3 (family breakdown, habit alerts, the comparison table and
/// caps); without it the PDF is the AI report alone. [currency] follows every
/// amount.
Future<Uint8List> buildMonthlyReportPdf(
  MonthlyReport report, {
  required ByteData font,
  required DateTime issuedOn,
  String cycle = '',
  MonthlyAnalysis? analysis,
  String currency = '',
}) {
  final base = pw.Font.ttf(font);
  final doc = pw.Document(title: monthlyReportTitle, author: 'زاد');
  String money(double v) => formatReportMoney(v, currency);
  final a = analysis;
  final recs = report.recommendations;
  final lastRecs = recs.skip(math.max(0, recs.length - 3)).toList();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 30),
      textDirection: pw.TextDirection.rtl,
      maxPages: 40,
      theme: pw.ThemeData.withFont(base: base).copyWith(
        paragraphStyle: const pw.TextStyle(
          fontSize: 11.5,
          color: _body,
          lineSpacing: 3,
        ),
        defaultTextStyle: const pw.TextStyle(fontSize: 11.5, color: _body),
      ),
      header: (context) =>
          context.pageNumber != 1 ? pw.SizedBox() : _header(issuedOn, cycle),
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.only(top: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _hairline)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            _text(monthlyReportTitle, size: 8.5, color: _muted),
            _text(
              'صفحة ${context.pageNumber} من ${context.pagesCount}',
              size: 8.5,
              color: _muted,
            ),
          ],
        ),
      ),
      build: (context) => <pw.Widget>[
        if (a != null) ..._overview(a, report.health, money),
        if (a == null && report.health.isNotEmpty) _chip(report.health),
        if (report.summary.isNotEmpty) ...<pw.Widget>[
          _subheading(monthlyReportSummaryHeading),
          pw.Paragraph(text: pdfWords(pdfSafeText(report.summary))),
        ],
        if (a != null) ..._familySection(a, money),
        if (a != null) ..._habitsSection(a, money),
        if (report.insights.isNotEmpty) ...<pw.Widget>[
          _subheading(monthlyReportInsightsHeading),
          for (final i in report.insights) _bullet('•', i, _zadRed),
        ],
        if (a != null) ..._savingsSection(a, money),
        if (recs.isNotEmpty) _subheading(monthlyReportRecommendationsHeading),
        for (final r in recs.take(recs.length - lastRecs.length))
          _bullet('-', r, _good),
        // The last few pieces of advice share a row with the stamp, so the
        // stamp never lands alone on a page. Only a few: a Row cannot break
        // across pages, and a long list in it would never fit one.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  for (final r in lastRecs) _bullet('-', r, _good),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: _stamp(),
            ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

/// `1,250 ج.م` — Latin digits with grouping, cents only when there are any.
String formatReportMoney(double v, String currency) =>
    '${NumberFormat('#,##0.##', 'en').format(v)} $currency'.trim();

/// `37%`.
String formatReportPercent(double v) => '${(v * 100).round()}%';

// ── Building blocks ─────────────────────────────────────────────────────────

pw.Widget _text(
  String s, {
  double size = 11.5,
  PdfColor color = _body,
  pw.TextAlign? align,
}) => pw.Text(
  pdfWords(pdfSafeText(s)),
  textAlign: align,
  style: pw.TextStyle(fontSize: size, color: color),
);

pw.Widget _header(DateTime issuedOn, String cycle) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 14),
  padding: const pw.EdgeInsets.only(bottom: 8),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _zadRed, width: 2)),
  ),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: <pw.Widget>[
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            _text(monthlyReportTitle, size: 26, color: _zadRed),
            _text(monthlyReportIssuedLine(issuedOn), size: 10, color: _muted),
          ],
        ),
      ),
      if (cycle.isNotEmpty)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: pw.BoxDecoration(
            color: _zadRed,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: _text(cycle, size: 11, color: _white),
        ),
    ],
  ),
);

/// A numbered section title: red badge, title, hairline.
pw.Widget _sectionTitle(int n, String title) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 20, bottom: 10),
  padding: const pw.EdgeInsets.only(bottom: 6),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _hairline)),
  ),
  child: pw.Row(
    children: <pw.Widget>[
      pw.Container(
        width: 22,
        height: 22,
        alignment: pw.Alignment.center,
        decoration: const pw.BoxDecoration(
          color: _zadRed,
          shape: pw.BoxShape.circle,
        ),
        child: _text('$n', size: 11, color: _white),
      ),
      pw.SizedBox(width: 8),
      pw.Expanded(child: _text(title, size: 15)),
    ],
  ),
);

pw.Widget _subheading(String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
  child: _text(text, size: 13, color: _zadRed),
);

pw.Widget _chip(String text) => pw.Align(
  alignment: pw.Alignment.centerRight,
  child: pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _zadRed),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: _text(text, size: 11, color: _zadRed),
  ),
);

pw.Widget _bullet(String mark, String text, PdfColor color) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 4),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Text(mark, style: pw.TextStyle(color: color)),
      pw.SizedBox(width: 6),
      pw.Expanded(child: _text(text)),
    ],
  ),
);

/// A horizontal consumption bar, filled from the right. [value] is clamped
/// to 0..1; over 1 it is drawn full, in [over] when given.
pw.Widget _bar(
  double value,
  PdfColor color, {
  PdfColor? over,
  double height = 6,
}) => pw.Container(
  height: height,
  decoration: pw.BoxDecoration(
    color: _track,
    borderRadius: pw.BorderRadius.circular(height / 2),
  ),
  // A Row, not a fractional box (package:pdf has none): in this RTL page
  // the first child sits on the right, so the bar fills from the right.
  child: pw.Row(
    children: <pw.Widget>[
      if (_fill(value) > 0)
        pw.Expanded(
          flex: _fill(value),
          child: pw.Container(
            height: height,
            decoration: pw.BoxDecoration(
              color: value > 1 && over != null ? over : color,
              borderRadius: pw.BorderRadius.circular(height / 2),
            ),
          ),
        ),
      if (_fill(value) < 1000)
        pw.Expanded(flex: 1000 - _fill(value), child: pw.SizedBox()),
    ],
  ),
);

/// [v] clamped to 0..1, in thousandths.
int _fill(double v) => v.isNaN ? 0 : (v.clamp(0, 1) * 1000).round();

/// [_card] stretched to the page's width — a card in the page's column
/// otherwise shrinks to its text.
pw.Widget _fullWidth({
  required pw.Widget child,
  PdfColor background = _surface,
  PdfColor? accent,
}) => pw.Row(
  children: <pw.Widget>[
    pw.Expanded(
      child: _card(background: background, accent: accent, child: child),
    ),
  ],
);

pw.Widget _card({
  required pw.Widget child,
  PdfColor background = _surface,
  PdfColor? accent,
  pw.EdgeInsets padding = const pw.EdgeInsets.all(10),
}) => pw.Container(
  padding: padding,
  decoration: pw.BoxDecoration(
    color: background,
    borderRadius: pw.BorderRadius.circular(10),
    border: pw.Border.all(color: accent ?? _hairline, width: 0.8),
  ),
  child: child,
);

/// Lays [cards] out two per row.
List<pw.Widget> _grid(List<pw.Widget> cards) => <pw.Widget>[
  for (var i = 0; i < cards.length; i += 2)
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(child: cards[i]),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: i + 1 < cards.length ? cards[i + 1] : pw.SizedBox(),
          ),
        ],
      ),
    ),
];

// ── Overview ────────────────────────────────────────────────────────────────

List<pw.Widget> _overview(
  MonthlyAnalysis a,
  String health,
  String Function(double) money,
) {
  pw.Widget kpi(String label, String value, {pw.Widget? extra, PdfColor? c}) =>
      pw.Expanded(
        child: _card(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _text(label, size: 9, color: _muted),
              pw.SizedBox(height: 2),
              _text(value, size: 15, color: c ?? _body),
              if (extra != null) ...<pw.Widget>[pw.SizedBox(height: 5), extra],
            ],
          ),
        ),
      );
  final usage = a.usage;
  final usageColor = usage == null
      ? _muted
      : usage > 1
      ? _zadRed
      : usage > 0.85
      ? _warn
      : _good;
  final net = a.income - a.spent;
  return <pw.Widget>[
    pw.Row(
      children: <pw.Widget>[
        pw.Expanded(child: _text(monthlyReportOverviewHeading, size: 13)),
        if (health.isNotEmpty) _chip(health),
      ],
    ),
    pw.SizedBox(height: 8),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        kpi('إجمالي المصروف', money(a.spent)),
        pw.SizedBox(width: 8),
        kpi(
          'الدخل',
          money(a.income),
          extra: a.income <= 0
              ? null
              : _text(
                  net >= 0 ? 'فاضل ${money(net)}' : 'عجز ${money(-net)}',
                  size: 9,
                  color: net >= 0 ? _good : _zadRed,
                ),
        ),
        pw.SizedBox(width: 8),
        kpi(
          'استهلاك الميزانية',
          usage == null ? 'بدون ميزانية' : formatReportPercent(usage),
          c: usageColor,
          extra: usage == null ? null : _bar(usage, usageColor, over: _zadRed),
        ),
        pw.SizedBox(width: 8),
        kpi('عدد العمليات', '${a.count}'),
      ],
    ),
  ];
}

// ── 1. Family ───────────────────────────────────────────────────────────────

List<pw.Widget> _familySection(
  MonthlyAnalysis a,
  String Function(double) money,
) {
  pw.Widget card(GroupSpend g) {
    final (accent, tint) = _groupColors[g.group]!;
    return _card(
      background: tint,
      accent: accent,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            children: <pw.Widget>[
              pw.Container(
                width: 8,
                height: 8,
                decoration: pw.BoxDecoration(
                  color: accent,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(child: _text(g.group.label, size: 11, color: accent)),
            ],
          ),
          pw.SizedBox(height: 4),
          _text(money(g.total), size: 17),
          _text(
            '${formatReportPercent(g.share)} من المصروف · ${g.count} عملية',
            size: 9,
            color: _muted,
          ),
          pw.SizedBox(height: 6),
          _bar(g.share, accent),
          if (g.topItems.isEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 6),
            _text('مفيش مصاريف متسجلة هنا الشهر ده', size: 9, color: _muted),
          ] else ...<pw.Widget>[
            pw.SizedBox(height: 6),
            for (final (title, amount) in g.topItems)
              pw.Row(
                children: <pw.Widget>[
                  pw.Expanded(child: _text(title, size: 9.5)),
                  _text(money(amount), size: 9.5, color: _muted),
                ],
              ),
          ],
        ],
      ),
    );
  }

  return <pw.Widget>[
    _sectionTitle(1, monthlyReportFamilyHeading),
    ..._grid(<pw.Widget>[for (final g in a.family) card(g)]),
    if (a.otherSpend > 0)
      _text(
        'باقي المصاريف خارج البنود دي: ${money(a.otherSpend)} '
        '(${formatReportPercent(a.spent <= 0 ? 0 : a.otherSpend / a.spent)})',
        size: 9.5,
        color: _muted,
      ),
  ];
}

// ── 2. Habits ───────────────────────────────────────────────────────────────

List<pw.Widget> _habitsSection(
  MonthlyAnalysis a,
  String Function(double) money,
) {
  pw.Widget alert(String title, List<String> lines, {bool ok = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: _fullWidth(
          background: ok ? _goodTint : _warnTint,
          accent: ok ? _good : _warn,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              _text(title, size: 12, color: ok ? _good : _warn),
              pw.SizedBox(height: 3),
              for (final l in lines) _text(l, size: 10),
            ],
          ),
        ),
      );

  final t = a.transport;
  final s = a.small;
  final transportLine = t == null
      ? ''
      : 'المواصلات: ${money(t.total)} على ${t.trips} مشوار '
            '(${formatReportPercent(t.share)} من المصروف، متوسط المشوار '
            '${money(t.median)})';
  final smallLine = s == null
      ? ''
      : '${s.count} عملية كل واحدة ${money(s.threshold)} أو أقل، '
            'مجموعها ${money(s.total)} (${formatReportPercent(s.share)} '
            'من المصروف)';
  const allClear =
      'مالقيناش مشتريات مكررة ولا تنقلات مكلفة ولا مشتريات صغيرة '
      'متراكمة — كمّل كده.';
  return <pw.Widget>[
    _sectionTitle(2, monthlyReportHabitsHeading),
    if (a.duplicates.isNotEmpty)
      alert('مشتريات مكررة في نفس الأسبوع', <String>[
        for (final d in a.duplicates)
          '«${d.title}» — ${timesLabel(d.count)} بإجمالي ${money(d.total)}',
      ]),
    if (t != null && t.isCostly)
      alert('تنقلات مكلفة', <String>[
        transportLine,
        for (final (title, amount) in t.costlyTrips)
          'مشوار أغلى من المعتاد: «$title» بـ ${money(amount)}',
      ]),
    if (s != null) alert('مشتريات صغيرة بتتراكم', <String>[smallLine]),
    if (!a.hasHabitAlerts)
      alert('مفيش عادات مقلقة الشهر ده', <String>[allClear], ok: true),
    if (t != null && !t.isCostly)
      _text(
        'المواصلات في الحدود: ${money(t.total)} على ${t.trips} مشوار '
        '(${formatReportPercent(t.share)} من المصروف).',
        size: 9.5,
        color: _muted,
      ),
  ];
}

// ── 3. Savings ──────────────────────────────────────────────────────────────

List<pw.Widget> _savingsSection(
  MonthlyAnalysis a,
  String Function(double) money,
) {
  const flex = <int>[30, 17, 17, 12, 17, 14];
  pw.Widget row(
    List<pw.Widget> cells, {
    PdfColor? background,
    bool divider = true,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: pw.BoxDecoration(
      color: background,
      border: divider
          ? const pw.Border(bottom: pw.BorderSide(color: _hairline, width: 0.6))
          : null,
    ),
    child: pw.Row(
      children: <pw.Widget>[
        for (var i = 0; i < cells.length; i++)
          pw.Expanded(flex: flex[i], child: cells[i]),
      ],
    ),
  );
  pw.Widget head(String s) => _text(s, size: 9, color: _white);

  final steps = savingSteps(a, money);
  return <pw.Widget>[
    _sectionTitle(3, monthlyReportSavingsHeading),
    _fullWidth(
      background: _goodTint,
      accent: _good,
      child: pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                _text('التوفير المتوقع الشهر الجاي', size: 10, color: _good),
                _text(money(a.savings), size: 20, color: _good),
              ],
            ),
          ),
          pw.SizedBox(
            width: 190,
            child: _text(
              'لو التزمت بسقف كل بند في الجدول، من غير ما نقرب من '
              'الأساسيات (الدواء، الفواتير، الإيجار، الأقساط، المدارس).',
              size: 9,
              color: _muted,
            ),
          ),
        ],
      ),
    ),
    _subheading(monthlyReportTableHeading),
    if (a.lines.isEmpty)
      _text('مفيش بنود كفاية للمقارنة الشهر ده.', size: 10, color: _muted)
    else ...<pw.Widget>[
      pw.Container(
        decoration: const pw.BoxDecoration(
          color: _tableHead,
          borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(8)),
        ),
        child: row(<pw.Widget>[
          head('البند'),
          head('الشهر ده'),
          head('الشهر اللي فات'),
          head('التغيير'),
          head('السقف المقترح'),
          head('التوفير'),
        ], divider: false),
      ),
      for (var i = 0; i < a.lines.length; i++)
        () {
          final l = a.lines[i];
          final change = l.change;
          return row(<pw.Widget>[
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                _text(l.category, size: 10),
                if (l.essential) _text('أساسي', size: 8, color: _good),
                pw.SizedBox(height: 3),
                _bar(
                  a.spent <= 0 ? 0 : l.current / a.spent,
                  _zadRed,
                  height: 3,
                ),
              ],
            ),
            _text(money(l.current), size: 10),
            _text(
              l.previous > 0 ? money(l.previous) : '—',
              size: 10,
              color: _muted,
            ),
            _text(
              change == null
                  ? 'جديد'
                  : change.abs() < 0.005
                  ? 'ثابت'
                  : '${change >= 0 ? '+' : '-'}'
                        '${formatReportPercent(change.abs())}',
              size: 10,
              color: change == null
                  ? _muted
                  : change > 0.05
                  ? _zadRed
                  : change < -0.05
                  ? _good
                  : _muted,
            ),
            _text(money(l.cap), size: 10, color: _good),
            _text(l.saving > 0 ? money(l.saving) : '—', size: 10),
          ], background: i.isOdd ? _surface : null);
        }(),
    ],
    if (steps.isNotEmpty) ...<pw.Widget>[
      _subheading('خطوات عملية للشهر الجاي'),
      for (final s in steps) _bullet('-', s, _good),
    ],
  ];
}

/// Kotlin's stamp: two red rings, «زاد» over «معتمد من عقل زاد», tilted.
pw.Widget _stamp() {
  const size = 104.0;
  const ring = PdfColor(0.776, 0.157, 0.157, 0.8);
  return pw.Transform.rotate(
    angle: 14 * math.pi / 180,
    child: pw.SizedBox.square(
      dimension: size,
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: <pw.Widget>[
          pw.Container(
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: ring, width: 3),
            ),
          ),
          pw.Container(
            margin: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: ring, width: 3),
            ),
          ),
          pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: <pw.Widget>[
              pw.Text(
                pdfWords(monthlyReportStampMark),
                style: const pw.TextStyle(fontSize: 20, color: ring),
              ),
              pw.Text(
                pdfWords(monthlyReportStampCaption),
                style: const pw.TextStyle(fontSize: 8, color: ring),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Drops what Cairo has no glyph for — emoji, their joiners and variation
/// selectors, and the dingbat/symbol blocks the model likes to sprinkle in —
/// so the PDF shows clean text instead of empty boxes.
String pdfSafeText(String text) {
  final out = StringBuffer();
  for (final r in text.runes) {
    final drop =
        r > 0xFFFF ||
        (r >= 0x2600 && r <= 0x27BF) ||
        (r >= 0x2B00 && r <= 0x2BFF) ||
        (r >= 0xFE00 && r <= 0xFE0F) ||
        r == 0x200D ||
        r == 0x20E3;
    if (!drop) out.writeCharCode(r);
  }
  return out.toString().replaceAll(RegExp(' {2,}'), ' ').trim();
}

/// Brackets every word with U+200C, the empty zero-width glyph `cairo_pdf.ttf`
/// carries, so `package:pdf`'s right-to-left mirroring sees no side bearing at
/// either end of a word. Spaces and line breaks are kept as they are.
String pdfWords(String text) =>
    text.replaceAllMapped(RegExp(r'[^\s]+'), (m) => '\u200C${m[0]}\u200C');
