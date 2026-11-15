// The way in, through the widgets.
//
// The screen owns no cache: everything it can do goes through the gateway, so a
// fake one is the harness. The only store it touches is the companion orb's
// (Zado's accessory and look), so that one is in-memory boxes. The orb and the
// hero animate for ever, so nothing here pumps until it settles: `settle`
// is a bounded pump.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/app_language.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/auth/presentation/login_screen.dart';
import 'package:zad/shared/auth/data/auth_gateway.dart';
import 'package:zad/shared/auth/domain/auth_failure.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

class _FakeGateway implements AuthGateway {
  final List<String> calls = <String>[];
  String? signUpMarket;
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
    String? country,
    String? currency,
  }) async {
    signUpMarket = country == null ? null : '$country/$currency';
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
  late ZadLocalStore store;

  setUp(() async {
    gateway = _FakeGateway();
    Hive.init('unused');
    Future<Box<String>> box(String name) =>
        Hive.openBox<String>(name, bytes: Uint8List(0));
    store = ZadLocalStore(
      outbox: await box('outbox'),
      transactions: await box('transactions'),
      documents: await box('documents'),
      chat: await box('chat'),
      inventory: await box('inventory'),
      shopping: await box('shopping'),
      pharmacy: await box('pharmacy'),
      subscriptions: await box('subscriptions'),
      device: await box('device'),
    );
  });

  tearDown(Hive.close);

  List<Override> overrides() => <Override>[
    authGatewayProvider.overrideWithValue(gateway),
    localStoreProvider.overrideWithValue(store),
  ];

  /// Time passes, but no more than that: the hero never stops animating.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> pumpLogin(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: overrides(),
      child: MaterialApp(
        theme: ZadTheme.light(),
        locale: const Locale('ar'),
        home: const LoginScreen(),
      ),
    ),
  );

  Future<void> openSignUp(WidgetTester tester) async {
    await pumpLogin(tester);
    await settle(tester);
    await tester.ensureVisible(find.text('سجل الآن'));
    await tester.tap(find.text('سجل الآن'));
    await settle(tester);
  }

  /// The consent row's link opens the sheet; accepting it ticks the box.
  Future<void> acceptTerms(WidgetTester tester) async {
    final link = find.text('الشروط وسياسة الخصوصية');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await settle(tester);
    await tester.tap(find.text('موافق ومتابعة'));
    await settle(tester);
  }

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
    await settle(tester);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('اسم المستخدم'), findsNothing);
  });

  testWidgets('signed out, Zado is the intro\'s character, not the ball', (
    tester,
  ) async {
    // No account means no saved companion; without a look the orb drew the
    // classic ball on the emulator (15/11) while the intro drew Zado.
    await pumpLogin(tester);
    await settle(tester);
    final orb = tester.widget<CompanionOrb>(find.byType(CompanionOrb).first);
    expect(orb.look, const CompanionLook());
    expect(orb.look!.persona, CompanionPersona.zado);
  });

  testWidgets('the button waits for an email and a password', (tester) async {
    await pumpLogin(tester);
    await settle(tester);
    expect(tester.widget<ElevatedButton>(submit('دخول')).onPressed, isNull);
  });

  testWidgets('signs in with exactly what was typed', (tester) async {
    await pumpLogin(tester);
    await settle(tester);
    await signIn(tester, 'amir@example.com', 'hunter2000');
    // The button keeps spinning until the session arrives, so no settle.
    await tester.pump(const Duration(milliseconds: 300));
    expect(gateway.calls, <String>['signIn:amir@example.com:hunter2000']);
  });

  testWidgets('a rejected password is said in words', (tester) async {
    gateway.failWith = const AuthFailure(AuthFailureKind.invalidCredentials);
    await pumpLogin(tester);
    await settle(tester);
    await signIn(tester, 'amir@example.com', 'wrong-one');
    await settle(tester);
    expect(find.text('الإيميل أو كلمة السر مش مظبوطة.'), findsOneWidget);
  });

  testWidgets('a typo in the address never leaves the device', (tester) async {
    await pumpLogin(tester);
    await settle(tester);
    await signIn(tester, 'amir-at-example.com', 'hunter2000');
    await settle(tester);
    expect(gateway.calls, isEmpty);
  });

  testWidgets('while the request is in flight the button spins', (
    tester,
  ) async {
    gateway.gate = Completer<void>();
    await pumpLogin(tester);
    await settle(tester);
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
    await openSignUp(tester);
    expect(find.text('اسم المستخدم'), findsOneWidget);
    expect(find.text('الشروط وسياسة الخصوصية'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(submit('إنشاء حساب')).onPressed,
      isNull,
    );
    // The terms are asked for through the consent sheet: accepting it ticks
    // the box (the button stays shut until the rest is filled in).
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await acceptTerms(tester);
    expect(find.text('موافق ومتابعة'), findsNothing);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });

  testWidgets('sign-up asks for the country and sends it with the account', (
    tester,
  ) async {
    await openSignUp(tester);

    await tester.enterText(find.byType(TextField).at(0), 'أمير');
    await tester.enterText(find.byType(TextField).at(1), 'amir@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret123');
    await acceptTerms(tester);
    // Everything but the country: still closed.
    expect(
      tester.widget<ElevatedButton>(submit('إنشاء حساب')).onPressed,
      isNull,
    );

    final field = find.byKey(const ValueKey<String>('sign-up-market'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await settle(tester);
    await tester.tap(find.text('مصر'));
    await settle(tester);
    expect(find.textContaining('مصر'), findsOneWidget);

    await tester.ensureVisible(submit('إنشاء حساب'));
    await tester.tap(submit('إنشاء حساب'));
    await tester.pump();
    expect(gateway.calls, <String>['signUp:amir@example.com:أمير']);
    expect(gateway.signUpMarket, 'EG/EGP');
    await tester.pump(const Duration(seconds: 2));
  });

  // Emulator, 2026-11-01: closing the picker gave focus back to the email
  // field, the keyboard came up again and covered the password field.
  testWidgets('choosing the country does not bring the keyboard back', (
    tester,
  ) async {
    await openSignUp(tester);

    await tester.tap(find.byType(TextField).at(1));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    final field = find.byKey(const ValueKey<String>('sign-up-market'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await settle(tester);
    await tester.tap(find.text('مصر'));
    await settle(tester);

    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('«نسيت كلمة المرور؟» sends the reset link', (tester) async {
    await pumpLogin(tester);
    await settle(tester);
    await tester.ensureVisible(find.text('نسيت كلمة المرور؟'));
    await settle(tester);
    await tester.tap(find.text('نسيت كلمة المرور؟'));
    await settle(tester);
    expect(find.text('استعادة كلمة المرور'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'البريد الإلكتروني').last,
      'amir@example.com',
    );
    await tester.tap(find.text('إرسال'));
    await settle(tester);
    expect(gateway.calls, <String>['reset:amir@example.com']);
    expect(find.text('تم إرسال الرابط بنجاح!'), findsOneWidget);
  });

  // ZAD_PLAN ٠.١٠: the dialog used to swallow any failure, so a reset that
  // never left the phone looked like one that did.
  testWidgets('a refused reset says why instead of looking sent', (
    tester,
  ) async {
    gateway.failWith = const AuthFailure(AuthFailureKind.rateLimited);
    await pumpLogin(tester);
    await settle(tester);
    await tester.ensureVisible(find.text('نسيت كلمة المرور؟'));
    await settle(tester);
    await tester.tap(find.text('نسيت كلمة المرور؟'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'البريد الإلكتروني').last,
      'amir@example.com',
    );
    await tester.tap(find.text('إرسال'));
    await settle(tester);
    expect(find.text('تم إرسال الرابط بنجاح!'), findsNothing);
    expect(
      find.text('جرّبت مرات كتير في وقت قصير. استنى شوية وحاول تاني.'),
      findsOneWidget,
    );
  });

  testWidgets('the password can be revealed', (tester) async {
    await pumpLogin(tester);
    await settle(tester);
    TextField password() => tester.widget<TextField>(passwordField());
    expect(password().obscureText, isTrue);
    await tester.tap(find.byTooltip('إظهار/إخفاء كلمة المرور'));
    await tester.pump();
    expect(password().obscureText, isFalse);
  });

  testWidgets('in English it reads English, left to right (ZAD_PLAN 6.3)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: ZadTheme.light(),
          locale: const Locale('en'),
          supportedLocales: kZadLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            ZadL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(find.text('Sign up now'), findsOneWidget);
    expect(find.text('نسيت كلمة المرور؟'), findsNothing);
    expect(
      Directionality.of(tester.element(find.text('Sign up now'))),
      TextDirection.ltr,
    );
    const failure = AuthFailure(AuthFailureKind.offline);
    expect(
      failure.localized(lookupZadL10n(const Locale('en'))),
      'No internet connection — signing in needs one.',
    );
  });
}
