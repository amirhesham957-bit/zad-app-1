/// Kotlin's `ZadReportPdfBuilder`: the monthly report as an A4 PDF — the red
/// «تقرير زاد الشهري» header with its date line and rule, the report text at
/// 13pt right to left, and the red round «زاد — معتمد من عقل زاد» stamp,
/// tilted −14°, on the last page. Same content as `buildExportText`.
///
/// The one difference is the emoji: Android's PDF canvas falls back to the
/// system's emoji font, the PDF here embeds Cairo alone, so the emoji are
/// left out of the file rather than printed as empty boxes.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const PdfColor _red = PdfColor.fromInt(0xFFC62828);

final RegExp _emoji = RegExp(
  '[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{2550}]',
  unicode: true,
);

/// Writes the PDF for [text] and returns the file.
Future<File> buildReportPdf(String text, {required DateTime today}) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/cairo_variable.ttf'),
  );
  final body = text
      .replaceAll(_emoji, '')
      .split('\n')
      .map((l) => l.trimRight())
      .toList();
  final stampRed = PdfColor(_red.red, _red.green, _red.blue, 200 / 255);

  final doc = pw.Document()
    ..addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginLeft: 40,
            marginRight: 40,
            marginTop: 40,
            marginBottom: 40,
          ),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: font, bold: font),
          buildForeground: (context) => context.pageNumber == context.pagesCount
              ? pw.Positioned(
                  right: 40 + 60 - 55,
                  bottom: 40 + 70 - 55,
                  child: pw.Transform.rotate(
                    angle: 14 * math.pi / 180,
                    child: pw.Container(
                      width: 110,
                      height: 110,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: stampRed, width: 3),
                      ),
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: stampRed, width: 3),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: <pw.Widget>[
                            pw.Text(
                              'زاد',
                              style: pw.TextStyle(
                                fontSize: 20,
                                color: stampRed,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'معتمد من عقل زاد',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: stampRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : pw.SizedBox(),
        ),
        header: (context) => context.pageNumber != 1
            ? pw.SizedBox()
            : pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: <pw.Widget>[
                  pw.Text(
                    'تقرير زاد الشهري',
                    style: const pw.TextStyle(
                      fontSize: 26,
                      color: _red,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'صادر بتاريخ ${today.day}/${today.month}/${today.year} — '
                    'تحليل عقل زاد لسلوكك المالي',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColor.fromInt(0xFF5A5A5A),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(color: _red, thickness: 2, height: 2),
                  pw.SizedBox(height: 12),
                ],
              ),
        build: (context) => <pw.Widget>[
          for (final line in body)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                line.isEmpty ? ' ' : line,
                style: const pw.TextStyle(
                  fontSize: 13,
                  lineSpacing: 1.1,
                  color: PdfColor.fromInt(0xFF1E1E1E),
                ),
              ),
            ),
        ],
      ),
    );

  final dir = Directory('${(await getTemporaryDirectory()).path}/reports');
  await dir.create(recursive: true);
  final stamp =
      '${today.year}${today.month.toString().padLeft(2, '0')}'
      '${today.day.toString().padLeft(2, '0')}';
  final file = File('${dir.path}/zad_report_$stamp.pdf');
  await file.writeAsBytes(await doc.save());
  return file;
}
