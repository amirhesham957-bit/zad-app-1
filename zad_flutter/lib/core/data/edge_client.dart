/// Every edge-function call goes through [invokeEdge] so one trace id follows
/// a user action from the button, through the function, into the `zad_events`
/// row and Sentry (P1.7).
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The header the edge functions read the trace id from.
const String traceHeader = 'x-zad-trace-id';

final Random _random = Random.secure();

/// A fresh 32-hex trace id (the server accepts `[A-Za-z0-9_-]{8,64}`).
String newTraceId() => List<String>.generate(
  16,
  (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

/// `client.functions.invoke(name, ...)` plus the trace header, a Sentry tag and
/// breadcrumb. Same arguments, same return, same exception type: on failure the
/// trace id is logged and the original error is rethrown untouched.
Future<FunctionResponse> invokeEdge(
  SupabaseClient client,
  String name, {
  Object? body,
  Map<String, String>? headers,
  HttpMethod method = HttpMethod.post,
}) async {
  final traceId = newTraceId();
  _tell(name, traceId);
  try {
    return await client.functions.invoke(
      name,
      body: body,
      headers: <String, String>{...?headers, traceHeader: traceId},
      method: method,
    );
  } on Object catch (e) {
    debugPrint('[edge] $name trace=$traceId failed: $e');
    rethrow;
  }
}

void _tell(String name, String traceId) {
  try {
    unawaited(
      Future<void>.sync(
        () => Sentry.configureScope((s) => s.setTag('trace_id', traceId)),
      ).catchError((Object _) {}),
    );
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'edge $name',
          category: 'edge',
          data: <String, dynamic>{'trace_id': traceId},
        ),
      ),
    );
  } on Object {
    // Telemetry must never break the call (no Sentry in tests or when off).
  }
}
