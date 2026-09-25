/// Kotlin's `LeaderboardShareCard`: «بستان عيلتنا» as a 1080×1350 image —
/// the top five by score with medal and streak, brand gradient, the family's
/// own aliases only — shared with the invite line.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/features/tasbiha/domain/tasbiha.dart';

const double _w = 1080;
const double _h = 1350;
const Color _mint = Color(0xFF6EE7B7);
const Color _gold = Color(0xFFE9A844);

double _text(
  Canvas canvas,
  String value, {
  required double size,
  required Color color,
  required bool bold,
  required double x,
  required double y,
  required double width,
  TextAlign align = TextAlign.right,
}) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textDirection: TextDirection.rtl,
            textAlign: align,
            fontFamily: 'Cairo',
          ),
        )
        ..pushStyle(
          ui.TextStyle(
            color: color,
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        )
        ..addText(value);
  final p = builder.build()..layout(ui.ParagraphConstraints(width: width));
  canvas.drawParagraph(p, Offset(x, y));
  return p.height;
}

/// Renders the card as PNG bytes.
Future<List<int>> renderLeaderboard(List<MemberGarden> gardens) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, _w, _h))
    ..drawRect(
      const Rect.fromLTWH(0, 0, _w, _h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[ZadColors.forestEmerald, ZadColors.emeraldDeep],
        ).createShader(const Rect.fromLTWH(0, 0, _w, _h)),
    )
    ..drawCircle(
      const Offset(_w * 0.15, _h * 0.06),
      300,
      Paint()..color = _mint.withValues(alpha: 0.1),
    );

  const margin = 96.0;
  const full = _w - margin * 2;
  var y = 130.0;
  y +=
      _text(
        canvas,
        '🌳 بستان عيلتنا',
        size: 64,
        color: Colors.white,
        bold: true,
        x: margin,
        y: y,
        width: full,
      ) +
      16;
  y +=
      _text(
        canvas,
        'ترتيب التسبيح في العيلة',
        size: 36,
        color: Colors.white,
        bold: false,
        x: margin,
        y: y,
        width: full,
      ) +
      72;

  for (final (i, g) in gardens.take(5).indexed) {
    final rank = i + 1;
    final alias = g.member.alias.trim().isEmpty ? '—' : g.member.alias.trim();
    final name = alias.length > 24 ? alias.substring(0, 24) : alias;
    final streak = longestStreak(g.trees);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(margin - 24, y, _w - margin + 24, y + 150),
        const Radius.circular(40),
      ),
      Paint()
        ..color = rank == 1
            ? _gold.withValues(alpha: 0.24)
            : Colors.white.withValues(alpha: 0.09),
    );
    const nameWidth = full * 0.62;
    _text(
      canvas,
      '${medal(rank)}  $name',
      size: 50,
      color: Colors.white,
      bold: true,
      x: _w - margin - nameWidth,
      y: y + 22,
      width: nameWidth,
    );
    if (streak > 0) {
      _text(
        canvas,
        '🔥 $streak يوم ورا بعض',
        size: 32,
        color: _mint,
        bold: false,
        x: _w - margin - nameWidth,
        y: y + 88,
        width: nameWidth,
      );
    }
    _text(
      canvas,
      '${g.totalScore}',
      size: 60,
      color: rank == 1 ? _gold : Colors.white,
      bold: true,
      x: margin,
      y: y + 40,
      width: full * 0.34,
      align: TextAlign.left,
    );
    y += 174;
  }

  _text(
    canvas,
    'مين هيسبقنا الأسبوع ده؟',
    size: 44,
    color: _mint,
    bold: true,
    x: margin,
    y: _h - 190,
    width: full,
  );
  _text(
    canvas,
    'نزّل زاد وجرّب أسبوع معاها',
    size: 32,
    color: Colors.white,
    bold: false,
    x: margin,
    y: _h - 120,
    width: full,
  );

  final image = await recorder.endRecording().toImage(_w.toInt(), _h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Shares the card.
Future<void> shareLeaderboard(List<MemberGarden> gardens) async {
  final bytes = await renderLeaderboard(gardens);
  await SharePlus.instance.share(
    ShareParams(
      text: 'مين هيسبقنا الأسبوع ده؟',
      subject: 'شارك الترتيب',
      files: <XFile>[
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: 'image/png',
          name: 'zad_leaderboard.png',
        ),
      ],
      fileNameOverrides: const <String>['zad_leaderboard.png'],
    ),
  );
}
