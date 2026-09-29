/// Writes the home-screen widget whenever the figures it shows change.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/home/data/home_widget_sync.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';

/// Kept alive by the shell. Rebuilds — and pushes — when the spendable
/// figure, the currency or the newest transactions change; nothing else.
final homeWidgetSyncProvider = Provider<void>((ref) {
  final available = ref.watch(
    budgetControllerProvider.select((v) => v.spendable),
  );
  final currency = ref.watch(
    budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
  );
  // A list compares by identity, so the rows are watched through a text
  // signature of the three newest; the list itself is read.
  ref.watch(
    transactionsControllerProvider.select(
      (v) => v.rows
          .take(3)
          .map((t) => '${t.id}|${t.amount}|${t.title}|${t.merchantName}')
          .join(';'),
    ),
  );
  final recent = ref.read(transactionsControllerProvider).rows.take(3).toList();
  unawaited(
    ref.read(homeWidgetPushProvider)(
      widgetValues(
        available: available,
        currency: currency,
        recent: recent,
        now: ref.read(nowProvider)(),
      ),
    ),
  );
});

/// How the values reach the widget — the plugin on a phone, a recorder in a
/// test.
final homeWidgetPushProvider =
    Provider<Future<void> Function(Map<String, String> values)>(
      (ref) => pushToHomeWidget,
    );
