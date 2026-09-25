/// The two photo reads besides the receipt — Kotlin's camera modes:
/// `analyze_inventory_image` (a shelf or a fridge, several items) and
/// `analyze_medicine_image` (one box). Same function, same key pool, same
/// JPEG as the receipt; asked only when the customer takes the photo.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// One item read off a pantry photo.
typedef ScannedPantryItem = ({
  String name,
  int quantity,
  String unit,
  String? category,
});

/// A medicine read off its box.
typedef ScannedMedicine = ({
  String name,
  String? activeIngredient,
  String? dosage,
  String category,
  int quantity,
  String unit,
  DateTime? expiryDate,
  int dailyDoseCount,
  String? doseTimes,
});

/// Reads photos.
abstract interface class VisionScanner {
  /// The items on a pantry photo; empty when it read none.
  Future<List<ScannedPantryItem>> pantry({
    required String userId,
    required Uint8List image,
  });

  /// The medicine on a box photo, or null.
  Future<ScannedMedicine?> medicine({
    required String userId,
    required Uint8List image,
  });
}

/// The real calls.
class SupabaseVisionScanner implements VisionScanner {
  /// Creates a scanner over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> _read(
    String action,
    String userId,
    Uint8List image,
  ) async {
    final response = await _client.functions.invoke(
      'zad-core-intelligence',
      body: <String, dynamic>{
        'action': action,
        'user_id': userId,
        'payload': <String, dynamic>{
          'image_base64': base64Encode(image),
          'mime_type': 'image/jpeg',
        },
      },
    );
    final data = response.data;
    if (data is! Map) throw StateError('$action answered ${data.runtimeType}');
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<List<ScannedPantryItem>> pantry({
    required String userId,
    required Uint8List image,
  }) async =>
      pantryItemsFrom(await _read('analyze_inventory_image', userId, image));

  @override
  Future<ScannedMedicine?> medicine({
    required String userId,
    required Uint8List image,
  }) async =>
      medicineFrom(await _read('analyze_medicine_image', userId, image));
}

/// Reads `analyze_inventory_image`'s answer — Kotlin's parse: a nameless
/// line is dropped, the rest default to one "قطعة".
List<ScannedPantryItem> pantryItemsFrom(Map<String, dynamic> data) =>
    <ScannedPantryItem>[
      for (final raw in (data['items'] as List<dynamic>? ?? <dynamic>[]))
        if (raw is Map && (raw['name'] as String? ?? '').trim().isNotEmpty)
          (
            name: (raw['name'] as String).trim(),
            quantity: ((raw['quantity'] as num?)?.toDouble() ?? 1)
                .round()
                .clamp(1, 999),
            unit: (raw['unit'] as String?)?.trim().isNotEmpty ?? false
                ? (raw['unit'] as String).trim()
                : 'قطعة',
            category: raw['category'] as String?,
          ),
    ];

/// Reads `analyze_medicine_image`'s answer, or null without a name.
ScannedMedicine? medicineFrom(Map<String, dynamic> data) {
  final med = data['medicine'];
  if (med is! Map) return null;
  final name = (med['name'] as String? ?? '').trim();
  if (name.isEmpty) return null;
  final times = med['suggested_times'];
  final expiry = med['expiry_date'];
  return (
    name: name,
    activeIngredient: med['active_ingredient'] as String?,
    dosage: med['dosage'] as String?,
    category: med['category'] as String? ?? 'عام',
    quantity: (med['quantity'] as num?)?.toInt() ?? 1,
    unit: med['unit'] as String? ?? 'قرص',
    expiryDate: expiry is String ? packExpiry(expiry) : null,
    dailyDoseCount: (med['daily_dose_count'] as num?)?.toInt() ?? 1,
    doseTimes: times is List ? times.join(',') : med['dose_times'] as String?,
  );
}

/// A pack's printed expiry as a date: `YYYY-MM-DD` as is, and `YYYY-MM` — the
/// prompt allows it, and most boxes print only a month — as the last day of
/// that month, when the pack stops being good.
DateTime? packExpiry(String raw) {
  final m = RegExp(r'^(\d{4})-(\d{1,2})(?:-(\d{1,2}))?').firstMatch(raw.trim());
  if (m == null) return null;
  final year = int.parse(m[1]!);
  final month = int.parse(m[2]!);
  if (month < 1 || month > 12) return null;
  if (m[3] == null) return DateTime.utc(year, month + 1, 0);
  final day = int.parse(m[3]!);
  final date = DateTime.utc(year, month, day);
  // 2027-02-30 would roll into March; a date the calendar lacks is no date.
  return date.month == month && date.day == day ? date : null;
}
