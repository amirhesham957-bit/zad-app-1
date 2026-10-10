// «اخرج» from a screen pushed over the app.
//
// The gate swaps the root for the login screen; a pushed screen (settings) sat
// on top of it, so the dialog closed and the customer saw nothing change
// (2026-10-10). Signing out has to leave the login screen on display.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/auth/presentation/sign_out_action.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/auth/domain/auth_failure.dart';

class _Session extends SessionController {
  new({this.fails});

  final AuthFailure? fails;

  @override
  String? build() => 'user-1';

  @override
  int get pendingWriteCount => 0;

  @override
  Future<void> signOut() async {
    state = null;
    if (fails case final failure?) throw failure;
  }
}

/// The gate in miniature: the root shows the app or the login screen, and
/// settings is pushed over it.
class _App extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionControllerProvider) == null) {
      return const Scaffold(body: Text('شاشة الدخول'));
    }
    return Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: SignOutTile()),
            ),
          ),
          child: const Text('الإعدادات'),
        ),
      ),
    );
  }
}

Future<void> _signOutFromSettings(WidgetTester tester, _Session session) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionControllerProvider.overrideWith(() => session)],
      child: const MaterialApp(home: _App()),
    ),
  );
  await tester.tap(find.text('الإعدادات'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(SignOutTile));
  await tester.pumpAndSettle();
  await tester.tap(find.text('اخرج'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signing out from settings leaves the login screen showing', (
    tester,
  ) async {
    await _signOutFromSettings(tester, _Session());

    expect(find.text('شاشة الدخول'), findsOneWidget);
    expect(find.byType(SignOutTile), findsNothing);
  });

  testWidgets('a sign-out the server never heard still lands on login', (
    tester,
  ) async {
    await _signOutFromSettings(
      tester,
      _Session(fails: const AuthFailure(AuthFailureKind.offline)),
    );

    expect(find.text('شاشة الدخول'), findsOneWidget);
    expect(find.byType(SignOutTile), findsNothing);
  });

  testWidgets('"استنى" keeps the customer where they were', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionControllerProvider.overrideWith(_Session.new)],
        child: const MaterialApp(home: _App()),
      ),
    );
    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SignOutTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('استنى'));
    await tester.pumpAndSettle();

    expect(find.byType(SignOutTile), findsOneWidget);
    expect(find.text('شاشة الدخول'), findsNothing);
  });
}
