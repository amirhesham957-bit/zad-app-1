/// Keeps the home-screen widget (ZadBalanceWidget.kt) in step with the app.
///
/// Kotlin's TransactionWidget: «متاح» and the last three transactions. The
/// widget has no network and does no arithmetic; everything it shows is
/// written here, already formatted, whenever the budget or the list changes.
library;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/shared/campaigns/domain/campaign.dart';
import 'package:zad/shared/companion/domain/pet_care.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

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
///
/// The season row: today's [campaign] (its badge and name on its colour), or
/// else a countdown to [upcoming]; blank keys hide it. [brief] is the daily
/// brief's first line — the one thing that needs the customer today.
Map<String, String> widgetValues({
  required double? available,
  required String currency,
  required List<ZadTransaction> recent,
  required DateTime now,
  ActiveCampaign? campaign,
  ({Campaign campaign, int inDays})? upcoming,
  String? brief,
}) {
  final newest = [...recent]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final values = <String, String>{
    'zad_available': available == null ? '—' : _money(available, currency),
    'zad_updated':
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}',
    ...seasonValues(campaign: campaign, upcoming: upcoming),
    'zad_brief': brief?.trim() ?? '',
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

/// The season row's keys. Empty strings hide the row.
Map<String, String> seasonValues({
  ActiveCampaign? campaign,
  ({Campaign campaign, int inDays})? upcoming,
}) {
  final Campaign c;
  final String line;
  if (campaign != null) {
    c = campaign.campaign;
    line = c.eventName ?? c.title;
  } else if (upcoming != null) {
    c = upcoming.campaign;
    final name = c.eventName!;
    line = switch (upcoming.inDays) {
      1 => 'بكرة $name',
      2 => 'باقي يومين على $name',
      final n => 'باقي $n أيام على $name',
    };
  } else {
    return const <String, String>{
      'zad_season_badge': '',
      'zad_season_line': '',
      'zad_season_color': '',
    };
  }
  return <String, String>{
    'zad_season_badge': c.badge,
    'zad_season_line': line,
    // White text sits on it; a colour that would hide it gets زاد's green.
    'zad_season_color': c.readableOnWhite
        ? '#${(c.primary & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}'
        : '#1b4332',
  };
}

/// The pet row's keys: the moments its levels were full, not the levels
/// themselves. Hunger and thirst keep falling while the app is closed, so
/// the widget works the face out at every redraw (ZadBalanceWidget.kt
/// mirrors `PetCare.mood`) — on the app's writes and every 30 minutes.
/// Signed out ([care] null): blank keys hide the row.
Map<String, String> petWidgetValues({
  required PetCare? care,
  required String name,
  required String zone,
}) {
  String ms(DateTime? t) =>
      t == null ? '' : '${t.toUtc().millisecondsSinceEpoch}';
  return <String, String>{
    'zad_pet_name': care == null ? '' : name,
    'zad_pet_fed_at': ms(care?.fedAt),
    'zad_pet_watered_at': ms(care?.wateredAt),
    'zad_pet_petted_at': ms(care?.pettedAt),
    'zad_pet_cared_at': ms(care?.lastCareAt),
    'zad_pet_hunger_ms': '${PetCare.hungerSpan.inMilliseconds}',
    'zad_pet_thirst_ms': '${PetCare.thirstSpan.inMilliseconds}',
    'zad_pet_joy_ms': '${PetCare.joySpan.inMilliseconds}',
    'zad_pet_zone': zone,
  };
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
