/// Kotlin's `zad_rejected_bank_messages` (Room, trimmed to 200 rows, never
/// synced): the bank messages the filter set aside, with why — so a bank that
/// never registers shows its reason instead of looking like a blind agent.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/bank/domain/bank_notification.dart';

/// One set-aside message.
typedef RejectedBankMessage = ({
  String reason,
  String source,
  String rawText,
  DateTime createdAt,
});

/// The log, on this device.
class BankRejectedLog {
  /// Creates the log over the documents box.
  const new(this._box);

  final Box<String> _box;

  static const String _key = 'bank_rejected_messages';
  static const int _max = 200;

  /// Kotlin's reason names: OTP, DECLINED, EXPIRED, PROMO, UNPARSED.
  static String reasonName(BankRejectReason r) => switch (r) {
    BankRejectReason.otp => 'OTP',
    BankRejectReason.declined => 'DECLINED',
    BankRejectReason.pending => 'PENDING',
    BankRejectReason.expired => 'EXPIRED',
    BankRejectReason.promo => 'PROMO',
    BankRejectReason.unparsed => 'UNPARSED',
  };

  /// Newest first.
  List<RejectedBankMessage> read() {
    try {
      final list = jsonDecode(_box.get(_key) ?? '[]') as List<Object?>;
      return <RejectedBankMessage>[
        for (final e in list)
          if (e is Map)
            (
              reason: '${e['reason']}',
              source: '${e['source']}',
              rawText: '${e['raw_text']}',
              createdAt:
                  DateTime.tryParse('${e['created_at']}') ?? DateTime(1970),
            ),
      ];
    } on Object {
      return const <RejectedBankMessage>[];
    }
  }

  /// Adds one, keeping the newest 200.
  Future<void> add(String source, BankRejectReason reason, String rawText) {
    final list = <Map<String, String>>[
      <String, String>{
        'reason': reasonName(reason),
        'source': source,
        'raw_text': rawText.length > 300 ? rawText.substring(0, 300) : rawText,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      for (final m in read().take(_max - 1))
        <String, String>{
          'reason': m.reason,
          'source': m.source,
          'raw_text': m.rawText,
          'created_at': m.createdAt.toIso8601String(),
        },
    ];
    return _box.put(_key, jsonEncode(list));
  }
}

/// The bank messages set aside, with why (Kotlin's rejected-messages table).
final bankRejectedLogProvider = Provider<BankRejectedLog>(
  (ref) => BankRejectedLog(ref.watch(localStoreProvider).documents),
);
