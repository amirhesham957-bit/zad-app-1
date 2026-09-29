/// Keeps the home-screen widget (ZadBalanceWidget.kt) in step with the app.
///
/// Kotlin's TransactionWidget: «متاح» and the last three transactions. The
/// widget has no network and does no arithmetic; everything it shows is
/// written here, already formatted, whenever the budget or the list changes.
library;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/features/transactions/domain/transaction.dart';

/// The Android class, fully named: the package is not the application id.
const String kZadWidgetProvider = 'com.aistudio.zad.wrtqvx.ZadBalanceWidget';

String _money(double v, String currency) =>
    '${NumberFormat('#,##0.##', 'en').format(v)} $currency'.trim();

/// What the widget shows, as the keys ZadBalanceWidget.kt reads.
///
/// [available] is the home card's figure (`available`, else `remaining`);
/// null — no budget yet — shows a dash rather than a zero that reads as
/// broke. The three newest of [recent] follow; a missing row is blank and
/// the widget hides it.
Map<String, String> widgetValues({
  required double? available,
  required String currency,
  required List<ZadTransaction> recent,
  required DateTime now,
}) {
  final newest = [...recent]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final values = <String, String>{
    'zad_available': available == null ? '—' : _money(available, currency),
    'zad_updated':
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}',
  };
  for (var i = 0; i < 3; i++) {
    final t = i < newest.length ? newest[i] : null;
    values['zad_tx_${i}_title'] = t == null
        ? ''
        : ((t.merchantName?.trim().isNotEmpty ?? false)
              ? t.merchantName!.trim()
              : t.title);
    values['zad_tx_${i}_amount'] = t == null
        ? ''
        : '${t.isExpense ? '−' : '+'}${_money(t.amount, currency)}';
  }
  return values;
}

/// Writes [values] and redraws the widget. A phone with no widget placed, or
/// a test host with no plugin, costs nothing.
Future<void> pushToHomeWidget(Map<String, String> values) async {
  try {
    for (final e in values.entries) {
      await HomeWidget.saveWidgetData<String>(e.key, e.value);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: kZadWidgetProvider);
  } on Object catch (e) {
    debugPrint('[home_widget] not updated: $e');
  }
}
