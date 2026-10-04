/// `analyze_document_image` on zad-core-intelligence: a prescription or a
/// school timetable read off a photo, and the timetable's save
/// (`zad_timetable_replace`, 20261004110000).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/scan/domain/scanned_document.dart';

/// Reads documents and keeps timetables.
abstract interface class DocumentScanner {
  /// The prescription on the photo, or null when nothing could be read.
  Future<ScannedPrescription?> prescription({
    required String userId,
    required Uint8List image,
  });

  /// The timetable on the photo, or null when nothing could be read.
  Future<ScannedTimetable?> timetable({
    required String userId,
    required Uint8List image,
  });

  /// Replaces [person]'s whole timetable with [days]. The number of periods
  /// kept.
  Future<int> saveTimetable({
    required String person,
    required List<TimetableDay> days,
  });
}

/// The real calls.
class SupabaseDocumentScanner implements DocumentScanner {
  /// Creates a scanner over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> _read(
    DocumentKind kind,
    String userId,
    Uint8List image,
  ) async {
    final response = await _client.functions.invoke(
      'zad-core-intelligence',
      body: <String, dynamic>{
        'action': 'analyze_document_image',
        'user_id': userId,
        'payload': <String, dynamic>{
          'image_base64': base64Encode(image),
          'mime_type': 'image/jpeg',
          'kind': kind.wire,
        },
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw StateError('analyze_document_image answered ${data.runtimeType}');
    }
    final document = data['document'];
    return document is Map ? Map<String, dynamic>.from(document) : null;
  }

  @override
  Future<ScannedPrescription?> prescription({
    required String userId,
    required Uint8List image,
  }) async {
    final doc = await _read(DocumentKind.prescription, userId, image);
    if (doc == null) return null;
    final p = ScannedPrescription.fromJson(doc);
    return p.medicines.isEmpty ? null : p;
  }

  @override
  Future<ScannedTimetable?> timetable({
    required String userId,
    required Uint8List image,
  }) async {
    final doc = await _read(DocumentKind.timetable, userId, image);
    if (doc == null) return null;
    final t = ScannedTimetable.fromJson(doc);
    return t.days.isEmpty ? null : t;
  }

  @override
  Future<int> saveTimetable({
    required String person,
    required List<TimetableDay> days,
  }) async {
    final result = await _client.rpc<dynamic>(
      'zad_timetable_replace',
      params: <String, dynamic>{
        'p_person': person,
        'p_days': <Map<String, dynamic>>[for (final d in days) d.toJson()],
      },
    );
    if (result is Map && result['ok'] == true) {
      return (result['periods'] as num?)?.toInt() ?? 0;
    }
    throw StateError('zad_timetable_replace refused: $result');
  }
}

/// The app's document scanner.
final documentScannerProvider = Provider<DocumentScanner>(
  (ref) => SupabaseDocumentScanner(ref.watch(supabaseClientProvider)),
);
