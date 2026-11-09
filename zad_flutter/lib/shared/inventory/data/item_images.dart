/// Photos of household items, by name, shared by every screen that lists them.
///
/// Rows ask for their photo while they are built; the names asked for in one
/// frame travel together, ten to a request, and each is asked once a session.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';

/// How many names one request carries (the server's own limit).
const int kItemImagesPerRequest = 10;

/// The known photos: a name maps to its URL, or to null when it has none.
class ItemImages extends Notifier<Map<String, String?>> {
  final Set<String> _queued = <String>{};
  final Set<String> _sent = <String>{};
  bool _scheduled = false;

  @override
  Map<String, String?> build() => const <String, String?>{};

  /// Asks for [name]'s photo, once.
  void want(String name) {
    if (state.containsKey(name) || _sent.contains(name)) return;
    if (!_queued.add(name) || _scheduled) return;
    _scheduled = true;
    scheduleMicrotask(_send);
  }

  Future<void> _send() async {
    _scheduled = false;
    final names = _queued.toList();
    _queued.clear();
    _sent.addAll(names);
    for (var i = 0; i < names.length; i += kItemImagesPerRequest) {
      final end = math.min(i + kItemImagesPerRequest, names.length);
      final chunk = names.sublist(i, end);
      final found = await _fetch(chunk);
      if (!ref.mounted) return;
      state = <String, String?>{
        ...state,
        for (final name in chunk) name: found[name],
      };
    }
  }

  Future<Map<String, String>> _fetch(List<String> names) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final response = await client.functions.invoke(
        'zad-core-intelligence',
        body: <String, dynamic>{
          'action': 'item_images',
          'user_id': client.auth.currentUser?.id,
          'payload': <String, dynamic>{'names': names},
        },
      );
      final data = response.data;
      final images = data is Map ? data['images'] : null;
      if (images is! Map) return const <String, String>{};
      return <String, String>{
        for (final e in images.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    } on Object {
      return const <String, String>{};
    }
  }
}

/// The photos known so far.
final itemImagesProvider = NotifierProvider<ItemImages, Map<String, String?>>(
  ItemImages.new,
);
