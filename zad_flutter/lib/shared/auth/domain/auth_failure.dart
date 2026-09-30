/// Why an authentication attempt failed, in terms a screen can act on.
///
/// The point of this file is that the customer is told the *right* thing. A
/// person who is offline and a person who mistyped their password both get an
/// error back from the same call, and telling the first one "wrong password"
/// sends them off to reset a password that was never wrong.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The only question the login screen asks about an error.
enum AuthFailureKind {
  /// The email and password do not go together — or the account does not
  /// exist. The server deliberately does not distinguish the two, and neither
  /// does this app: saying "no such account" tells anyone who asks which of
  /// your customers' addresses are registered.
  invalidCredentials,

  /// Signing up with an address that already has an account.
  emailTaken,

  /// The password is too short or too guessable for the project's policy.
  weakPassword,

  /// The address is not a valid email.
  invalidEmail,

  /// The account exists but its address was never confirmed.
  emailNotConfirmed,

  /// Too many attempts, too quickly.
  rateLimited,

  /// New accounts are turned off for this project.
  signupDisabled,

  /// The account has been suspended.
  userBanned,

  /// The request never reached a verdict: no network, or a timeout.
  offline,

  /// The service answered, and what it answered was 5xx.
  serverError,

  /// Nothing above matched. Carries the server's own words so an
  /// unclassified failure is still diagnosable from a screenshot.
  unknown,
}

/// A failure, classified, with the sentence to show for it.
@immutable
class AuthFailure implements Exception {
  /// Creates a failure.
  const new(this.kind, {this.detail});

  /// What went wrong.
  final AuthFailureKind kind;

  /// The underlying message, kept only for [AuthFailureKind.unknown].
  final String? detail;

  /// What to put in front of the customer.
  String get message => switch (kind) {
    AuthFailureKind.invalidCredentials => 'الإيميل أو كلمة السر مش مظبوطة.',
    AuthFailureKind.emailTaken =>
      'الإيميل ده مسجّل قبل كده. جرّب تدخل بيه، أو غيّر كلمة السر.',
    AuthFailureKind.weakPassword => 'كلمة السر قصيرة — خليها ٦ حروف على الأقل.',
    AuthFailureKind.invalidEmail => 'الإيميل ده شكله مش مظبوط.',
    AuthFailureKind.emailNotConfirmed =>
      'لسه محتاج تأكّد الإيميل. بصّ في رسايلك على اللينك اللي بعتناه.',
    AuthFailureKind.rateLimited =>
      'جرّبت مرات كتير في وقت قصير. استنى شوية وحاول تاني.',
    AuthFailureKind.signupDisabled => 'التسجيل مقفول دلوقتي.',
    AuthFailureKind.userBanned => 'الحساب ده موقوف.',
    AuthFailureKind.offline => 'مفيش اتصال بالنت — الدخول محتاج نت.',
    AuthFailureKind.serverError =>
      'الخدمة مش بتردّ دلوقتي. حاول تاني بعد شوية.',
    AuthFailureKind.unknown => 'حصل خطأ مش متوقع. حاول تاني.',
  };

  @override
  String toString() =>
      'AuthFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}

/// Classifies [error].
///
/// **The order of the checks is the whole function.**
/// `AuthRetryableFetchException` *extends* `AuthException`, and gotrue
/// throws it for every transport failure
/// (`fetch.dart` wraps anything that is not a `Response` in one) as well as for
/// any 5xx. Matching the parent type first would tell a customer standing in a
/// lift with no signal that their password is wrong.
///
/// The codes are matched as **strings, not through gotrue's `ErrorCode` enum**,
/// because that enum does not contain `invalid_credentials` — the single most
/// common failure a login screen will ever see. Probed live against this
/// project on 2026-09-20: a wrong password answers
/// `400 {"error_code":"invalid_credentials"}` and a 5-character password
/// answers `422 {"error_code":"weak_password", ... "reasons":["length"]}`.
AuthFailure classifyAuthFailure(Object error) {
  if (error is AuthRetryableFetchException) {
    // No status at all means the request never got an answer. A status means
    // it did, and it was a 5xx — gotrue routes those here too.
    final status = int.tryParse(error.statusCode ?? '');
    return AuthFailure(
      status == null ? AuthFailureKind.offline : AuthFailureKind.serverError,
    );
  }

  // The transport's own exceptions, for the paths that do not go through
  // gotrue's wrapper. Same three the outbox treats as "no verdict reached".
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException) {
    return const AuthFailure(AuthFailureKind.offline);
  }

  if (error is AuthWeakPasswordException) {
    return const AuthFailure(AuthFailureKind.weakPassword);
  }

  if (error is AuthException) {
    final kind = switch (error.code) {
      'invalid_credentials' ||
      'invalid_grant' => AuthFailureKind.invalidCredentials,
      'email_exists' || 'user_already_exists' => AuthFailureKind.emailTaken,
      'weak_password' => AuthFailureKind.weakPassword,
      'validation_failed' ||
      'email_address_invalid' => AuthFailureKind.invalidEmail,
      'email_not_confirmed' => AuthFailureKind.emailNotConfirmed,
      'over_request_rate_limit' ||
      'over_email_send_rate_limit' => AuthFailureKind.rateLimited,
      'signup_disabled' => AuthFailureKind.signupDisabled,
      'user_banned' => AuthFailureKind.userBanned,
      // No code, or one nobody has classified yet. Fall back to the status,
      // which at least separates "too many attempts" from everything else.
      _ => switch (int.tryParse(error.statusCode ?? '')) {
        429 => AuthFailureKind.rateLimited,
        final int s when s >= 500 => AuthFailureKind.serverError,
        _ => AuthFailureKind.unknown,
      },
    };

    return AuthFailure(
      kind,
      detail: kind == AuthFailureKind.unknown ? error.message : null,
    );
  }

  return AuthFailure(AuthFailureKind.unknown, detail: error.toString());
}
