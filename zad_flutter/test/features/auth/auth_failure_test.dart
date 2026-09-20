// What the customer is told when a sign-in does not work.
//
// The load-bearing case is the first group: gotrue reports "no network" by
// throwing a *subclass* of the same exception it uses for "wrong password", so
// a classifier that checks the parent type first tells somebody with no signal
// that their password is wrong and sends them to reset it.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/auth/domain/auth_failure.dart';

void main() {
  group('a failure that never reached the server', () {
    test('AuthRetryableFetchException with no status is offline, not a '
        'credentials error', () {
      // Exactly what gotrue's fetch.dart throws when the request itself fails:
      // `if (error is! Response) throw AuthRetryableFetchException(...)`.
      final failure = classifyAuthFailure(
        AuthRetryableFetchException(message: 'Failed host lookup'),
      );

      expect(failure.kind, AuthFailureKind.offline);
      expect(
        failure.kind,
        isNot(AuthFailureKind.invalidCredentials),
        reason:
            'AuthRetryableFetchException extends AuthException — checking '
            'the parent first would blame the password',
      );
    });

    test('the same exception carrying a 5xx is a server error', () {
      final failure = classifyAuthFailure(
        AuthRetryableFetchException(message: 'oops', statusCode: '503'),
      );

      expect(failure.kind, AuthFailureKind.serverError);
    });

    test('the transport exceptions are offline', () {
      for (final error in <Object>[
        const SocketException('no route to host'),
        TimeoutException('gave up'),
        const HttpException('dropped'),
      ]) {
        expect(
          classifyAuthFailure(error).kind,
          AuthFailureKind.offline,
          reason: '$error',
        );
      }
    });
  });

  group('codes the server actually sends', () {
    test("invalid_credentials — which is NOT in gotrue's ErrorCode enum", () {
      // Probed live against this project 2026-09-20:
      //   POST /auth/v1/token?grant_type=password
      //   → 400 {"error_code":"invalid_credentials"}
      // gotrue's own `ErrorCode` enum has no entry for it, so matching through
      // that enum would leave the commonest login failure unclassified.
      final failure = classifyAuthFailure(
        const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );

      expect(failure.kind, AuthFailureKind.invalidCredentials);
      expect(failure.message, contains('كلمة السر'));
    });

    test('weak_password, at the length this project enforces', () {
      // → 422 {"error_code":"weak_password","msg":"Password should be at
      //        least 6 characters."}
      final failure = classifyAuthFailure(
        const AuthApiException(
          'Password should be at least 6 characters.',
          statusCode: '422',
          code: 'weak_password',
        ),
      );

      expect(failure.kind, AuthFailureKind.weakPassword);
    });

    test('an already-registered address', () {
      for (final code in <String>['email_exists', 'user_already_exists']) {
        expect(
          classifyAuthFailure(
            AuthApiException('taken', statusCode: '422', code: code),
          ).kind,
          AuthFailureKind.emailTaken,
          reason: code,
        );
      }
    });

    test('rate limiting, by code and by bare status', () {
      expect(
        classifyAuthFailure(
          const AuthApiException(
            'slow down',
            statusCode: '429',
            code: 'over_email_send_rate_limit',
          ),
        ).kind,
        AuthFailureKind.rateLimited,
      );

      // Same verdict with no code at all, which is what an edge proxy in front
      // of the service will produce.
      expect(
        classifyAuthFailure(
          const AuthApiException('slow down', statusCode: '429'),
        ).kind,
        AuthFailureKind.rateLimited,
      );
    });

    test('an unconfirmed address is its own message, not a wrong password', () {
      final failure = classifyAuthFailure(
        const AuthApiException(
          'Email not confirmed',
          statusCode: '400',
          code: 'email_not_confirmed',
        ),
      );

      expect(failure.kind, AuthFailureKind.emailNotConfirmed);
      expect(failure.message, contains('رسايلك'));
    });
  });

  group('anything else', () {
    test("keeps the server's own words so a screenshot is diagnosable", () {
      final failure = classifyAuthFailure(
        const AuthApiException(
          'mfa_verification_rejected',
          statusCode: '403',
          code: 'mfa_verification_rejected',
        ),
      );

      expect(failure.kind, AuthFailureKind.unknown);
      expect(failure.detail, 'mfa_verification_rejected');
    });

    test('a non-auth object still classifies rather than throwing', () {
      expect(
        classifyAuthFailure(StateError('something else entirely')).kind,
        AuthFailureKind.unknown,
      );
    });

    test('every kind has a message, and none of them is empty', () {
      for (final kind in AuthFailureKind.values) {
        expect(AuthFailure(kind).message, isNotEmpty, reason: kind.name);
      }
    });
  });
}
