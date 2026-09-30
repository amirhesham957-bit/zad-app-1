/// Which repository sends each kind of queued write.
///
/// The outbox (core/) knows no feature; this is the one place that maps a
/// kind to the feature that queued it. Bound by `wireZad`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/features/alerts/data/push_registrar.dart';
import 'package:zad/features/bank/data/bank_remote.dart';
import 'package:zad/features/obligations/data/obligations_repository.dart';
import 'package:zad/features/recipes/data/recipes_repository.dart';
import 'package:zad/shared/insights/data/insights_repository.dart';
import 'package:zad/shared/inventory/data/consumption_observations.dart';
import 'package:zad/shared/inventory/data/inventory_repository.dart';
import 'package:zad/shared/inventory/data/shopping_list_repository.dart';
import 'package:zad/shared/notifications/data/notifications_repository.dart';
import 'package:zad/shared/pharmacy/data/pharmacy_repository.dart';
import 'package:zad/shared/prices/data/prices_repository.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';
import 'package:zad/shared/subscriptions/data/subscriptions_repository.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';

/// Sends [entry] through the repository its kind belongs to.
Future<void> sendOutboxEntry(Ref ref, OutboxEntry entry) async =>
    switch (entry.kind) {
      OutboxKind.insertTransaction =>
        await ref.read(transactionsRepositoryProvider).sendQueued(entry),
      OutboxKind.updateTransaction =>
        await ref.read(transactionsRepositoryProvider).sendQueuedEdit(entry),
      OutboxKind.deleteTransaction =>
        await ref.read(transactionsRepositoryProvider).sendQueuedDelete(entry),
      OutboxKind.notificationIngest =>
        await ref.read(bankRemoteProvider).ingestNotification(entry.payload),
      OutboxKind.updateAccountSettings =>
        await ref.read(settingsRepositoryProvider).sendQueued(entry),
      OutboxKind.upsertInventory =>
        await ref.read(inventoryRepositoryProvider).sendQueued(entry),
      OutboxKind.deleteInventory =>
        await ref.read(inventoryRepositoryProvider).sendQueuedDelete(entry),
      OutboxKind.upsertShoppingItem =>
        await ref.read(shoppingListRepositoryProvider).sendQueued(entry),
      OutboxKind.deleteShoppingItem =>
        await ref.read(shoppingListRepositoryProvider).sendQueuedDelete(entry),
      OutboxKind.upsertPharmacyItem =>
        await ref.read(pharmacyRepositoryProvider).sendQueued(entry),
      OutboxKind.confirmPharmacyQuantity =>
        await ref.read(pharmacyRepositoryProvider).sendQueuedQuantity(entry),
      OutboxKind.deletePharmacyItem =>
        await ref.read(pharmacyRepositoryProvider).sendQueuedDelete(entry),
      OutboxKind.logPharmacyDose =>
        await ref.read(pharmacyRepositoryProvider).sendQueuedDose(entry),
      OutboxKind.upsertDoseSnooze =>
        await ref.read(pharmacyRepositoryProvider).sendQueuedSnooze(entry),
      OutboxKind.restockPharmacyItem =>
        await ref.read(pharmacyRepositoryProvider).sendQueuedRestock(entry),
      OutboxKind.upsertSubscription =>
        await ref.read(subscriptionsRepositoryProvider).sendQueued(entry),
      OutboxKind.recordObservation =>
        await ref.read(consumptionObservationsProvider).sendQueued(entry),
      OutboxKind.rateRecipe =>
        await ref.read(recipesRepositoryProvider).sendQueuedRating(entry),
      OutboxKind.reportPrice =>
        await ref.read(pricesRepositoryProvider).sendQueuedReport(entry),
      OutboxKind.registerPushToken =>
        await ref.read(pushRegistrarProvider).sendQueued(entry),
      OutboxKind.resolveInsight =>
        await ref.read(insightsRepositoryProvider).sendQueued(entry),
      OutboxKind.markNotificationRead =>
        await ref.read(notificationsRepositoryProvider).sendQueuedRead(entry),
      OutboxKind.markAllNotificationsRead =>
        await ref
            .read(notificationsRepositoryProvider)
            .sendQueuedReadAll(entry),
      OutboxKind.deleteSubscription =>
        await ref.read(subscriptionsRepositoryProvider).sendQueuedDelete(entry),
      OutboxKind.upsertObligation =>
        await ref.read(obligationsRepositoryProvider).sendQueued(entry),
      OutboxKind.deleteObligation =>
        await ref.read(obligationsRepositoryProvider).sendQueuedDelete(entry),
      _ => throw StateError('no sender for outbox kind "${entry.kind}"'),
    };
