/// The brain's booking guard, asked from the page (ZAD_PLAN ٨ج.٥).
///
/// zad-brain's `booking_check` runs the same `bookingConflicts` the chat's
/// `add_appointment` runs before it writes: another appointment within the
/// hour for the same person, the customer's working hours from their
/// profile, a medicine while they sleep, and a medicine the pharmacy already
/// reminds them of. The page used to save past all of that and warn about
/// clashes only. The server reads the profile, sleep and pharmacy itself, so
/// none of it has to live on the phone.
///
/// Offline, or any failure, is no answer at all and the page saves as
/// before: the guard asks, it never blocks.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// Asks the server what a new appointment would sit on top of.
abstract interface class BookingGuard {
  /// The reasons to ask before saving, in the customer's words — empty when
  /// there are none, null when the server could not be asked.
  Future<List<String>?> check({
    required String title,
    required String kind,
    required DateTime startsAt,
    required String recurrence,
    String? forPerson,
  });
}

/// zad-brain's `booking_check`. Identity is the JWT, never the body.
class SupabaseBookingGuard implements BookingGuard {
  /// Creates the guard.
  const new(this._client);

  final SupabaseClient _client;

  /// Past this the page saves without the answer: a slow guard is not worth
  /// a customer staring at a spinner.
  static const Duration timeout = Duration(seconds: 6);

  @override
  Future<List<String>?> check({
    required String title,
    required String kind,
    required DateTime startsAt,
    required String recurrence,
    String? forPerson,
  }) async {
    final who = forPerson?.trim() ?? '';
    try {
      final response = await _client.functions
          .invoke(
            'zad-brain',
            body: <String, dynamic>{
              'action': 'booking_check',
              'title': title.trim(),
              'kind': kind,
              'starts_at': startsAt.toUtc().toIso8601String(),
              'recurrence': recurrence,
              if (who.isNotEmpty) 'for_person': who,
            },
          )
          .timeout(timeout);
      return bookingConflictLines(response.data);
    } on Object catch (e) {
      debugPrint('booking check skipped: $e');
      return null;
    }
  }
}

/// The `say` lines of a `booking_check` answer, or null when it is not one.
List<String>? bookingConflictLines(Object? data) {
  if (data is! Map || data['ok'] != true) return null;
  final conflicts = data['conflicts'];
  if (conflicts is! List) return null;
  return <String>[
    for (final c in conflicts)
      if (c is Map && c['say'] is String && (c['say'] as String).isNotEmpty)
        c['say'] as String,
  ];
}

/// The guard the add dialog asks.
final Provider<BookingGuard> bookingGuardProvider = Provider<BookingGuard>(
  (ref) => SupabaseBookingGuard(ref.watch(supabaseClientProvider)),
);
