import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/shared/quota/domain/server_refusal.dart';

void main() {
  test('402: the balance, in the server words', () {
    final r = serverRefusal(
      const FunctionsHttpException(
        status: 402,
        details: <String, dynamic>{
          'error': 'no_attempts',
          'message': 'رصيد محاولاتك مايكفيش قراية الصورة',
        },
      ),
    );
    expect(r?.title, 'رصيد المحاولات مايكفيش');
    expect(r?.message, 'رصيد محاولاتك مايكفيش قراية الصورة');
  });

  test('429: too fast, also when the body arrived as text', () {
    final r = serverRefusal(
      const FunctionsHttpException(
        status: 429,
        details: '{"error":"too_fast","message":"بالراحة عليّ شوية"}',
      ),
    );
    expect(r?.title, 'استنى شوية');
    expect(r?.message, 'بالراحة عليّ شوية');
  });

  test('anything else is the screen own failure, not a refusal', () {
    expect(
      serverRefusal(
        const FunctionsHttpException(
          status: 500,
          details: <String, dynamic>{'message': 'boom'},
        ),
      ),
      isNull,
    );
    expect(
      serverRefusal(const FunctionsHttpException(status: 402, details: 'x')),
      isNull,
    );
    expect(serverRefusal(StateError('offline')), isNull);
    expect(serverRefusal(null), isNull);
  });
}
