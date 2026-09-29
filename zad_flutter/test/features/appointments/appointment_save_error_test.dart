import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/appointments/presentation/appointments_screen.dart';

void main() {
  test('each failure says what to do about it', () {
    expect(
      appointmentSaveError(
        const PostgrestException(message: 'x', code: '23514'),
      ),
      contains('من ٢ لـ١٦٠ حرف'),
    );
    expect(
      appointmentSaveError(
        const PostgrestException(message: 'x', code: '42501'),
      ),
      contains('الجلسة انتهت'),
    );
    expect(
      appointmentSaveError(const SocketException('offline')),
      contains('مفيش نت'),
    );
    expect(appointmentSaveError(TimeoutException('slow')), contains('مفيش نت'));
    expect(
      appointmentSaveError(StateError('?')),
      'ماتسجلش الميعاد، جرّب تاني.',
    );
  });
}
