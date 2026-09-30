/// Kotlin's `ZadExecutiveDossierSheet` (`ZadHomeGlanceCards.kt`, section 7):
/// «التقرير الاستراتيجي الشامل لعقل زاد» — the cycle's money and the house's
/// health on one dark sheet, shareable as text.
///
/// Kotlin built the sheet but never opened it: `showExecutiveDossier` is never
/// set to true and `onOpenDossierClick` defaults to a no-op. Here it opens
/// from the home screen's budget block.
///
/// Two deliberate differences from Kotlin:
/// - The safe daily spend is the home card's figure (spendable over the days
///   left), not Kotlin's available ÷ 14, so the sheet cannot disagree with the
///   card it opens from.
/// - There is no next-month forecast line. Kotlin's came from an AI call
///   (`predictNextMonthExpenses`) that Flutter does not make on its own, and
///   its fallback «لسه مفيش تاريخ صرف كفاية للتنبؤ» would state a reason that
///   is not the real one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/home/presentation/metrics_duo.dart'
    show safeDailySpend;
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';

/// What the sheet shows.
class ExecutiveDossier {
  /// Creates one.
  const new({
    required this.issuedOn,
    required this.totalSpent,
    required this.safeDailySpend,
    required this.familyMembers,
    required this.lowStockItems,
    required this.adherencePct,
    required this.currency,
  });

  /// The account's civil date the sheet was opened on.
  final DateTime issuedOn;

  /// Spent in the current cycle.
  final double totalSpent;

  /// Safe to spend a day; null without a spendable figure.
  final double? safeDailySpend;

  /// People in the family, at least one.
  final int familyMembers;

  /// Pantry items that are short, by the pantry's own rule.
  final int lowStockItems;

  /// The week's dose adherence; null without doses.
  final int? adherencePct;

  /// The account's currency.
  final String currency;

  String _money(double v) =>
      '${NumberFormat('#,##0.##', 'en').format(v)} $currency'.trim();

  /// «تاريخ الإصدار: yyyy-MM-dd».
  String get issuedLine {
    final d = issuedOn;
    String two(int n) => n.toString().padLeft(2, '0');
    return 'تاريخ الإصدار: ${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// Section 1's text.
  String get moneyText {
    final daily = safeDailySpend;
    final dailyLine = daily == null
        ? '• معدل الصرف اليومي الآمن: '
              'محتاج ميزانية ورصيد محدّدين عشان يتحسب.'
        : '• معدل الصرف اليومي الآمن الموصى به: '
              '${_money(daily < 0 ? 0 : daily)}/يوم.';
    return '• إجمالي الصرف الفعلي للدورة الحالية: ${_money(totalSpent)}.\n'
        '$dailyLine';
  }

  /// Section 2's text.
  String get householdText =>
      '• عقل العائلة المشترك: $familyMembers أفراد متصلين ومزامنين لحظياً.\n'
      '• أصناف قاربت على النفاد في المخزون: $lowStockItems صنف.\n'
      '${switch (adherencePct) {
        final int p => '• الالتزام الدوائي هذا الأسبوع: $p%.',
        null => '• الالتزام الدوائي: لسه مفيش جرعات كفاية مسجّلة لحساب نسبة.',
      }}';

  /// What «📤 مشاركة التقرير» sends.
  String get shareText =>
      '📄 تقرير عقل زاد:\n'
      '• إجمالي الصرف: ${_money(totalSpent)}\n'
      '${adherencePct == null ? '' : '• الالتزام الدوائي: $adherencePct%\n'}';
}

/// Gathers the dossier: the money comes from the budget block that opens it,
/// the house from the family, pantry and pharmacy controllers.
ExecutiveDossier executiveDossierOf(
  WidgetRef ref, {
  required double spent,
  required double? spendable,
  required int daysLeft,
  required String currency,
}) {
  final zone = tz.getLocation(ref.read(accountTimeZoneProvider));
  final now = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);
  final members = ref.read(familyControllerProvider).family?.members.length;
  return ExecutiveDossier(
    issuedOn: DateTime(now.year, now.month, now.day),
    totalSpent: spent,
    safeDailySpend: spendable == null
        ? null
        : safeDailySpend(spendable: spendable, daysLeft: daysLeft),
    familyMembers: members == null || members < 1 ? 1 : members,
    lowStockItems: ref.read(pantryControllerProvider).shortages.length,
    adherencePct: ref.read(pharmacyControllerProvider).adherence,
    currency: currency,
  );
}

/// Opens the sheet.
Future<void> showExecutiveDossierSheet(
  BuildContext context,
  ExecutiveDossier dossier,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: _sheet,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => ExecutiveDossierSheet(dossier: dossier),
);

// Kotlin's dossier colours — the sheet's own dark palette, kept here.
const Color _sheet = Color(0xFF0F172A);
const Color _headerFrom = Color(0xFF052E16);
const Color _headerTo = Color(0xFF0F9B76);
const Color _mint = Color(0xFF6EE7B7);
const Color _mintText = Color(0xFFD9F2E6);
const Color _amber = Color(0xFFFBBF24);
const Color _green = Color(0xFF34D399);
const Color _body = Color(0xFFE2E8F0);
const Color _closeText = Color(0xFFCBD5E1);

/// The sheet.
class ExecutiveDossierSheet extends StatelessWidget {
  /// Creates the sheet.
  const new({required this.dossier, super.key});

  /// What it shows.
  final ExecutiveDossier dossier;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[_headerFrom, _headerTo],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: <Widget>[
                const Text('👑', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  'التقرير الاستراتيجي الشامل لعقل زاد',
                  textAlign: TextAlign.center,
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ZAD EXECUTIVE FAMILY & BEHAVIORAL INTELLIGENCE DOSSIER',
                  textAlign: TextAlign.center,
                  style: ZadType.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _mint,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dossier.issuedLine,
                  style: ZadType.labelMedium.copyWith(
                    color: _mintText.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            emoji: '🔮',
            title: '1. التنبؤات والتدفق المالي للشهر القادم',
            tint: _amber,
            text: dossier.moneyText,
          ),
          const SizedBox(height: 16),
          _Section(
            emoji: '🏡',
            title: '2. كفاءة إدارة المنزل والعائلة',
            tint: _green,
            text: dossier.householdText,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: () => unawaited(
                    SharePlus.instance.share(
                      ShareParams(
                        text: dossier.shareText,
                        title: 'مشاركة تقرير عقل زاد',
                      ),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _headerTo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '📤 مشاركة التقرير',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _closeText,
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'إغلاق التقرير',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const new({
    required this.emoji,
    required this.title,
    required this.tint,
    required this.text,
  });

  final String emoji;
  final String title;
  final Color tint;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: ZadType.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: tint,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: ZadType.bodyMedium.copyWith(color: _body, height: 1.6),
        ),
      ],
    ),
  );
}
