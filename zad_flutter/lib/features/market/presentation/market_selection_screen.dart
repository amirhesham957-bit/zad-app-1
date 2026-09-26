/// Asking a signed-in account which market it is in.
///
/// Shown by the gate, once, to an account the server has no country for. The
/// Kotlin app asks the same question before sign-in and stores the answer on
/// the phone until there is an account to write it to — which is how two of
/// the four live accounts ended up with a null country after their owners had
/// chosen one. Asking after sign-in means there is always a row to write to.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_appear.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/auth/presentation/login_screen.dart';
import 'package:zad/features/market/application/market_gate_controller.dart';
import 'package:zad/features/market/domain/market.dart';
import 'package:zad/features/market/presentation/market_picker_grid.dart';

/// The market picker.
class MarketSelectionScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<MarketSelectionScreen> createState() =>
      _MarketSelectionScreenState();
}

class _MarketSelectionScreenState extends ConsumerState<MarketSelectionScreen> {
  Market? _selected;
  bool _saving = false;

  Future<void> _confirm() async {
    final market = _selected;
    if (market == null || _saving) return;
    setState(() => _saving = true);
    // Not awaited, for the same reason as on the login button: feedback, not
    // a precondition.
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ref.read(marketGateProvider.notifier).choose(market);
    } on Object {
      // Only a failure to save *on the device* lands here — the network is
      // the outbox's business and never reaches this screen.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ماقدرناش نحفظ اختيارك. جرّب تاني.')),
        );
      }
    } finally {
      // The gate swaps this screen out on success, so there is usually
      // nothing left to update; on a failure the button comes back.
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: ZadAuthBackground(
        child: SafeArea(
          child: ZadAppearOnEntry(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 48),
                  Text(
                    'وين موطنك؟',
                    textAlign: TextAlign.center,
                    style: ZadType.headlineMedium.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'زاد بيتكلم بلهجتك وبيحسب مصروفك بعملة بلدك',
                    textAlign: TextAlign.center,
                    style: ZadType.bodyLarge.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  MarketPickerGrid(
                    selected: _selected,
                    onSelect: _saving
                        ? null
                        : (m) => setState(() => _selected = m),
                  ),
                  const Spacer(),
                  ZadPrimaryButton(
                    text: 'متابعة',
                    enabled: _selected != null,
                    loading: _saving,
                    onPressed: () => unawaited(_confirm()),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
