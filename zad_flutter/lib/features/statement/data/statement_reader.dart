/// `analyze_statement` on zad-core-intelligence: a statement photo or PDF
/// read into rows and checked against its own balance (ZAD_PLAN ٣.٣).
/// Nothing is written here — the rows go to the same review as a CSV.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// Reads statements off files.
abstract interface class StatementReader {
  /// The server's `statement` object, or null when nothing could be read.
  /// Throws on transport failure and on the meter's refusals (402/429).
  Future<Map<String, dynamic>?> read({
    required String userId,
    required Uint8List bytes,
    required String mimeType,
  });
}

/// The real call.
class SupabaseStatementReader implements StatementReader {
  /// Creates a reader over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> read({
    required String userId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final response = await _client.functions.invoke(
      'zad-core-intelligence',
      body: <String, dynamic>{
        'action': 'analyze_statement',
        'user_id': userId,
        'payload': <String, dynamic>{
          'file_base64': base64Encode(bytes),
          'mime_type': mimeType,
        },
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw StateError('analyze_statement answered ${data.runtimeType}');
    }
    final statement = data['statement'];
    return statement is Map ? Map<String, dynamic>.from(statement) : null;
  }
}

/// The app's statement reader.
final statementReaderProvider = Provider<StatementReader>(
  (ref) => SupabaseStatementReader(ref.watch(supabaseClientProvider)),
);
