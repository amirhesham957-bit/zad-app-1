/// One row of `zad_memory`: something زاد learned about the customer and will
/// bring into every conversation after.
///
/// The same rows `zad-brain` and the Telegram bot read as context. The
/// customer can see them and make زاد forget one, and nothing else: there is no
/// editing the text, because anything typed here would come back to the model
/// later as a trusted fact about the customer.
library;

import 'package:flutter/foundation.dart';

/// A note.
@immutable
class MemoryNote {
  /// Creates a note.
  const new({
    required this.id,
    required this.scope,
    required this.note,
    this.confidence = 0.5,
    this.evidenceCount = 1,
    this.validUntil,
    this.about = const <String>[],
  });

  /// Reads a row.
  factory fromJson(Map<String, dynamic> json) => MemoryNote(
    id: json['id'] as String,
    scope: (json['scope'] as String?) ?? 'general',
    note: (json['note'] as String?) ?? '',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    evidenceCount: (json['evidence_count'] as num?)?.toInt() ?? 1,
    validUntil: DateTime.tryParse((json['valid_until'] as String?) ?? ''),
    about: <String>[
      for (final a in (json['about'] as List<dynamic>?) ?? const <dynamic>[])
        if (a is String && a.isNotEmpty) a,
    ],
  );

  /// The row id.
  final String id;

  /// What kind of thing it is — `general`, `spending_pattern`, … .
  final String scope;

  /// The note, in the brain's words.
  final String note;

  /// How sure the brain is, 0–1.
  final double confidence;

  /// How many times the same thing was seen again. `zad_memory_upsert` counts
  /// a repeat instead of writing a second row, so this is how a note that was
  /// said once differs from one confirmed nine times.
  final int evidenceCount;

  /// The first instant a temporary note («أخويا عندنا لحد الجمعة») stops being
  /// true; null for a lasting one. The server stops sending it after that, but
  /// the cached list can still hold it until the next refresh.
  final DateTime? validUntil;

  /// Who or what the note is about («ماما»، «قهوة») — its
  /// `zad_memory_entities` names.
  final List<String> about;

  /// Whether the note still holds at [now].
  bool isLiveAt(DateTime now) => validUntil?.isAfter(now) ?? true;

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'scope': scope,
    'note': note,
    'confidence': confidence,
    'evidence_count': evidenceCount,
    'valid_until': ?validUntil?.toUtc().toIso8601String(),
    'about': about,
  };
}

/// What the customer reads for a note's scope.
///
/// Every scope on the live project on 2026-09-21. Kotlin printed the scope
/// itself on the chip, so the customer read `spending_pattern`.
String memoryScopeLabel(String scope) => switch (scope) {
  'general' => 'عنك',
  'spending_pattern' => 'صرفك',
  'cycle_pattern' => 'دورة القبض',
  'weekly_synthesis' => 'ملخص الأسبوع',
  'data_quality' => 'دقة البيانات',
  'dismissal' || 'proactive_dismissal' => 'تنبيه رفضته',
  _ => 'ملاحظة',
};
