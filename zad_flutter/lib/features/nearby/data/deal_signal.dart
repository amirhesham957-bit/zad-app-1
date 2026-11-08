/// Tells the brain a deal card was opened, so what the customer taps rises in
/// what Zad picks for them (zad-brain's `deal_signal`, `_shared/dealRelevance.ts`).
///
/// Best-effort on purpose: a lost signal costs one data point, and opening the
/// deal must never wait on it or fail because of it.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';

/// Sends the signal in the background; never throws.
void sendDealOpened(
  WidgetRef ref, {
  required String item,
  required String store,
}) {
  Future<void> send() async {
    try {
      await ref
          .read(supabaseClientProvider)
          .functions
          .invoke(
            'zad-brain',
            body: <String, dynamic>{
              'action': 'deal_signal',
              'item': item,
              'store': store,
            },
          );
    } on Object catch (e) {
      debugPrint('deal_signal failed: $e');
    }
  }

  unawaited(send());
}
