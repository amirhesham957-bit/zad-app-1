import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
// The library's own font parser, to check the glyphs it will look up.
import 'package:pdf/src/pdf/font/ttf_parser.dart';
import 'package:zad/features/intelligence/data/monthly_report_pdf.dart';
import 'package:zad/features/intelligence/domain/monthly_analysis.dart';
import 'package:zad/features/intelligence/domain/monthly_report.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

import 'sample_month.dart';

ByteData _cairo() =>
    ByteData.sublistView(File(monthlyReportFontAsset).readAsBytesSync());

/// Pages in a `package:pdf` document: one `/Type /Page` object each.
int _pages(Uint8List pdf) =>
    RegExp(r'/Type\s*/Page(?!s)').allMatches(String.fromCharCodes(pdf)).length;

const MonthlyReport _report = MonthlyReport(
  summary: 'صرفت 70٪ من ميزانيتك في أول أسبوعين.',
  insights: <String>['الأكل برا هو أكبر بند 🍔', 'المواصلات ثابتة'],
  recommendations: <String>['حدد سقف للأكل برا'],
  health: 'متوازن ✅',
);

void main() {
  group('titles', () {
    test('match Kotlin ZadReportPdfBuilder', () {
      expect(monthlyReportTitle, 'تقرير زاد الشهري');
      expect(monthlyReportShareSubject, 'تقرير زاد المالي');
      expect(monthlyReportStampMark, 'زاد');
      expect(monthlyReportStampCaption, 'معتمد من عقل زاد');
      expect(monthlyReportSummaryHeading, 'الملخص');
      expect(monthlyReportInsightsHeading, 'ملاحظات زاد');
      expect(monthlyReportRecommendationsHeading, 'نصايح زاد');
    });

    test('the strategic report section titles', () {
      expect(monthlyReportOverviewHeading, 'نظرة عامة على الشهر');
      expect(monthlyReportFamilyHeading, 'تفكيك مصاريف الأسرة والأطفال');
      expect(
        monthlyReportHabitsHeading,
        'رصد العادات المالية الخاطئة وتنبيهات الاستهلاك',
      );
      expect(monthlyReportSavingsHeading, 'نصائح زاد الذكية وتوصيات التوفير');
      expect(
        monthlyReportTableHeading,
        'مقارنة البنود والسقف المقترح للشهر الجاي',
      );
    });

    test('issued line carries d/m/yyyy, unpadded', () {
      expect(
        monthlyReportIssuedLine(DateTime(2026, 9, 7)),
        'صادر بتاريخ 7/9/2026 — تحليل عقل زاد لسلوكك المالي',
      );
    });

    test('file name is zad_report_yyyyMMdd.pdf, padded', () {
      expect(
        monthlyReportFileName(DateTime(2026, 9, 7)),
        'zad_report_20260907.pdf',
      );
      expect(
        monthlyReportFileName(DateTime(2026, 12, 31)),
        'zad_report_20261231.pdf',
      );
    });
  });

  group('MonthlyReport.fromResponse', () {
    test('reads every field and trims', () {
      final r = MonthlyReport.fromResponse(<String, dynamic>{
        'summary': ' ملخص ',
        'insights': <dynamic>['أ', ' ', 3, 'ب'],
        'recommendations': <dynamic>['ج'],
        'health_label': 'ممتاز',
      });
      expect(r.summary, 'ملخص');
      expect(r.insights, <String>['أ', 'ب']);
      expect(r.recommendations, <String>['ج']);
      expect(r.health, 'ممتاز');
    });

    test('missing or mistyped fields read as empty', () {
      final r = MonthlyReport.fromResponse(<String, dynamic>{
        'summary': 5,
        'insights': 'not a list',
      });
      expect(r.summary, isEmpty);
      expect(r.insights, isEmpty);
      expect(r.recommendations, isEmpty);
      expect(r.health, isEmpty);
    });

    test('a non-map is not a report', () {
      expect(() => MonthlyReport.fromResponse('oops'), throwsStateError);
      expect(() => MonthlyReport.fromResponse(null), throwsStateError);
    });
  });

  group('toShareText', () {
    test('uses the new section titles', () {
      expect(
        _report.toShareText(),
        'تقرير زاد الشهري — متوازن ✅\n\n'
        'صرفت 70٪ من ميزانيتك في أول أسبوعين.\n\n'
        'ملاحظات زاد\n• الأكل برا هو أكبر بند 🍔\n• المواصلات ثابتة\n\n'
        'نصايح زاد\n✓ حدد سقف للأكل برا',
      );
    });

    test('empty sections leave no heading behind', () {
      const r = MonthlyReport(
        summary: 'بس ملخص',
        insights: <String>[],
        recommendations: <String>[],
        health: '',
      );
      expect(r.toShareText(), 'تقرير زاد الشهري\n\nبس ملخص');
    });
  });

  group('pdfSafeText', () {
    test('drops emoji, joiners and dingbats Cairo cannot draw', () {
      expect(pdfSafeText('متوازن ✅'), 'متوازن');
      expect(pdfSafeText('أكل 🍔 برا'), 'أكل برا');
      expect(pdfSafeText('عيلة 👨‍👩‍👧 سعيدة'), 'عيلة سعيدة');
      expect(pdfSafeText('❤️ شكراً'), 'شكراً');
    });

    test('keeps Arabic, digits and punctuation', () {
      const s = 'صرفت ٧٠٪ (1,250.50 ج.م) — كويس!';
      expect(pdfSafeText(s), s);
    });
  });

  group('formatting', () {
    test('money: grouped Latin digits, cents only when present', () {
      expect(formatReportMoney(1250, 'ج.م'), '1,250 ج.م');
      expect(formatReportMoney(102.5, 'ر.س'), '102.5 ر.س');
      expect(formatReportMoney(40, ''), '40');
    });

    test('percent rounds', () {
      expect(formatReportPercent(0.9765), '98%');
      expect(formatReportPercent(0), '0%');
    });
  });

  group('pdfWords', () {
    test('brackets every word with U+200C and keeps the spaces', () {
      expect(
        pdfWords('تقرير زاد\nالشهري'),
        '\u200Cتقرير\u200C \u200Cزاد\u200C\n\u200Cالشهري\u200C',
      );
      expect(pdfWords(''), '');
    });
  });

  group('cairo_pdf.ttf', () {
    // The two things tool/make_pdf_font.py adds, read back through the same
    // parser package:pdf draws with. If the font is regenerated without
    // them, «ي» alone and the word spacing break silently.
    final font = TtfParser(_cairo());

    test('has its own glyph for the isolated yeh', () {
      expect(font.charToGlyphIndexMap[0xFEF1], isNotNull);
      expect(
        font.charToGlyphIndexMap[0xFEF1],
        font.charToGlyphIndexMap[0x064A],
      );
    });

    test('carries an empty, zero-width U+200C', () {
      final g = font.charToGlyphIndexMap[0x200C];
      expect(g, isNotNull);
      final m = font.glyphInfoMap[g]!;
      expect(m.advanceWidth, 0);
      expect(m.width, 0);
    });
  });

  group('buildMonthlyReportPdf', () {
    test('writes a one-page PDF with the bundled Cairo font', () async {
      final bytes = await buildMonthlyReportPdf(
        _report,
        font: _cairo(),
        issuedOn: DateTime(2026, 9, 27),
        cycle: 'سبتمبر 2026',
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(_pages(bytes), 1);
      expect(bytes.length, greaterThan(1000));
    });

    test('a long report flows onto more pages', () async {
      final long = MonthlyReport(
        summary: List<String>.filled(
          40,
          'جملة طويلة عن مصروفات الشهر.',
        ).join(' '),
        insights: List<String>.generate(60, (i) => 'ملاحظة رقم $i عن الصرف'),
        recommendations: List<String>.generate(30, (i) => 'نصيحة رقم $i'),
        health: 'محتاج انتباه',
      );
      final bytes = await buildMonthlyReportPdf(
        long,
        font: _cairo(),
        issuedOn: DateTime(2026, 9, 27),
      );
      expect(_pages(bytes), greaterThan(1));
    });

    test('with the analysis: all three sections, over several pages', () async {
      final bytes = await buildMonthlyReportPdf(
        _report,
        font: _cairo(),
        issuedOn: DateTime(2026, 9, 27),
        cycle: 'سبتمبر 2026',
        currency: 'ج.م',
        analysis: analyzeMonth(
          transactions: sampleMonth(),
          start: sampleStart,
          end: sampleEnd,
          budget: 20000,
        ),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(_pages(bytes), inInclusiveRange(2, 4));
    });

    test('with an empty month: still builds, no division by zero', () async {
      final bytes = await buildMonthlyReportPdf(
        _report,
        font: _cairo(),
        issuedOn: DateTime(2026, 9, 27),
        analysis: analyzeMonth(
          transactions: const <ZadTransaction>[],
          start: sampleStart,
          end: sampleEnd,
        ),
      );
      expect(_pages(bytes), greaterThanOrEqualTo(1));
    });

    test('an empty report still builds (title and stamp only)', () async {
      final bytes = await buildMonthlyReportPdf(
        const MonthlyReport(
          summary: '',
          insights: <String>[],
          recommendations: <String>[],
          health: '',
        ),
        font: _cairo(),
        issuedOn: DateTime(2026, 9, 27),
      );
      expect(_pages(bytes), 1);
    });
  });
}
