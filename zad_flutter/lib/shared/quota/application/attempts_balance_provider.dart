/// The balance the chip shows, read on demand and re-read after every reply.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/quota/data/attempts_remote.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';

/// The customer's balance, or null when there is none to show (signed out,
/// offline, or an older server). Null hides the chip rather than showing a
/// wrong number: a balance is a promise, and a guessed one breaks it.
final FutureProvider<AttemptsBalance?> attemptsBalanceProvider =
    FutureProvider.autoDispose<AttemptsBalance?>((ref) async {
      final zone = ref.watch(accountTimeZoneProvider);
      try {
        return await ref.watch(attemptsRemoteProvider).fetch(timeZone: zone);
      } on Object {
        return null;
      }
    });
