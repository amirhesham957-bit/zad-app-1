// The way in, through the widgets.
//
// No Hive and no boxes here on purpose: this screen owns no cache. Everything
// it can do goes through the gateway, so a fake one is the whole harness.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/auth/application/auth_controller.dart';
import 'package:zad/features/auth/data/auth_gateway.dart';
import 'package:zad/features/auth/domain/auth_failure.dart';
import 'package:zad/features/auth/presentation/login_screen.dart';

class _FakeGateway implements AuthGateway {
  final List<String> calls = <String>[];
  AuthFailure? failWith;
  Completer<void>? gate;

  @override
  String? get currentUserId => null;

  @override
  Stream<String?> get userIdChanges => const Stream<String?>.empty();

  Future<void> _run(String call) async {
    calls.add(call);
    if (gate case final g?) await g.future;
    if (failWith case final f?) throw f;
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _run('signIn:$email:$password');

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    await _run('signUp:$email:$name');
    return SignUpOutcome.signedIn;
  }

  @override
  Future<void> sendPasswordReset(String email) => _run('reset:$email');

  @override
  Future<void> signOut() => _run('signOut');
}

void main() {
  late _FakeGateway gateway;

  setUp(() => gateway = _FakeGateway());

  Future<void> pumpLogin(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [authGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp(
        theme: ZadTheme.light(),
        locale: const Locale('ar'),
        home: const LoginScreen(),
      ),
    ),
  );

  Finder fieldLabelled(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  testWidgets('opens on sign-in, with no name field to fill', (tester) async {
    await pumpLogin(tester);

    expect(find.text('أهلاً بيك تاني'), findsOneWidget);
    expect(find.text('ادخل'), findsOneWidget);
    expect(find.text('اسمك'), findsNothing);
  });

  testWidgets('typing an email and a password signs in with exactly those', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.enterText(fieldLabelled('الإيميل'), 'amir@example.com');
    await tester.enterText(fieldLabelled('كلمة السر'), 'hunter2000');
    await tester.tap(find.widgetWithText(FilledButton, 'ادخل'));
    await tester.pump();

    expect(gateway.calls, <String>['signIn:amir@example.com:hunter2000']);
  });

  testWidgets('a rejected password is said in words, and the button returns', (
    tester,
  ) async {
    gateway.failWith = const AuthFailure(AuthFailureKind.invalidCredentials);
    await pumpLogin(tester);

    await tester.enterText(fieldLabelled('الإيميل'), 'amir@example.com');
    await tester.enterText(fieldLabelled('كلمة السر'), 'wrong-one');
    await tester.tap(find.widgetWithText(FilledButton, 'ادخل'));
    await tester.pump();
    await tester.pump();

    expect(find.text('الإيميل أو كلمة السر مش مظبوطة.'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull, reason: 'the button must come back');
  });

  testWidgets('a typo in the address never leaves the device', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(fieldLabelled('الإيميل'), 'amir-at-example.com');
    await tester.enterText(fieldLabelled('كلمة السر'), 'hunter2000');
    await tester.tap(find.widgetWithText(FilledButton, 'ادخل'));
    await tester.pump();

    expect(find.text('الإيميل ده شكله مش مظبوط.'), findsOneWidget);
    expect(gateway.calls, isEmpty);
  });

  testWidgets('while the request is in flight the button is disabled', (
    tester,
  ) async {
    gateway.gate = Completer<void>();
    await pumpLogin(tester);

    await tester.enterText(fieldLabelled('الإيميل'), 'amir@example.com');
    await tester.enterText(fieldLabelled('كلمة السر'), 'hunter2000');
    await tester.tap(find.widgetWithText(FilledButton, 'ادخل'));
    // pump, never pumpAndSettle: the spinner in the button animates forever
    // and settling would wait for an animation that has no end.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    gateway.gate!.complete();
    await tester.pump();
  });

  testWidgets('switching to sign-up asks for a name and says the minimum', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.tap(find.text('لسه معندكش حساب؟ اعمل واحد'));
    await tester.pump();

    expect(find.text('اسمك'), findsOneWidget);
    expect(find.text('$kMinPasswordLength حروف على الأقل'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'اعمل حساب'), findsOneWidget);
  });

  testWidgets('the reset mode drops the password field entirely', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.tap(find.text('نسيت كلمة السر؟'));
    await tester.pump();

    expect(find.text('كلمة السر'), findsNothing);

    await tester.enterText(fieldLabelled('الإيميل'), 'amir@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'ابعت اللينك'));
    await tester.pump();
    await tester.pump();

    expect(gateway.calls, <String>['reset:amir@example.com']);
    // Back on sign-in, and told what just happened.
    expect(find.widgetWithText(FilledButton, 'ادخل'), findsOneWidget);
    expect(find.textContaining('لينك لتغيير كلمة السر'), findsOneWidget);
  });

  testWidgets('the password can be revealed', (tester) async {
    await pumpLogin(tester);

    TextField password() =>
        tester.widget<TextField>(fieldLabelled('كلمة السر'));
    expect(password().obscureText, isTrue);

    await tester.tap(find.byTooltip('اظهر كلمة السر'));
    await tester.pump();

    expect(password().obscureText, isFalse);
  });
}
