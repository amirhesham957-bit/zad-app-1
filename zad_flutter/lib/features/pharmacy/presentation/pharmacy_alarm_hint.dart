/// The exact-alarm hint: when a medicine has dose times and Android will not
/// ring on time, a tap opens the system's «المنبهات الدقيقة» setting; read
/// again whenever the app comes back.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';

/// Whether Android lets the dose reminders ring on time.
final FutureProvider<bool> exactAlarmGrantedProvider =
    FutureProvider.autoDispose<bool>(
      (ref) => ref.watch(localRemindersProvider).canScheduleExact(),
    );

/// Kotlin's exact-alarm hint, shown when [hasScheduledDoses] and Android
/// will not ring on time.
class ExactAlarmHint extends ConsumerStatefulWidget {
  /// Creates the hint.
  const new({required this.hasScheduledDoses, super.key});

  /// A medicine has dose times.
  final bool hasScheduledDoses;

  @override
  ConsumerState<ExactAlarmHint> createState() => _ExactAlarmHintState();
}

class _ExactAlarmHintState extends ConsumerState<ExactAlarmHint>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Kotlin re-reads it on ON_RESUME — the customer comes back from settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(exactAlarmGrantedProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final granted = ref.watch(exactAlarmGrantedProvider).value ?? true;
    if (!widget.hasScheduledDoses || granted) return const SizedBox.shrink();
    final warning = Theme.of(context).colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.md),
      child: Material(
        color: warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              unawaited(ref.read(localRemindersProvider).requestExact()),
          child: Padding(
            padding: const EdgeInsets.all(ZadSpacing.md),
            child: Row(
              children: <Widget>[
                Icon(Icons.notifications_active, size: 18, color: warning),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: Text(
                    'فعّل "المنبهات الدقيقة" من الإعدادات عشان تنبيهات مواعيد '
                    'الدواء تشتغل بدقة',
                    style: ZadType.bodySmall.copyWith(
                      color: warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_left, size: 16, color: warning),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
