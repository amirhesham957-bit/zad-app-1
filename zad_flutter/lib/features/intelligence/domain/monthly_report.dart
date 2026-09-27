/// The AI monthly report `zad-core-intelligence`'s `monthly_expense_report`
/// returns, and the titles every rendering of it shares — the card, the shared
/// text and the PDF (Kotlin's `ZadReportPdfBuilder`) all read them from here,
/// so a renamed heading changes in one place.
library;

/// The PDF's title — Kotlin's header line.
const String monthlyReportTitle = 'تقرير زاد الشهري';

/// The share sheet's subject.
const String monthlyReportShareSubject = 'تقرير زاد المالي';

/// The summary section's heading.
const String monthlyReportSummaryHeading = 'الملخص';

/// The insights section's heading.
const String monthlyReportInsightsHeading = 'ملاحظات زاد';

/// The recommendations section's heading — also the card's.
const String monthlyReportRecommendationsHeading = 'نصايح زاد';

/// The big word in the red stamp on the last page.
const String monthlyReportStampMark = 'زاد';

/// The stamp's small line.
const String monthlyReportStampCaption = 'معتمد من عقل زاد';

/// The line under the title: `صادر بتاريخ d/m/yyyy — …`, Kotlin's wording.
String monthlyReportIssuedLine(DateTime issuedOn) =>
    'صادر بتاريخ ${issuedOn.day}/${issuedOn.month}/${issuedOn.year}'
    ' — تحليل عقل زاد لسلوكك المالي';

/// `zad_report_yyyyMMdd.pdf`, Kotlin's file name.
String monthlyReportFileName(DateTime issuedOn) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'zad_report_${issuedOn.year}${two(issuedOn.month)}'
      '${two(issuedOn.day)}.pdf';
}

/// One generated report.
class MonthlyReport {
  /// A report from its parts.
  const new({
    required this.summary,
    required this.insights,
    required this.recommendations,
    required this.health,
  });

  /// Reads the function's JSON. Missing or mistyped fields read as empty;
  /// anything other than a map is not a report and throws.
  factory fromResponse(Object? data) {
    if (data is! Map) {
      throw StateError('monthly_expense_report: ${data.runtimeType}');
    }
    List<String> strings(Object? v) => <String>[
      if (v is List)
        for (final s in v)
          if (s is String && s.trim().isNotEmpty) s.trim(),
    ];
    String text(Object? v) => v is String ? v.trim() : '';
    return MonthlyReport(
      summary: text(data['summary']),
      insights: strings(data['insights']),
      recommendations: strings(data['recommendations']),
      health: text(data['health_label']),
    );
  }

  /// The model's paragraph on the month.
  final String summary;

  /// What it noticed, one line each.
  final List<String> insights;

  /// What it advises, one line each.
  final List<String> recommendations;

  /// The short health label (`health_label`), shown as a chip.
  final String health;

  /// The report as plain text, for the share sheet's body.
  String toShareText() {
    final b = StringBuffer(monthlyReportTitle);
    if (health.isNotEmpty) b.write(' — $health');
    if (summary.isNotEmpty) b.write('\n\n$summary');
    if (insights.isNotEmpty) {
      b.write('\n\n$monthlyReportInsightsHeading');
      for (final i in insights) {
        b.write('\n• $i');
      }
    }
    if (recommendations.isNotEmpty) {
      b.write('\n\n$monthlyReportRecommendationsHeading');
      for (final r in recommendations) {
        b.write('\n✓ $r');
      }
    }
    return b.toString();
  }
}
