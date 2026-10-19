/// Opens what was shared to Zad (share_intake.dart) over the shell: whatever
/// was pushed is closed first, so back from the share returns to the shell.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/share/share_intake.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/features/scan/presentation/receipt_scan_sheet.dart';
import 'package:zad/features/statement/presentation/statement_import_screen.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';

/// The longest text that goes into the composer.
const int _maxDraft = 2000;

/// Opens [item].
Future<void> openShared(
  BuildContext context,
  WidgetRef ref,
  SharedItem item,
) async {
  final navigator = Navigator.of(context)..popUntil((route) => route.isFirst);
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));

  switch (routeFor(item)) {
    case ShareRoute.chat:
      final text = item.text!.trim();
      ref
          .read(chatPrefillProvider.notifier)
          .offer(text.substring(0, math.min(text.length, _maxDraft)));
      await navigator.push<void>(
        MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
      );
    case ShareRoute.statement:
      final bytes = await _bytes(item);
      if (bytes == null) {
        say(_unreadable);
        return;
      }
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => StatementImportScreen(
            initialFile: (name: shareFileName(item), bytes: bytes),
          ),
        ),
      );
    case ShareRoute.askImage:
      final bytes = await _bytes(item);
      if (bytes == null) {
        say(_unreadable);
        return;
      }
      if (!context.mounted) return;
      final use = await _askImageUse(context);
      if (use == null || !context.mounted) return;
      switch (use) {
        case _ImageUse.receipt:
          final Uint8List small;
          try {
            small = await shrinkForReceipt(bytes);
          } on Object {
            say(_unreadable);
            return;
          }
          if (!context.mounted) return;
          await showReceiptScanSheet(
            context,
            ref,
            image: small,
            mimeType: 'image/png',
          );
        case _ImageUse.statement:
          await navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => StatementImportScreen(
                initialFile: (name: shareFileName(item), bytes: bytes),
              ),
            ),
          );
      }
    case ShareRoute.tooLarge:
      say('الملف أكبر من إن زاد يقراه مرة واحدة — ابعته أصغر');
    case ShareRoute.failed:
      say(_unreadable);
    case ShareRoute.unsupported:
      say('زاد بيقرا الكلام والصور وملفات PDF وCSV بس');
  }
}

const String _unreadable = 'مقدرتش أفتح اللي اتشارك — جرّب تبعته تاني';

Future<Uint8List?> _bytes(SharedItem item) async {
  try {
    return await File(item.path!).readAsBytes();
  } on Object {
    return null;
  }
}

enum _ImageUse { receipt, statement }

Future<_ImageUse?> _askImageUse(BuildContext context) =>
    showModalBottomSheet<_ImageUse>(
      context: context,
      backgroundColor: ZadColors.surface,
      shape: zadSquircle(ZadRadii.sheet),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.lg,
            ZadSpacing.lg,
            ZadSpacing.lg,
            ZadSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('الصورة دي إيه؟', style: ZadType.titleMedium),
              const SizedBox(height: ZadSpacing.sm),
              Text(
                'زاد هيقراها ويوريك اللي لقاه قبل ما يسجل أي حاجة',
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.md),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('فاتورة شرا'),
                onTap: () => Navigator.of(context).pop(_ImageUse.receipt),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_outlined),
                title: const Text('كشف حساب'),
                onTap: () => Navigator.of(context).pop(_ImageUse.statement),
              ),
            ],
          ),
        ),
      ),
    );

/// [bytes] as a PNG no larger than the 1024px the camera path sends the
/// receipt reader (ImagePickerCamera.maxEdge): a full-size screenshot or
/// photo is several times the upload for no better reading.
Future<Uint8List> shrinkForReceipt(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  try {
    final scale = math.min(
      1,
      1024 / math.max(descriptor.width, descriptor.height),
    );
    final codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * scale).round()),
      targetHeight: math.max(1, (descriptor.height * scale).round()),
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    if (data == null) throw StateError('the picture could not be encoded');
    return data.buffer.asUint8List();
  } finally {
    descriptor.dispose();
    buffer.dispose();
  }
}
