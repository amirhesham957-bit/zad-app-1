/// When the server turned a photo or a voice call down on purpose — the
/// attempts balance does not cover it (402), or the calls came too fast
/// (429) — in the server's own words (`zad-core-intelligence/meter.ts`).
///
/// The point is the right message: without this, a customer whose balance ran
/// out was told «مقدرتش أوصل للسيرفر» and went to check their connection.
library;

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The server's refusal: a title for the screen and its own message.
typedef ServerRefusal = ({String title, String message});

/// The refusal behind [error], or null for any other failure (offline, a
/// server error), which the screen words itself.
ServerRefusal? serverRefusal(Object? error) {
  if (error is! FunctionException) return null;
  if (error.status != 402 && error.status != 429) return null;
  final details = switch (error.details) {
    final Map<dynamic, dynamic> map => map,
    final String text => _decode(text),
    _ => null,
  };
  final message = details?['message'];
  if (message is! String || message.isEmpty) return null;
  return (
    title: error.status == 402 ? 'رصيد المحاولات مايكفيش' : 'استنى شوية',
    message: message,
  );
}

Map<dynamic, dynamic>? _decode(String text) {
  try {
    final decoded = jsonDecode(text);
    return decoded is Map ? decoded : null;
  } on FormatException {
    return null;
  }
}
