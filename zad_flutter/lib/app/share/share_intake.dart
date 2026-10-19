/// «شارك لزاد» (ZAD_PLAN ٣.٣): what another app shared to Zad, from
/// MainActivity's `zad/share` channel, and where it goes.
///
/// Android copies a shared file into the app's cache before Dart sees it, so
/// the content URI's short-lived read grant never has to outlive the share.
/// Nothing shared is recorded on its own: text becomes a draft in the chat,
/// a statement goes to the import's review, a receipt to the scan's.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/features/statement/domain/statement_import.dart';

/// One share. Exactly one of [text] and [path] is set, unless the share
/// could not be taken ([tooLarge], [failed]).
@immutable
class SharedItem {
  /// Creates an item.
  const new({
    this.text,
    this.path,
    this.name,
    this.mimeType,
    this.tooLarge = false,
    this.failed = false,
  });

  /// Reads the channel's map; null for anything else.
  static SharedItem? fromMap(Object? raw) {
    if (raw is! Map) return null;
    String? str(String key) {
      final v = raw[key];
      return v is String && v.trim().isNotEmpty ? v : null;
    }

    return SharedItem(
      text: str('text'),
      path: str('path'),
      name: str('name'),
      mimeType: str('mime'),
      tooLarge: raw['tooLarge'] == true,
      failed: raw['failed'] == true,
    );
  }

  /// Shared words — a bank message copied out, an order confirmation.
  final String? text;

  /// The copy of a shared file in the app's cache.
  final String? path;

  /// The file's own name, as the sharing app gave it.
  final String? name;

  /// The type the sharing app declared.
  final String? mimeType;

  /// Larger than the phone should upload.
  final bool tooLarge;

  /// The file could not be copied.
  final bool failed;
}

/// Where a share goes.
enum ShareRoute {
  /// A draft in the chat composer.
  chat,

  /// The statement import, with the file.
  statement,

  /// A picture: a receipt or a statement — the customer says which.
  askImage,

  /// Not something Zad reads.
  unsupported,

  /// Too large.
  tooLarge,

  /// Could not be read off the phone.
  failed,
}

/// The route for [item].
ShareRoute routeFor(SharedItem item) {
  if (item.tooLarge) return ShareRoute.tooLarge;
  if (item.failed) return ShareRoute.failed;
  if (item.path == null) {
    return item.text == null ? ShareRoute.unsupported : ShareRoute.chat;
  }
  final mime = item.mimeType ?? '';
  final kind =
      statementFileKind(item.name ?? '') ??
      switch (mime) {
        'application/pdf' => StatementFileKind.pdf,
        'text/csv' ||
        'text/comma-separated-values' ||
        'application/csv' => StatementFileKind.csv,
        _ when mime.startsWith('image/') => StatementFileKind.image,
        _ => null,
      };
  return switch (kind) {
    StatementFileKind.pdf || StatementFileKind.csv => ShareRoute.statement,
    StatementFileKind.image => ShareRoute.askImage,
    null => ShareRoute.unsupported,
  };
}

/// The file's name with an extension the importer recognises: some apps
/// share `document` with only the mime type to say it is a PDF.
String shareFileName(SharedItem item) {
  final name = item.name ?? 'shared';
  if (statementFileKind(name) != null) return name;
  final mime = item.mimeType ?? '';
  return switch (mime) {
    'application/pdf' => '$name.pdf',
    'image/png' => '$name.png',
    'image/webp' => '$name.webp',
    'text/csv' ||
    'text/comma-separated-values' ||
    'application/csv' => '$name.csv',
    _ when mime.startsWith('image/') => '$name.jpg',
    _ => name,
  };
}

/// MainActivity's share channel.
class ShareIntake {
  /// Creates the intake over [channel].
  new([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('zad/share');

  final MethodChannel _channel;

  /// Calls [onShare] with every share: the one that opened the app, and each
  /// one after while it runs.
  Future<void> listen(void Function(SharedItem item) onShare) async {
    Future<void> take() async {
      final Object? raw;
      try {
        raw = await _channel.invokeMethod<Object?>('take');
      } on Object {
        // No channel (tests, another platform): nothing was shared.
        return;
      }
      final item = SharedItem.fromMap(raw);
      if (item != null) onShare(item);
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') await take();
    });
    await take();
  }

  /// Stops listening.
  void close() => _channel.setMethodCallHandler(null);
}

/// The app's share intake.
final shareIntakeProvider = Provider<ShareIntake>((ref) => ShareIntake());
