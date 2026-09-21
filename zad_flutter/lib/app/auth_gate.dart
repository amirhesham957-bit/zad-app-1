/// Which of the two apps this is: the one behind a session, and the one in
/// front of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/zad_shell.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/auth/application/session_controller.dart';
import 'package:zad/features/auth/presentation/login_screen.dart';
import 'package:zad/features/market/application/market_gate_controller.dart';
import 'package:zad/features/market/presentation/market_selection_screen.dart';
import 'package:zad/features/onboarding/application/intro_controller.dart';
import 'package:zad/features/onboarding/presentation/intro_screen.dart';

/// Shows the shell to a signed-in customer whose account has a market, the
/// market picker to one whose account has none, and the login screen to
/// everyone else — after the introduction, on a phone that has not seen it.
///
/// A customer coming back to the app sees no loading branch at all:
/// [SessionController] seeds itself synchronously from the session Supabase
/// already restored from disk during `bootstrap`, and the market gate decides
/// from the settings the device already holds, so the first frame is the
/// shell. The one wait there is — [MarketGate.checking] — happens only when
/// the device has never read this account's settings, which in practice means
/// straight after signing in, and it is bounded by
/// [MarketGateController.checkTimeout].
class ZadAuthGate extends ConsumerWidget {
  /// Creates the gate.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(sessionControllerProvider) != null;

    if (!signedIn) {
      // A phone that has never seen Zad is shown what it does before it is
      // asked for an email address.
      return ref.watch(introSeenProvider)
          ? const LoginScreen()
          : const IntroScreen();
    }

    return switch (ref.watch(marketGateProvider)) {
      MarketGate.checking => const _Checking(),
      MarketGate.missing => const MarketSelectionScreen(),
      MarketGate.chosen || MarketGate.unknown => const ZadShell(),
    };
  }
}

/// The one moment the gate waits on the server.
class _Checking extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: ZadSpacing.lg),
            Text(
              'بنجهّز حسابك…',
              style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ),
      ),
    ),
  );
}
