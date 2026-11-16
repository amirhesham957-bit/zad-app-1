/// The form's «مسح العبوة بالكاميرا»: a photo of the box, the vision read, and
/// the form filled with what it read (Kotlin's camera button).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/ads/presentation/ai_wait_ad.dart';
import 'package:zad/shared/scan/data/receipt_scanner.dart';
import 'package:zad/shared/scan/data/vision_scanner.dart';

/// The scan row.
class PharmacyScanRow extends ConsumerStatefulWidget {
  /// Creates the row; [onRead] gets a reading to fill the form from.
  const new({required this.onRead, super.key});

  /// A box was read.
  final ValueChanged<ScannedMedicine> onRead;

  @override
  ConsumerState<PharmacyScanRow> createState() => _PharmacyScanRowState();
}

class _PharmacyScanRowState extends ConsumerState<PharmacyScanRow> {
  bool _scanning = false;

  Future<void> _scanBox() async {
    final userId = ref.read(signedInUserIdProvider)();
    if (userId == null || _scanning) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final image = await ref
        .read(receiptCameraProvider)
        .capture(ReceiptImageSource.camera);
    if (image == null || !mounted) return;
    setState(() => _scanning = true);
    const unclear = SnackBar(
      content: Text('تعذر قراءة العلبة بدقة، يرجى المحاولة بزاوية أوضح'),
    );
    try {
      final result = await ref
          .read(visionScannerProvider)
          .medicine(userId: userId, image: image);
      if (!mounted) return;
      if (result != null && result.name.trim().isNotEmpty) {
        widget.onRead(result);
        messenger?.showSnackBar(
          const SnackBar(content: Text('تم استخراج بيانات الدواء بنجاح')),
        );
      } else {
        messenger?.showSnackBar(unclear);
      }
    } on Object {
      messenger?.showSnackBar(unclear);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      OutlinedButton(
        onPressed: _scanning ? null : () => unawaited(_scanBox()),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_scanning) ...<Widget>[
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: ZadSpacing.sm),
              const Flexible(
                child: Text(
                  'جاري قراءة علبة الدواء بالذكاء الاصطناعي...',
                  style: ZadType.labelMedium,
                ),
              ),
            ] else ...<Widget>[
              const Icon(Icons.camera_alt, size: 18),
              const SizedBox(width: ZadSpacing.sm),
              Text(
                'مسح العبوة بالكاميرا',
                style: ZadType.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      // One ad with the box scan (owner 15/11), under the disabled scan
      // button while the AI reads.
      if (_scanning) ...<Widget>[
        const SizedBox(height: ZadSpacing.lg),
        const ZadAiWaitAd(),
      ],
      const SizedBox(height: ZadSpacing.md),
    ],
  );
}
