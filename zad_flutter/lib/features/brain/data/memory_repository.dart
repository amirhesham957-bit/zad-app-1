/// What زاد knows about the customer: cached to open instantly, changed only
/// online.
///
/// Three writes live here — forget a note, correct the profile, wipe the
/// outings — and none of them goes through the outbox. Each is a promise about
/// what the brain will read on the very next turn: "forgotten" told while the
/// note is still on the server would be false for as long as the phone stayed
/// offline, and the brain would keep using it. The profile has a second
/// reason: the brain writes it too (`update_customer_profile`), so a form
/// queued now and sent an hour later could overwrite what it learned in
/// between. So each happens now or says why not, and each is read back.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/features/brain/data/memory_remote.dart';
import 'package:zad/features/brain/domain/customer_profile.dart';
import 'package:zad/features/brain/domain/habits.dart';
import 'package:zad/features/brain/domain/memory_note.dart';

/// Everything the screen shows.
@immutable
class MemorySnapshot {
  /// Creates a snapshot.
  const new({
    this.notes = const <MemoryNote>[],
    this.profile,
    this.behavior,
    this.visits = const <PlaceVisit>[],
  });

  /// The notes, most certain first.
  final List<MemoryNote> notes;

  /// The profile; null when the brain has not started one.
  final CustomerProfile? profile;

  /// The weekly spending row as the server gave it; null when none.
  final Map<String, dynamic>? behavior;

  /// Outings in the last [MemoryRepository.visitWindow].
  final List<PlaceVisit> visits;

  /// The habits card's figures.
  HabitsSummary get habits => HabitsSummary.from(behavior, visits);

  /// A copy with the given parts replaced.
  MemorySnapshot copyWith({
    List<MemoryNote>? notes,
    CustomerProfile? profile,
    List<PlaceVisit>? visits,
  }) => MemorySnapshot(
    notes: notes ?? this.notes,
    profile: profile ?? this.profile,
    behavior: behavior,
    visits: visits ?? this.visits,
  );
}

/// Why a write did not happen.
enum MemoryWriteFailure {
  /// No answer from the server.
  offline('مفيش اتصال دلوقتي — جرب لما النت يرجع'),

  /// The server answered and the change is not there.
  notSaved('مقدرتش أحفظ ده، جرب تاني');

  new(this.message);

  /// What the customer reads.
  final String message;
}

/// Holds it.
class MemoryRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required MemoryRemote remote,
    required String? Function() signedInUserId,
    required DateTime Function() now,
  }) : _cache = cache,
       _remote = remote,
       _signedInUserId = signedInUserId,
       _now = now;

  final Box<String> _cache;
  final MemoryRemote _remote;
  final String? Function() _signedInUserId;
  final DateTime Function() _now;

  /// How far back outings are read — Kotlin's window, and the one the card
  /// names ("آخر ٣٠ يوم").
  static const Duration visitWindow = Duration(days: 30);

  /// How many notes a refresh reads. The busiest account had 8 on 2026-09-21.
  static const int noteLimit = 200;

  static const String _key = 'brain_memory';

  /// The last snapshot, or an empty one. Synchronous; call it from `build`.
  MemorySnapshot cached() {
    final raw = _cache.get(_key);
    if (raw == null) return const MemorySnapshot();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return MemorySnapshot(
        notes: <MemoryNote>[
          for (final n in json['notes'] as List<dynamic>)
            MemoryNote.fromJson(Map<String, dynamic>.from(n as Map)),
        ],
        profile: switch (json['profile']) {
          final Map<dynamic, dynamic> p => CustomerProfile.fromJson(
            Map<String, dynamic>.from(p),
          ),
          _ => null,
        },
        behavior: switch (json['behavior']) {
          final Map<dynamic, dynamic> b => Map<String, dynamic>.from(b),
          _ => null,
        },
        visits: <PlaceVisit>[
          for (final v in json['visits'] as List<dynamic>)
            PlaceVisit.fromJson(Map<String, dynamic>.from(v as Map)),
        ],
      );
    } on Object {
      return const MemorySnapshot();
    }
  }

  /// Reads all four and caches them. Any one failing fails the refresh, so the
  /// screen keeps the last whole picture instead of half a new one.
  Future<MemorySnapshot> refresh() async {
    final userId = _requireUserId();
    final results = await Future.wait<Object?>(<Future<Object?>>[
      _remote.fetchNotes(userId: userId, limit: noteLimit),
      _remote.fetchProfile(userId),
      _remote.fetchBehavior(userId),
      _remote.fetchVisits(userId: userId, since: _now().subtract(visitWindow)),
    ]);
    final snapshot = MemorySnapshot(
      notes: <MemoryNote>[
        for (final row in results[0]! as List<Map<String, dynamic>>)
          MemoryNote.fromJson(row),
      ],
      profile: switch (results[1]) {
        final Map<String, dynamic> p => CustomerProfile.fromJson(p),
        _ => null,
      },
      behavior: results[2] as Map<String, dynamic>?,
      visits: <PlaceVisit>[
        for (final row in results[3]! as List<Map<String, dynamic>>)
          PlaceVisit.fromJson(row),
      ],
    );
    await _store(snapshot);
    return snapshot;
  }

  /// Makes زاد forget [note]. Null when it is gone from the server.
  Future<MemoryWriteFailure?> forget(MemoryNote note) => _write(() async {
    await _remote.deleteNote(note.id);
    if (await _remote.noteExists(note.id)) return MemoryWriteFailure.notSaved;
    final current = cached();
    await _store(
      current.copyWith(
        notes: <MemoryNote>[
          for (final n in current.notes)
            if (n.id != note.id) n,
        ],
      ),
    );
    return null;
  });

  /// Saves the profile form. Null when the server's row reads back as sent.
  Future<MemoryWriteFailure?> saveProfile(CustomerProfile profile) =>
      _write(() async {
        final userId = _requireUserId();
        final sent = profile.normalized();
        await _remote.upsertProfile(userId, sent.toFormJson());
        final row = await _remote.fetchProfile(userId);
        final stored = row == null ? null : CustomerProfile.fromJson(row);
        if (stored != sent) return MemoryWriteFailure.notSaved;
        await _store(cached().copyWith(profile: stored));
        return null;
      });

  /// Deletes every recorded outing. Null when none is left.
  Future<MemoryWriteFailure?> clearOutings() => _write(() async {
    final userId = _requireUserId();
    await _remote.deleteVisits(userId);
    if (await _remote.anyVisits(userId)) return MemoryWriteFailure.notSaved;
    await _store(cached().copyWith(visits: const <PlaceVisit>[]));
    return null;
  });

  Future<MemoryWriteFailure?> _write(
    Future<MemoryWriteFailure?> Function() body,
  ) async {
    try {
      return await body();
    } on Object catch (error) {
      if (error is SocketException ||
          error is TimeoutException ||
          error is HandshakeException ||
          error.toString().contains('ClientException')) {
        return MemoryWriteFailure.offline;
      }
      return MemoryWriteFailure.notSaved;
    }
  }

  Future<void> _store(MemorySnapshot s) => _cache.put(
    _key,
    jsonEncode(<String, dynamic>{
      'notes': <Map<String, dynamic>>[for (final n in s.notes) n.toJson()],
      'profile': s.profile?.toJson(),
      'behavior': s.behavior,
      'visits': <Map<String, dynamic>>[for (final v in s.visits) v.toJson()],
    }),
  );

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to read memory for');
    }
    return id;
  }
}
