/// Photographing a receipt, checking what was read, and saving it.
///
/// The bank channel fills the list on its own and the manual sheet covers the
/// cash purchase nobody was notified about. This is the third way in: the paper
/// in the customer's hand.
///
/// Every reading is shown before it is written. The model is good at receipts
/// and still wrong sometimes, and the two fields it gets wrong in ways that
/// matter — the total and the category — are the two this sheet lets the
/// customer correct in place.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `hide TextDirection`: intl exports one of its own, and the amount field
// needs dart:ui's — digits read left to right inside a right-to-left sheet.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:zad/core/money/money.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/data/receipt_scanner.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';

/// Opens the scanner.
Future<void> showReceiptScanSheet(BuildContext context, WidgetRef ref) {
  // A sheet left open from a previous scan would show that receipt again.
  ref.read(scanControllerProvider.notifier).reset();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ZadColors.surface,
    shape: zadSquircle(ZadRadii.sheet),
    builder: (_) => const ReceiptScanSheet(),
  );
}

/// The scanner.
class ReceiptScanSheet extends ConsumerWidget {
  /// Creates the sheet.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(scanControllerProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: switch (view.stage) {
          ScanStage.idle => const _Pick(),
          ScanStage.working => const _Working(),
          ScanStage.unreadable => const _Retry(
            title: 'مقدرتش أقرا الفاتورة',
            message:
                'جرب صورة أوضح — الورقة مفرودة، الإضاءة كويسة، والمبلغ '
                'الأخير ظاهر في الصورة.',
            tone: ZadEmptyTone.waiting,
          ),
          ScanStage.failed => const _Retry(
            title: 'مقدرتش أوصل للسيرفر',
            message: 'الصورة لسه معاك. جرب تاني لما النت يرجع.',
            tone: ZadEmptyTone.problem,
          ),
          ScanStage.ready => _Reading(receipt: view.receipt!),
        },
      ),
    );
  }
}

/// Which camera to open.
class _Pick extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(scanControllerProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('صوّر الفاتورة', style: ZadType.titleMedium),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          'هقرا المحل والمبلغ والأصناف، وأوريهملك تتأكد منهم قبل ما أسجّل '
          'أي حاجة.',
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.xl),
        FilledButton.icon(
          onPressed: () => controller.scan(ReceiptImageSource.camera),
          icon: const Icon(ZadIcons.scan),
          label: const Text('افتح الكاميرا'),
        ),
        const SizedBox(height: ZadSpacing.md),
        OutlinedButton.icon(
          onPressed: () => controller.scan(ReceiptImageSource.gallery),
          icon: const Icon(ZadIcons.inventory),
          label: const Text('اختار من الصور'),
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          // Said here because it is the non-obvious half: the same reader
          // handles a screenshot of a bank notification, and offers to make it
          // the budget rather than an expense.
          'تقدر كمان تختار صورة إشعار رصيد أو راتب، وهعرض عليك تخليه ميزانيتك.',
          style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
        ),
      ],
    );
  }
}

class _Working extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      const SizedBox(height: ZadSpacing.xl),
      const CircularProgressIndicator(),
      const SizedBox(height: ZadSpacing.lg),
      Text(
        'بقرا الفاتورة…',
        style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
      ),
      const SizedBox(height: ZadSpacing.xl),
    ],
  );
}

class _Retry extends ConsumerWidget {
  const new({required this.title, required this.message, required this.tone});

  final String title;
  final String message;
  final ZadEmptyTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = tone == ZadEmptyTone.problem
        ? ZadColors.terracottaRust
        : ZadColors.mustardOchre;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(ZadIcons.failed, color: accent, size: 20),
            const SizedBox(width: ZadSpacing.md),
            Expanded(child: Text(title, style: ZadType.titleSmall)),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        Text(
          message,
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.xl),
        FilledButton(
          onPressed: () => ref
              .read(scanControllerProvider.notifier)
              .scan(ReceiptImageSource.camera),
          child: const Text('صوّر تاني'),
        ),
      ],
    );
  }
}

/// What was read, and what to do with it.
class _Reading extends ConsumerStatefulWidget {
  const new({required this.receipt});

  final ScannedReceipt receipt;

  @override
  ConsumerState<_Reading> createState() => _ReadingState();
}

class _ReadingState extends ConsumerState<_Reading> {
  late final TextEditingController _total = TextEditingController(
    text: _plain(widget.receipt.total),
  );

  @override
  void dispose() {
    _total.dispose();
    super.dispose();
  }

  double? get _parsedTotal => parseMoneyInput(_total.text);

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    final view = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);
    final busy = view.isSaving;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          receipt.type.isPurchase ? 'اتأكد من الفاتورة' : 'دي مش فاتورة شراء',
          style: ZadType.titleMedium,
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          receipt.type.isPurchase
              ? 'راجع المبلغ والفئة قبل ما تحفظ. لسه ماتسجّلش حاجة.'
              // The distinction that stops a salary notice being recorded as
              // spending — which is what the Kotlin screen does today.
              : 'دي شكلها صورة رصيد أو راتب، مش حاجة اتصرفت. أقدر أخلي الرقم '
                    'ده ميزانيتك بدل ما أسجّله مصروف.',
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.lg),

        if (receipt.storeName.isNotEmpty) ...<Widget>[
          Text(receipt.storeName, style: ZadType.titleSmall),
          const SizedBox(height: ZadSpacing.md),
        ],

        TextField(
          controller: _total,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          style: ZadType.figure(26),
          decoration: InputDecoration(
            labelText: receipt.type.isPurchase ? 'المبلغ' : 'الرصيد',
          ),
          onChanged: (_) {
            setState(() {});
            final parsed = _parsedTotal;
            if (parsed != null) controller.correct(total: parsed);
          },
        ),

        if (receipt.type.isPurchase) ...<Widget>[
          const SizedBox(height: ZadSpacing.lg),
          Text(
            'الفئة',
            style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.sm),
          // The eleven, offered rather than typed. Every breakdown in the app
          // buckets by exact match, so a free-text field here would be a way
          // to create an orphan bucket by hand.
          Wrap(
            spacing: ZadSpacing.sm,
            runSpacing: ZadSpacing.sm,
            children: <Widget>[
              for (final category in kStandardCategories)
                ChoiceChip(
                  label: Text(category),
                  selected: category == receipt.category,
                  onSelected: busy
                      ? null
                      : (_) => controller.correct(category: category),
                ),
            ],
          ),

          if (receipt.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: ZadSpacing.lg),
            Text(
              // Named as what it is. The items are not stored anywhere yet —
              // the pantry has not been ported — and implying otherwise would
              // be the sort of half-claim this app keeps getting caught by.
              'الأصناف اللي قريتها (${receipt.items.length}) — للمراجعة بس، '
              'لسه مش بتتخزن',
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    for (final item in receipt.items) _ItemRow(item: item),
                  ],
                ),
              ),
            ),
          ],
        ],

        const SizedBox(height: ZadSpacing.xl),
        if (receipt.type.isPurchase)
          FilledButton(
            onPressed: busy || _parsedTotal == null
                ? null
                : () => _save(controller.saveAsTransaction),
            child: busy ? const _ButtonSpinner() : const Text('احفظ كمصروف'),
          )
        else
          FilledButton(
            onPressed: busy || _parsedTotal == null
                ? null
                : () => _save(controller.useAsMonthlyLimit),
            child: busy ? const _ButtonSpinner() : const Text('خليها ميزانيتي'),
          ),
        const SizedBox(height: ZadSpacing.sm),
        TextButton(
          onPressed: busy ? null : controller.reset,
          child: const Text('صوّر تاني'),
        ),
      ],
    );
  }

  Future<void> _save(Future<bool> Function() write) async {
    final saved = await write();
    if (!mounted) return;
    if (saved) {
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _ItemRow extends StatelessWidget {
  const new({required this.item});

  final ScannedReceiptItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        Text(
          _plain(item.price),
          style: ZadType.figure(13).copyWith(color: ZadColors.inkMuted),
        ),
      ],
    ),
  );
}

class _ButtonSpinner extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

/// A figure with no grouping separators, for an editable field.
String _plain(double value) {
  final rounded = value.asMoney;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : NumberFormat('0.##', 'en').format(rounded);
}
