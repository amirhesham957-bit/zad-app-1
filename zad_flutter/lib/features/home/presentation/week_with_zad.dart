/// Kotlin's «أسبوعك مع زاد»: `WeekSummaryMath` (`data/WeekSummary.kt`), the
/// home card `WeekWithZadCard`, and the shared image `WeeklyShareCard`.
///
/// The shared image carries no amount on purpose — the change against last
/// week, the top category and the streaks only. People share an achievement,
/// not a statement.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_palette.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/modes/application/modes_controller.dart';
import 'package:zad/features/tasbiha/application/tasbiha_controller.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// Kotlin's `WeekSummary.Tone`.
enum WeekTone {
  /// A week to be proud of.
  proud,

  /// Next week will be better.
  reproach,

  /// Step by step.
  neutral,
}

/// Kotlin's `WeekSummary`.
@immutable
class WeekSummary {
  /// Creates a summary.
  const new({
    required this.spent,
    required this.lastWeekSpent,
    required this.changePct,
    required this.topCategory,
    required this.tone,
  });

  /// This week's spending.
  final double spent;

  /// Last week's.
  final double lastWeekSpent;

  /// Negative = less. Null = no previous week to compare with.
  final int? changePct;

  /// Where most of it went.
  final String? topCategory;

  /// The tone of the shared image.
  final WeekTone tone;
}

/// Kotlin's `WeekSummaryMath.summarize`. Null when nothing was spent this
/// week.
WeekSummary? summarizeWeek(
  List<ZadTransaction> transactions,
  DateTime now,
  double? monthlyLimit,
) {
  final weekAgo = now.subtract(const Duration(days: 7));
  final twoWeeksAgo = now.subtract(const Duration(days: 14));
  final expenses = transactions.where(
    (t) =>
        t.kind == TxnKind.expense &&
        t.countsTowardBudget &&
        !t.createdAt.isBefore(twoWeeksAgo) &&
        t.createdAt.isBefore(now),
  );
  final thisWeek = expenses.where((t) => !t.createdAt.isBefore(weekAgo));
  final lastWeek = expenses.where((t) => t.createdAt.isBefore(weekAgo));
  final spent = thisWeek
      .fold<double>(0, (s, t) => s + t.amount.abs())
      .roundToDouble();
  if (spent <= 0) return null;
  final last = lastWeek
      .fold<double>(0, (s, t) => s + t.amount.abs())
      .roundToDouble();

  final byCategory = <String, double>{};
  for (final t in thisWeek) {
    final c = t.category?.trim();
    if (c == null || c.isEmpty) continue;
    byCategory[c] = (byCategory[c] ?? 0) + t.amount.abs();
  }
  String? top;
  for (final e in byCategory.entries) {
    if (top == null || e.value > byCategory[top]!) top = e.key;
  }

  final weeklyBudget = monthlyLimit != null && monthlyLimit > 0
      ? (monthlyLimit * 7 / 30).roundToDouble()
      : null;
  final changePct = last > 0 ? ((spent - last) / last * 100).round() : null;

  final lessThanLast = last > 0 && spent <= last * 0.9;
  final muchMore = last > 0 && spent >= last * 1.15;
  final underBudget = weeklyBudget != null && spent <= weeklyBudget * 0.85;
  final overBudget = weeklyBudget != null && spent > weeklyBudget * 1.05;
  final tone = muchMore || overBudget
      ? WeekTone.reproach
      : lessThanLast || underBudget
      ? WeekTone.proud
      : WeekTone.neutral;
  return WeekSummary(
    spent: spent,
    lastWeekSpent: last,
    changePct: changePct,
    topCategory: top,
    tone: tone,
  );
}

String _headline(int? pct) => pct == null
    ? 'أول أسبوع مع زاد'
    : pct < 0
    ? 'صرفت أقل بـ ${-pct}٪ من الأسبوع اللي فات'
    : pct > 0
    ? 'صرفت أكتر بـ $pct٪ من الأسبوع اللي فات'
    : 'نفس صرف الأسبوع اللي فات بالظبط';

/// The week, from every cached transaction — Kotlin summarises the whole
/// local list, not one budget period.
final weekSummaryProvider = Provider<WeekSummary?>((ref) {
  // Rebuilt whenever the budget refreshes, which is when new rows land.
  final snapshot = ref.watch(budgetControllerProvider).snapshot;
  final rows = ref.read(transactionsRepositoryProvider).allCached();
  final limit = snapshot != null && snapshot.limitConfirmed
      ? snapshot.openingBalance
      : null;
  return summarizeWeek(rows, ref.read(nowProvider)(), limit);
});

/// The home card, or nothing.
class WeekWithZadSlot extends ConsumerWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weekSummaryProvider);
    if (week == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: WeekWithZadCard(
        week: week,
        onShare: () {
          final challenge = ref.read(modesControllerProvider).challenge;
          final tree = ref.read(tasbihaControllerProvider).myTrees.firstOrNull;
          unawaited(
            shareWeek(
              week,
              challengeStreak: challenge?.streak,
              tasbihaStreak: tree?.streakDays,
            ),
          );
        },
      ),
    );
  }
}

/// Kotlin's `WeekWithZadCard`: a dark panel in both themes.
class WeekWithZadCard extends StatelessWidget {
  /// Creates the card.
  const new({required this.week, required this.onShare, super.key});

  /// The week.
  final WeekSummary week;

  /// شارك أسبوعك.
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final pct = week.changePct;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZadPalette.darkPanelBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'أسبوعي مع زاد',
                  style: ZadType.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ZadPalette.darkPanelAccent,
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: onShare,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: const StadiumBorder(),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.share, size: 18),
                    SizedBox(width: 8),
                    Text('شارك أسبوعك'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _headline(pct),
            style: ZadType.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: pct != null && pct > 0
                  ? ZadPalette.darkPanelWarning
                  : Colors.white,
            ),
          ),
          if (week.topCategory case final top?) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'أكتر حاجة صرفت عليها: $top',
              style: ZadType.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const double _w = 1080;
const double _h = 1350;

double _text(
  Canvas canvas,
  String value, {
  required double size,
  required Color color,
  required double y,
  bool bold = false,
}) {
  const margin = 96.0;
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.start,
            height: 1.1,
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
  final p = builder.build()
    ..layout(const ui.ParagraphConstraints(width: _w - margin * 2));
  canvas.drawParagraph(p, Offset(margin, y));
  return p.height;
}

/// Kotlin's `WeeklyShareCard.render`: 1080×1350, a post's size.
Future<Uint8List> renderWeek(
  WeekSummary week, {
  int? challengeStreak,
  int? tasbihaStreak,
}) async {
  const white = Colors.white;
  const mint = ZadPalette.emeraldOnDark;
  const mustard = ZadPalette.mustardLight;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, _w, _h))
    ..drawRect(
      const Rect.fromLTWH(0, 0, _w, _h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(_w, _h),
          const <Color>[ZadPalette.forestEmeraldDark, ZadPalette.forestEmerald],
        ),
    );
  final glow = Paint()..color = mint.withAlpha(28);
  canvas
    ..drawCircle(const Offset(_w * 0.9, _h * 0.08), 320, glow)
    ..drawCircle(const Offset(_w * 0.05, _h * 0.95), 260, glow);

  var y = 140.0;
  y +=
      _text(canvas, 'أسبوعي مع زاد', size: 64, color: white, y: y, bold: true) +
      12;
  y +=
      _text(
        canvas,
        'ملخص الصرف والعادات — من غير أرقام',
        size: 36,
        color: white.withAlpha(180),
        y: y,
      ) +
      72;
  final pct = week.changePct;
  y +=
      _text(
        canvas,
        _headline(pct),
        size: 88,
        color: pct != null && pct > 0 ? mustard : mint,
        y: y,
        bold: true,
      ) +
      48;
  final tone = switch (week.tone) {
    WeekTone.proud => 'أسبوع يستاهل فخر 🏆',
    WeekTone.reproach => 'الأسبوع الجاي هيبقى أحسن 💪',
    WeekTone.neutral => 'خطوة خطوة 🌿',
  };
  y += _text(canvas, tone, size: 48, color: white, y: y) + 64;

  final rows = <String>[
    if (week.topCategory case final top?) 'أكتر حاجة صرفت عليها: $top',
    if (challengeStreak != null && challengeStreak > 0)
      '🔥 تحدي التوفير: $challengeStreak يوم ورا بعض',
    if (tasbihaStreak != null && tasbihaStreak > 0)
      '🌱 التسبيح: $tasbihaStreak يوم ورا بعض',
  ];
  final card = Paint()..color = white.withAlpha(26);
  for (final row in rows) {
    final top = y - 28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(96 - 32, top, _w - 96 + 32, top + 124),
        const Radius.circular(36),
      ),
      card,
    );
    y += 10;
    y += _text(canvas, row, size: 44, color: white, y: y) + 62;
  }

  y = _h - 150;
  y +=
      _text(
        canvas,
        'زاد — صاحبتك في إدارة البيت',
        size: 40,
        color: mint,
        y: y,
        bold: true,
      ) +
      8;
  _text(
    canvas,
    'نزّل زاد وجرّب أسبوع معاها',
    size: 32,
    color: white.withAlpha(170),
    y: y,
  );

  final image = await recorder.endRecording().toImage(_w.toInt(), _h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Kotlin's `WeeklyShareCard.share`: the image plus the title and the store
/// link.
Future<void> shareWeek(
  WeekSummary week, {
  int? challengeStreak,
  int? tasbihaStreak,
}) async {
  final bytes = await renderWeek(
    week,
    challengeStreak: challengeStreak,
    tasbihaStreak: tasbihaStreak,
  );
  await SharePlus.instance.share(
    ShareParams(
      text:
          'أسبوعي مع زاد\n'
          'https://play.google.com/store/apps/details?id=com.aistudio.zad.wrtqvx',
      subject: 'شارك أسبوعك',
      files: <XFile>[
        XFile.fromData(bytes, mimeType: 'image/png', name: 'zad_week.png'),
      ],
      fileNameOverrides: const <String>['zad_week.png'],
    ),
  );
}
