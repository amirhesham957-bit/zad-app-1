/// Getting a photograph of a receipt, and getting it read.
///
/// Both halves sit behind interfaces so the controller can be tested without a
/// camera and without a network — neither exists in a widget test, and a scan
/// path that can only be exercised by hand on a phone is a scan path nobody
/// checks after the first time.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';

/// Where the photograph comes from.
enum ReceiptImageSource {
  /// The phone's camera app.
  camera,

  /// An image already on the device — a receipt the customer was emailed, or a
  /// screenshot of a bank notification.
  gallery,
}

/// Produces one still image.
abstract interface class ReceiptCamera {
  /// Returns the JPEG bytes, or null when the customer backed out.
  Future<Uint8List?> capture(ReceiptImageSource source);
}

/// The real camera, over `image_picker`.
class ImagePickerCamera implements ReceiptCamera {
  /// Creates a camera.
  new([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// The longest edge, in pixels, and the JPEG quality.
  ///
  /// 1024 and 70 are the Kotlin client's numbers, not a guess:
  /// `ZadAiRepository.encodeBitmap` settled on them because 800px did not give
  /// the vision model enough resolution to read receipt and medicine-bottle
  /// text reliably, while q70 keeps the request well under the size limit. The
  /// two clients must send comparable images or they will not read the same
  /// receipt the same way.
  static const double maxEdge = 1024;

  /// JPEG quality, 0–100.
  static const int quality = 70;

  @override
  Future<Uint8List?> capture(ReceiptImageSource source) async {
    final file = await _picker.pickImage(
      source: source == ReceiptImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: maxEdge,
      maxHeight: maxEdge,
      imageQuality: quality,
    );
    if (file == null) return null;
    return await file.readAsBytes();
  }
}

/// Reads a receipt image.
abstract interface class ReceiptScanner {
  /// Calls `zad-core-intelligence`'s `analyze_receipt` action.
  ///
  /// Throws on transport failure. The caller distinguishes that from a
  /// successful call that read nothing, because they need different words: one
  /// is "we could not reach the server", the other is "hold the camera
  /// steadier".
  Future<ScannedReceipt> scan({
    required String userId,
    required Uint8List image,
  });
}

/// The real scanner.
class SupabaseReceiptScanner implements ReceiptScanner {
  /// Creates a scanner over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  /// The function that owns every vision action.
  ///
  /// Not `zad-ai-proxy`, which is dead code no client calls, and not
  /// `zad-brain`, which is the agent loop. Vision runs the Gemini key pool and
  /// never falls through to Groq — Groq rejects JSON mode on any request
  /// carrying an image, and this action needs structured JSON.
  static const String function = 'zad-core-intelligence';

  @override
  Future<ScannedReceipt> scan({
    required String userId,
    required Uint8List image,
  }) async {
    final response = await _client.functions.invoke(
      function,
      body: <String, dynamic>{
        'action': 'analyze_receipt',
        'user_id': userId,
        'payload': <String, dynamic>{
          'image_base64': base64Encode(image),
          'mime_type': 'image/jpeg',
        },
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw StateError(
        'analyze_receipt answered ${data.runtimeType}, not an object',
      );
    }
    return ScannedReceipt.fromJson(Map<String, dynamic>.from(data));
  }
}
