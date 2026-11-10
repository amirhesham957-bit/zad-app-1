/// Amazon links open in the Amazon Shopping app (owner, 2026-11-10), the way
/// the Telegram button does: an Android intent aimed at the app's package
/// (`MainActivity`, channel `zad/amazon_app`). The link keeps the store's
/// tag (`zad04-21` on amazon.eg, `zad0b-21` on amazon.sa).
///
/// This replaced «a browser tab, never the Amazon app», which feared the app
/// would drop the commission; the owner chose the app on 2026-11-10.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('zad/amazon_app');

final RegExp _amazonStore = RegExp(
  r'^https://(www\.)?amazon\.(eg|sa|ae|com\.tr|com)(/|$)',
);

/// True when the Amazon app took [url]. False on iPhone and anywhere else
/// (the caller then opens its browser tab), when the app is not installed,
/// or when [url] is not an Amazon store link.
Future<bool> openInAmazonApp(String url) async {
  if (!_amazonStore.hasMatch(url)) return false;
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await _channel.invokeMethod<bool>('open', <String, String>{
          'url': url,
        }) ??
        false;
  } on Object catch (e) {
    debugPrint('amazon app not opened: $e');
    return false;
  }
}
