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

  // Kotlin's labels sit above the fields, so the fields go by order.
  Finder emailField() => find.byType(TextField).at(0);
  Finder passwordField() => find.byType(TextField).at(1);
  Finder submit(String text) => find.widgetWithText(ElevatedButton, text);

  Future<void> signIn(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    await tester.enterText(emailField(), email);
    await tester.enterText(passwordField(), password);
    await tester.pump();
    await tester.ensureVisible(submit('دخول'));
    await tester.tap(submit('دخول'));
  }

  testWidgets("opens on Kotlin's sign-in, with no name field", (tester) async {
    await pumpLogin(tester);
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('اسم المستخدم'), findsNothing);
  });

  testWidgets('the button waits for an email and a password', (tester) async {
    await pumpLogin(tester);
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(submit('دخول')).onPressed, isNull);
  });

  testWidgets('signs in with exactly what was typed', (tester) async {
    await pumpLogin(tester);
    await tester.pumpAndSettle();
    await signIn(tester, 'amir@example.com', 'hunter2000');
    // The button keeps spinning until the session arrives, so no settle.
    await tester.pump(const Duration(milliseconds: 300));
    expect(gateway.calls, <String>['signIn:amir@example.com:hunter2000']);
  });

  testWidgets('a rejected password is said in words', (tester) async {
    gateway.failWith = const AuthFailure(AuthFailureKind.invalidCredentials);
    await pumpLogin(tester);
    await tester.pumpAndSettle();
    await signIn(tester, 'amir@example.com', 'wrong-one');
    await tester.pumpAndSettle();
    expect(find.text('الإيميل أو كلمة السر مش مظبوطة.'), findsOneWidget);
  });

  testWidgets('a typo in the address never leaves the device', (tester) async {
    await pumpLogin(tester);
    await tester.pumpAndSettle();
    await signIn(tester, 'amir-at-example.com', 'hunter2000');
    await tester.pumpAndSettle();
    expect(gateway.calls, isEmpty);
  });

  testWidgets('while the request is in flight the button spins', (
    tester,
  ) async {
    gateway.gate = Completer<void>();
    await pumpLogin(tester);
    await tester.pumpAndSettle();
    await signIn(tester, 'amir@example.com', 'hunter2000');
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    gateway.gate!.complete();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('«سجل الآن» opens sign-up with the terms to accept', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('سجل الآن'));
    await tester.tap(find.text('سجل الآن'));
    await tester.pumpAndSettle();
    expect(find.text('اسم المستخدم'), findsOneWidget);
    expect(find.text('الشروط وسياسة الخصوصية'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(submit('إنشاء حساب')).onPressed,
      isNull,
    );
  });

  testWidgets('«نسيت كلمة المرور؟» sends the reset link', (tester) async {
    await pumpLogin(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('نسيت كلمة المرور؟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نسيت كلمة المرور؟'));
    await tester.pumpAndSettle();
    expect(find.text('استعادة كلمة المرور'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'البريد الإلكتروني').last,
      'amir@example.com',
    );
    await tester.tap(find.text('إرسال'));
    await tester.pumpAndSettle();
    expect(gateway.calls, <String>['reset:amir@example.com']);
    expect(find.text('تم إرسال الرابط بنجاح!'), findsOneWidget);
  });

  testWidgets('the password can be revealed', (tester) async {
    await pumpLogin(tester);
    await tester.pumpAndSettle();
    TextField password() => tester.widget<TextField>(passwordField());
    expect(password().obscureText, isTrue);
    await tester.tap(find.byTooltip('إظهار/إخفاء كلمة المرور'));
    await tester.pump();
    expect(password().obscureText, isFalse);
  });
}
