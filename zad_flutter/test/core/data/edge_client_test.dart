import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/edge_client.dart';

class _MockClient extends Mock implements SupabaseClient;

class _MockFunctions extends Mock implements FunctionsClient;

void main() {
  setUpAll(() => registerFallbackValue(HttpMethod.post));

  late _MockClient client;
  late _MockFunctions functions;

  setUp(() {
    client = _MockClient();
    functions = _MockFunctions();
    when(() => client.functions).thenReturn(functions);
  });

  void stubInvoke() {
    when(
      () => functions.invoke(
        any(),
        body: any(named: 'body'),
        headers: any(named: 'headers'),
        method: any(named: 'method'),
      ),
    ).thenAnswer((_) async => const FunctionResponse(data: 'ok', status: 200));
  }

  test(
    'adds a trace header, unique per call, and passes the rest through',
    () async {
      stubInvoke();
      final body = <String, dynamic>{'action': 'x'};
      await invokeEdge(client, 'zad-brain', body: body, headers: {'a': 'b'});
      await invokeEdge(client, 'zad-brain', body: body, headers: {'a': 'b'});

      final calls = verify(
        () => functions.invoke(
          'zad-brain',
          body: body,
          headers: captureAny(named: 'headers'),
          method: any(named: 'method'),
        ),
      ).captured.cast<Map<String, String>>();
      expect(calls, hasLength(2));
      for (final h in calls) {
        expect(h['a'], 'b');
        expect(h[traceHeader], matches(RegExp(r'^[0-9a-f]{32}$')));
      }
      expect(calls[0][traceHeader], isNot(calls[1][traceHeader]));
    },
  );

  test('keeps the method and returns the response untouched', () async {
    stubInvoke();
    final r = await invokeEdge(
      client,
      'delete-account',
      method: HttpMethod.get,
    );
    expect(r.data, 'ok');
    verify(
      () => functions.invoke(
        'delete-account',
        headers: any(named: 'headers'),
        method: HttpMethod.get,
      ),
    ).called(1);
  });

  test('rethrows the original exception type', () async {
    when(
      () => functions.invoke(
        any(),
        body: any(named: 'body'),
        headers: any(named: 'headers'),
        method: any(named: 'method'),
      ),
    ).thenThrow(const FunctionException(status: 500, details: 'boom'));
    expect(invokeEdge(client, 'zad-brain'), throwsA(isA<FunctionException>()));
  });
}
