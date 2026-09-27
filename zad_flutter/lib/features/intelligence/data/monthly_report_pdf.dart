/// Kotlin's `ZadReportPdfBuilder`: the monthly report as an A4 PDF with a red
/// title, the issue date, a rule under the header, the report's sections, and
/// the round «معتمد من عقل زاد» stamp after the last line.
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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:zad/features/intelligence/domain/monthly_report.dart';

/// The bundled font the PDF is drawn with.
const String monthlyReportFontAsset = 'assets/fonts/cairo_pdf.ttf';

const PdfColor _zadRed = PdfColor.fromInt(0xFFC62828);
const PdfColor _body = PdfColor.fromInt(0xFF1E1E1E);
const PdfColor _muted = PdfColor.fromInt(0xFF5A5A5A);

/// Builds the PDF. [cycle] is the budget cycle's month label (`سبتمبر 2026`),
/// shown under the title when given.
Future<Uint8List> buildMonthlyReportPdf(
  MonthlyReport report, {
  required ByteData font,
  required DateTime issuedOn,
  String cycle = '',
}) {
  final base = pw.Font.ttf(font);
  final doc = pw.Document(title: monthlyReportTitle, author: 'زاد');

  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
    child: pw.Text(
      pdfWords(text),
      style: const pw.TextStyle(fontSize: 15, color: _zadRed),
    ),
  );

  pw.Widget bullet(String mark, String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(mark, style: const pw.TextStyle(color: _zadRed)),
        pw.SizedBox(width: 6),
        pw.Expanded(child: pw.Text(pdfWords(pdfSafeText(text)))),
      ],
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: base).copyWith(
        paragraphStyle: const pw.TextStyle(
          fontSize: 13,
          color: _body,
          lineSpacing: 4,
        ),
        defaultTextStyle: const pw.TextStyle(fontSize: 13, color: _body),
      ),
      header: (context) => context.pageNumber != 1
          ? pw.SizedBox()
          : pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _zadRed, width: 2),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    pdfWords(monthlyReportTitle),
                    style: const pw.TextStyle(fontSize: 26, color: _zadRed),
                  ),
                  pw.Text(
                    pdfWords(monthlyReportIssuedLine(issuedOn)),
                    style: const pw.TextStyle(fontSize: 12, color: _muted),
                  ),
                  if (cycle.isNotEmpty)
                    pw.Text(
                      pdfWords(cycle),
                      style: const pw.TextStyle(fontSize: 12, color: _muted),
                    ),
                ],
              ),
            ),
      footer: (context) => pw.Align(
        child: pw.Text(
          pdfWords('صفحة ${context.pageNumber} من ${context.pagesCount}'),
          style: const pw.TextStyle(fontSize: 10, color: _muted),
        ),
      ),
      build: (context) => <pw.Widget>[
        if (report.health.isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _zadRed),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              pdfWords(pdfSafeText(report.health)),
              style: const pw.TextStyle(color: _zadRed),
            ),
          ),
        if (report.summary.isNotEmpty) ...<pw.Widget>[
          heading(monthlyReportSummaryHeading),
          pw.Paragraph(text: pdfWords(pdfSafeText(report.summary))),
        ],
        if (report.insights.isNotEmpty) ...<pw.Widget>[
          heading(monthlyReportInsightsHeading),
          for (final i in report.insights) bullet('•', i),
        ],
        if (report.recommendations.isNotEmpty) ...<pw.Widget>[
          heading(monthlyReportRecommendationsHeading),
          for (final r in report.recommendations) bullet('-', r),
        ],
        pw.SizedBox(height: 24),
        pw.Align(alignment: pw.Alignment.centerLeft, child: _stamp()),
      ],
    ),
  );
  return doc.save();
}

/// Kotlin's stamp: two red rings, «زاد» over «معتمد من عقل زاد», tilted.
pw.Widget _stamp() {
  const size = 110.0;
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
                style: const pw.TextStyle(fontSize: 9, color: ring),
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
