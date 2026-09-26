/// Kotlin's `BankListeningPill` (`ui/components/BankListeningPill.kt`) and the
/// fx notice above it on home.
///
/// The pill says the truth about the bank channel right under the green card:
/// green while the listener is alive, orange and tappable when Android killed
/// it — one tap repairs it. Kotlin re-reads the status every 30 seconds while
/// home is open, and so does this.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/money/fx.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/bank/application/bank_access_controller.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';

/// Kotlin's `unconvertibleTxCount`: transactions in a currency other than
/// the account's with no rate to convert them, left out of the totals.
final unconvertibleTxCountProvider = Provider<int>((ref) {
  final home = ref.watch(settingsRepositoryProvider).cached()?.currency;
  if (home == null || home.trim().isEmpty) return 0;
  final rows = ref.watch(transactionsControllerProvider.select((v) => v.rows));
  var count = 0;
  for (final tx in rows) {
    final code = tx.currency?.trim().toUpperCase();
    if (code == null || code.isEmpty || code == home.toUpperCase()) continue;
    if (convertCurrency(tx.amount, code, home) == null) count++;
  }
  return count;
});

/// «استُبعدت N معاملة من الإجمالي — عملتها مالهاش سعر صرف», or nothing. A
/// total that silently shrinks reads as a bug; the count reads as a reason.
class FxExcludedNotice extends ConsumerWidget {
  /// Creates the notice.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unconvertibleTxCountProvider);
    if (count <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.secondary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.currency_exchange, size: 18, color: scheme.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'استُبعدت $count معاملة من الإجمالي — عملتها مالهاش سعر صرف',
                style: ZadType.bodySmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pill, re-checked every 30 seconds while it is on screen.
class BankListeningPill extends ConsumerStatefulWidget {
  /// Creates the pill.
  const new({super.key});

  @override
  ConsumerState<BankListeningPill> createState() => _BankListeningPillState();
}

class _BankListeningPillState extends ConsumerState<BankListeningPill> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        unawaited(ref.read(bankAccessControllerProvider.notifier).refresh());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bankAccessControllerProvider);
    final alive = state.isAlive(ref.read(nowProvider)());
    final bg = alive
        ? const Color(0xFF00BFA6).withValues(alpha: 0.12)
        : const Color(0xFFFF8A3D).withValues(alpha: 0.15);
    final fg = alive ? const Color(0xFF00897B) : const Color(0xFFE65100);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alive
            ? null
            : () => ref.read(bankAccessControllerProvider.notifier).repair(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.hearing, size: 14, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  alive
                      ? 'بسمع رسايل البنك وحدّث رصيدك تلقائياً'
                      : 'الاستماع لرسايل البنك وقف — اضغط للإصلاح',
                  style: ZadType.labelSmall.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
