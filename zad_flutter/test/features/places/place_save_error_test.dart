// «أماكني»: a failed save says what happened in words, not a bare code.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;
import 'package:zad/features/places/presentation/my_places_screen.dart';

void main() {
  test('a refused session says to sign in again', () {
    const rls = PostgrestException(message: 'denied', code: '42501');
    expect(placeSaveError(rls), contains('الجلسة انتهت'));
    expect(
      placeSaveError(const AuthException('expired')),
      contains('الجلسة انتهت'),
    );
    expect(placeSaveError(rls), isNot(contains('42501')));
  });

  test('no network says so', () {
    expect(placeSaveError(TimeoutException('slow')), contains('مفيش نت'));
    expect(placeSaveError(const SocketException('down')), contains('مفيش نت'));
  });

  test('an unknown server code is kept, after a sentence, for support', () {
    const other = PostgrestException(message: 'check', code: '23514');
    expect(placeSaveError(other), 'السيرفر رفض التذكير (23514). جرّب تاني.');
  });

  test('anything else is a plain retry, with no code', () {
    expect(placeSaveError(StateError('x')), 'ماتسجلش التذكير، جرّب تاني.');
  });
}
