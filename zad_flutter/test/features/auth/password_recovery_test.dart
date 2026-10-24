// «نسيت كلمة السر» (ZAD_PLAN ٠.١٠): the reset link opens the app and the app
// asks for the new password. Before 2026-10-24 nothing on the phone could set
// one, so the reset went nowhere.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/auth/presentation/password_recovery_listener.dart';
import 'package:zad/shared/auth/data/password_recovery.dart';
import 'package:zad/shared/auth/domain/auth_failure.dart';

class _Recovery implements PasswordRecoveryGateway {
  final StreamController<void> links = StreamController<void>.broadcast();
  final List<String> saved = <String>[];
  AuthFailure? fails;

  @override
  Stream<void> get recoveries => links.stream;

  @override
  Future<void> setNewPassword(String password) async {
    if (fails case final failure?) throw failure;
    saved.add(password);
  }
}

Future<_Recovery> _pump(WidgetTester tester) async {
  final recovery = _Recovery();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [passwordRecoveryProvider.overrideWithValue(recovery)],
      child: const MaterialApp(
        locale: Locale('ar'),
        localizationsDelegates: ZadL10n.localizationsDelegates,
        supportedLocales: ZadL10n.supportedLocales,
        home: PasswordRecoveryListener(child: Scaffold(body: Text('التطبيق'))),
      ),
    ),
  );
  return recovery;
}

void main() {
  testWidgets('a reset link asks for the new password and saves it', (
    tester,
  ) async {
    final recovery = await _pump(tester);
    expect(find.text('كلمة سر جديدة'), findsNothing);

    recovery.links.add(null);
    await tester.pumpAndSettle();
    expect(find.text('كلمة سر جديدة'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'secret-123');
    await tester.tap(find.text('احفظ'));
    await tester.pumpAndSettle();

    expect(recovery.saved, <String>['secret-123']);
    expect(find.text('كلمة سر جديدة'), findsNothing);
    expect(find.text('اتغيرت كلمة السر.'), findsOneWidget);
  });

  testWidgets('a short password is refused before the server is asked', (
    tester,
  ) async {
    final recovery = await _pump(tester);
    recovery.links.add(null);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('احفظ'));
    await tester.pumpAndSettle();

    expect(recovery.saved, isEmpty);
    expect(find.text('كلمة سر جديدة'), findsOneWidget);
  });

  testWidgets('a server refusal stays on the dialog, said in words', (
    tester,
  ) async {
    final recovery = await _pump(tester)
      ..fails = const AuthFailure(AuthFailureKind.offline);
    recovery.links.add(null);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'secret-123');
    await tester.tap(find.text('احفظ'));
    await tester.pumpAndSettle();

    expect(find.text('كلمة سر جديدة'), findsOneWidget);
    expect(find.text('مفيش اتصال بالنت — الدخول محتاج نت.'), findsOneWidget);
  });

  test('the reset link comes back to this app', () {
    expect(kPasswordResetRedirect, 'com.aistudio.zad.wrtqvx://reset-password');
  });
}
