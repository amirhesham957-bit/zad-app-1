/// Which of the two apps this is: the one behind a session, and the one in
/// front of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/zad_shell.dart';
import 'package:zad/features/auth/application/session_controller.dart';
import 'package:zad/features/auth/presentation/login_screen.dart';

/// Shows the shell to a signed-in customer and the login screen to everyone
/// else.
///
/// There is no third, loading branch, and that is the point:
/// [SessionController] seeds itself synchronously from the session Supabase
/// already restored from disk during `bootstrap`, so on the very first frame
/// this is either the shell or the login screen — never a spinner shown to
/// somebody who never signed out.
class ZadAuthGate extends ConsumerWidget {
  /// Creates the gate.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(sessionControllerProvider) != null;
    return signedIn ? const ZadShell() : const LoginScreen();
  }
}
