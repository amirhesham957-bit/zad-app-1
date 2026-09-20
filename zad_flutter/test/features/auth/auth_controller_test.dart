// The login form's behaviour, without a screen.
//
// The two claims worth holding: a typo never costs a round trip, and a failed
// attempt never leaves the button stuck.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/auth/application/auth_controller.dart';
import 'package:zad/features/auth/data/auth_gateway.dart';
import 'package:zad/features/auth/domain/auth_failure.dart';

class _FakeGateway implements AuthGateway {
  final List<String> calls = <String>[];
  final StreamController<String?> ids = StreamController<String?>.broadcast();

  String? userId;
  AuthFailure? failWith;
  SignUpOutcome signUpOutcome = SignUpOutcome.signedIn;

  /// Held open so a test can look at the form mid-flight.
  Completer<void>? gate;

  @override
  String? get currentUserId => userId;

  @override
  Stream<String?> get userIdChanges => ids.stream;

  Future<void> _run(String call) async {
    calls.add(call);
    if (gate case final g?) await g.future;
    if (failWith case final f?) throw f;
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _run('signIn:$email');

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    await _run('signUp:$email:$name');
    return signUpOutcome;
  }

  @override
  Future<void> sendPasswordReset(String email) => _run('reset:$email');

  @override
  Future<void> signOut() => _run('signOut');
}

void main() {
  late _FakeGateway gateway;
  late ProviderContainer container;

  setUp(() {
    gateway = _FakeGateway();
    container = ProviderContainer(
      overrides: [authGatewayProvider.overrideWithValue(gateway)],
    );
  });

  tearDown(() async {
    container.dispose();
    await gateway.ids.close();
  });

  AuthController controller() =>
      container.read(authControllerProvider.notifier);
  AuthFormState form() => container.read(authControllerProvider);

  Future<void> submit({
    String email = 'someone@example.com',
    String password = 'hunter2000',
    String name = '',
  }) => controller().submit(email: email, password: password, name: name);

  group('what never reaches the network', () {
    test('an address with no @ is refused locally', () async {
      await submit(email: 'someone.example.com');

      expect(form().failure?.kind, AuthFailureKind.invalidEmail);
      expect(gateway.calls, isEmpty, reason: 'a typo is not worth a request');
    });

    test('a password under the measured minimum is refused locally', () async {
      await submit(password: '12345');

      expect(form().failure?.kind, AuthFailureKind.weakPassword);
      expect(gateway.calls, isEmpty);
      expect(kMinPasswordLength, 6, reason: 'probed against this project');
    });

    test('whitespace around the address is trimmed, not rejected', () async {
      await submit(email: '  someone@example.com  ');

      expect(form().failure, isNull);
      expect(gateway.calls, <String>['signIn:someone@example.com']);
    });

    test(
      'a reset needs no password — the whole point is not having one',
      () async {
        controller().setMode(AuthMode.resetPassword);
        await submit(password: '');

        expect(form().failure, isNull);
        expect(gateway.calls, <String>['reset:someone@example.com']);
      },
    );
  });

  group('signing in', () {
    test('success leaves the form alone — the gate swaps the screen', () async {
      await submit();

      expect(form().failure, isNull);
      expect(form().notice, isNull);
    });

    test('a failure is shown and the button comes back', () async {
      gateway.failWith = const AuthFailure(AuthFailureKind.invalidCredentials);
      await submit();

      expect(form().failure?.kind, AuthFailureKind.invalidCredentials);
      expect(
        form().submitting,
        isFalse,
        reason: 'a stuck spinner is worse than the error itself',
      );
    });

    test('a second tap while the first is in flight does nothing', () async {
      gateway.gate = Completer<void>();
      final first = submit();
      await Future<void>.delayed(Duration.zero);
      expect(form().submitting, isTrue);

      await submit();
      expect(gateway.calls, hasLength(1));

      gateway.gate!.complete();
      await first;
    });
  });

  group('signing up', () {
    test(
      'the name goes with the request, for the provisioning trigger',
      () async {
        controller().setMode(AuthMode.signUp);
        await submit(name: '  أمير  ');

        expect(gateway.calls, <String>['signUp:someone@example.com:  أمير  ']);
      },
    );

    test('no session back means a confirmation email, said out loud', () async {
      controller().setMode(AuthMode.signUp);
      gateway.signUpOutcome = SignUpOutcome.confirmationSent;
      await submit();

      expect(form().notice, contains('someone@example.com'));
      expect(form().failure, isNull);
    });

    test(
      'a session back says nothing — the gate is about to take over',
      () async {
        controller().setMode(AuthMode.signUp);
        await submit();

        expect(form().notice, isNull);
      },
    );
  });

  group('switching modes', () {
    test("drops the previous mode's error", () async {
      gateway.failWith = const AuthFailure(AuthFailureKind.invalidCredentials);
      await submit();
      expect(form().failure, isNotNull);

      controller().setMode(AuthMode.signUp);

      expect(form().failure, isNull);
      expect(form().mode, AuthMode.signUp);
    });

    test(
      'a sent reset link drops the customer back on sign-in, told so',
      () async {
        controller().setMode(AuthMode.resetPassword);
        await submit(password: '');

        expect(form().mode, AuthMode.signIn);
        expect(form().notice, isNotNull);
      },
    );
  });
}
