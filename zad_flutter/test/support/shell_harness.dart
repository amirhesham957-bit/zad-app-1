// The shell with no server — shared by the shell walkthrough.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/features/auth/data/auth_gateway.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';
import 'package:zad/features/insights/data/insights_repository.dart';
import 'package:zad/features/notifications/data/notifications_remote.dart';
import 'package:zad/features/notifications/data/notifications_repository.dart';
import 'package:zad/features/proposals/data/proposals_repository.dart';
import 'package:zad/features/proposals/domain/transaction_proposal.dart';
import 'package:zad/features/settings/data/settings_repository.dart';
import 'package:zad/features/settings/domain/account_settings.dart';
import 'package:zad/features/subscriptions/data/subscriptions_remote.dart';
import 'package:zad/features/subscriptions/data/subscriptions_repository.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';

import 'quiet_household.dart';

class _Gateway implements AuthGateway {
  new(this.userId);

  final String? userId;

  @override
  String? get currentUserId => userId;

  @override
  Stream<String?> get userIdChanges => const Stream<String?>.empty();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String name,
    String? country,
    String? currency,
  }) async => SignUpOutcome.signedIn;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

class _Offline implements TransactionsRemote {
  @override
  Future<Map<String, dynamic>?> updateReturning(
    Map<String, dynamic> patch,
  ) async => null;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> exists(String id) async => false;

  @override
  Future<List<Map<String, dynamic>>> fetchPeriod({
    required String userId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) => Future<List<Map<String, dynamic>>>.error(
    const SocketException('offline'),
  );

  @override
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row) =>
      Future<Map<String, dynamic>?>.error(const SocketException('offline'));
}

class _OfflineBudget implements BudgetRemote {
  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) => Future<Map<String, dynamic>>.error(const SocketException('offline'));
}

/// Refuses at once. A widget test cannot let a background refresh reach a
/// Hive write — under the fake clock that write never completes.
class _OfflineSettings implements SettingsRemote {
  int fetches = 0;

  @override
  Future<Map<String, dynamic>?> fetch({required String userId}) {
    fetches++;
    return Future<Map<String, dynamic>?>.error(
      const SocketException('offline'),
    );
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row) =>
      Future<Map<String, dynamic>?>.error(const SocketException('offline'));
}

class _OfflineProposals implements ProposalsRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchOpen({required String userId}) =>
      Future<List<Map<String, dynamic>>>.error(
        const SocketException('offline'),
      );

  @override
  Future<Map<String, dynamic>> resolve({
    required String proposalId,
    required ProposalDecision decision,
  }) => Future<Map<String, dynamic>>.error(const SocketException('offline'));
}

Map<String, dynamic> _state() => <String, dynamic>{
  'user_id': 'user-1',
  'currency': 'ج.م',
  'timezone': 'Africa/Cairo',
  'spent': 0,
  'income': 0,
  'committed': 0,
  'days_left': 5,
  'cycle_length_days': 31,
  'threat': 'SAFE',
  'unverified_count': 0,
  'computed_at': '2026-09-20T12:00:00Z',
  'available': 1000,
  'remaining': 1000,
  'opening_balance': 8000,
  'limit_confirmed': true,
  'cycle_start': '2026-08-25',
  'cycle_end': '2026-09-25',
};

/// Refuses at once: a widget test must not let a background refresh reach a
/// Hive write, which never completes under the fake clock.
class _OfflineSubscriptions implements SubscriptionsRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchAll({required String userId}) =>
      Future<List<Map<String, dynamic>>>.error(
        const SocketException('offline'),
      );

  @override
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row) =>
      Future<Map<String, dynamic>?>.error(const SocketException('offline'));

  @override
  Future<void> remove(String id) =>
      Future<void>.error(const SocketException('offline'));
}

/// Insights with no server: every call refuses at once, so Home's section
/// renders from the (empty) cache and a background refresh cannot write.
class _OfflineInsights implements InsightsRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchPending(String userId) =>
      Future<List<Map<String, dynamic>>>.error(
        const SocketException('offline'),
      );

  @override
  Future<void> setStatus(String id, String status, {String? reason}) =>
      Future<void>.error(const SocketException('offline'));

  @override
  Future<String?> statusOf(String id) =>
      Future<String?>.error(const SocketException('offline'));

  @override
  Future<void> remember({
    required String userId,
    required String scope,
    required String note,
    required double confidence,
  }) => Future<void>.error(const SocketException('offline'));
}

/// Refuses at once, for the same reason as the subscriptions stand-in.
class _OfflineNotifications implements NotificationsRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchLatest({
    required String userId,
    required int limit,
  }) => Future<List<Map<String, dynamic>>>.error(
    const SocketException('offline'),
  );

  @override
  Future<Map<String, dynamic>?> markReadReturning(String id) =>
      Future<Map<String, dynamic>?>.error(const SocketException('offline'));

  @override
  Future<void> markAllRead({required String userId, required DateTime upTo}) =>
      Future<void>.error(const SocketException('offline'));

  @override
  Future<int> unreadUpTo({required String userId, required DateTime upTo}) =>
      Future<int>.error(const SocketException('offline'));
}

/// The shell's world with no server: a signed-in account on a fixed clock,
/// every remote refusing at once, empty Hive boxes. Same stand-ins as
/// `test/app/auth_gate_test.dart`.
class ShellHarness {
  late Box<String> documents;
  late Box<String> chatBox;
  late Box<String> transactions;
  late Box<String> outboxBox;
  late Box<String> subsBox;
  late Box<String> deviceBox;

  final DateTime now = DateTime.parse('2026-09-20T12:00:00Z');

  /// Opens in-memory boxes, the introduction seen, a budget and a market.
  Future<void> open() async {
    Hive.init('unused');
    documents = await Hive.openBox<String>('documents', bytes: Uint8List(0));
    transactions = await Hive.openBox<String>(
      'transactions',
      bytes: Uint8List(0),
    );
    outboxBox = await Hive.openBox<String>('outbox', bytes: Uint8List(0));
    subsBox = await Hive.openBox<String>('subscriptions', bytes: Uint8List(0));
    deviceBox = await Hive.openBox<String>('device', bytes: Uint8List(0));
    await deviceBox.put('intro_seen', 'true');
    chatBox = await Hive.openBox<String>('chat', bytes: Uint8List(0));
    await documents.put(
      'budget_state',
      jsonEncode(BudgetSnapshot.fromJson(_state()).toJson()),
    );
    await documents.put(
      'account_settings',
      jsonEncode(
        const AccountSettings(country: 'EG', currency: 'EGP').toJson(),
      ),
    );
  }

  /// A container for [userId].
  ProviderContainer container(
    String? userId, {
    List<Override>? household,
    List<Override> extra = const <Override>[],
  }) {
    late TransactionsRepository txns;
    final outbox = Outbox(
      box: outboxBox,
      send: (entry) => txns.sendQueued(entry),
      clock: () => now,
    );
    txns = TransactionsRepository(
      cache: transactions,
      remote: _Offline(),
      outbox: () => outbox,
      newId: () => 'txn',
      signedInUserId: () => userId,
    );
    return ProviderContainer(
      overrides: [
        ...(household ?? quietHouseholdOverrides),
        authGatewayProvider.overrideWithValue(_Gateway(userId)),
        signedInUserIdProvider.overrideWithValue(() => userId),
        nowProvider.overrideWithValue(() => now),
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: outboxBox,
            transactions: transactions,
            documents: documents,
            chat: chatBox,
            inventory: chatBox,
            shopping: chatBox,
            pharmacy: chatBox,
            subscriptions: subsBox,
            device: deviceBox,
          ),
        ),
        transactionsRepositoryProvider.overrideWithValue(txns),
        budgetRepositoryProvider.overrideWithValue(
          BudgetRepository(
            cache: documents,
            remote: _OfflineBudget(),
            signedInUserId: () => userId,
          ),
        ),
        insightsRepositoryProvider.overrideWithValue(
          InsightsRepository(
            cache: documents,
            remote: _OfflineInsights(),
            outbox: () => outbox,
            signedInUserId: () => userId,
          ),
        ),
        notificationsRepositoryProvider.overrideWithValue(
          NotificationsRepository(
            cache: documents,
            remote: _OfflineNotifications(),
            outbox: () => outbox,
            signedInUserId: () => userId,
          ),
        ),
        subscriptionsRepositoryProvider.overrideWithValue(
          SubscriptionsRepository(
            cache: subsBox,
            remote: _OfflineSubscriptions(),
            outbox: () => outbox,
            newId: () => 'sub',
            signedInUserId: () => userId,
          ),
        ),
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(
            cache: documents,
            remote: _OfflineSettings(),
            outbox: () => outbox,
            signedInUserId: () => userId,
            now: () => now,
          ),
        ),
        proposalsRepositoryProvider.overrideWithValue(
          ProposalsRepository(
            cache: documents,
            remote: _OfflineProposals(),
            signedInUserId: () => userId,
          ),
        ),
        ...extra,
      ],
    );
  }
}
