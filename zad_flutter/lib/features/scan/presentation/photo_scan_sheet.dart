/// Photographing a pantry shelf or a medicine box — Kotlin's two other camera
/// modes, beside the receipt.
///
/// A shelf's items are listed with a tick each and go into the pantry on one
/// tap. A box's reading is not saved here at all: the sheet hands it back and
/// the pharmacy opens its add form filled in, so the customer checks the name,
/// the count and the times in the same form they would have typed them into.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/scan/application/photo_scan_controller.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/data/receipt_scanner.dart';
import 'package:zad/features/scan/data/vision_scanner.dart';

/// Opens the pantry photo.
Future<void> showPantryPhotoSheet(BuildContext context) =>
    _open<void>(context, PhotoKind.pantry);

/// Opens the medicine photo, and returns the reading once there is one — null
/// when the customer closed the sheet first.
Future<ScannedMedicine?> showMedicinePhotoSheet(BuildContext context) =>
    _open<ScannedMedicine>(context, PhotoKind.medicine);

Future<T?> _open<T>(BuildContext context, PhotoKind kind) {
  // A sheet left from a previous photo would show that reading again.
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(photoScanControllerProvider.notifier).reset();

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ZadColors.surface,
    shape: zadSquircle(ZadRadii.sheet),
    builder: (_) => PhotoScanSheet(kind: kind),
  );
}

/// The sheet.
class PhotoScanSheet extends ConsumerWidget {
  /// Creates the sheet for [kind].
  const new({required this.kind, super.key});

  /// What is being photographed.
  final PhotoKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(photoScanControllerProvider);
    ref.listen(photoScanControllerProvider.select((v) => v.medicine), (
      _,
      medicine,
    ) {
      if (kind == PhotoKind.medicine && medicine != null) {
        Navigator.of(context).pop(medicine);
      }
    });

    final isPantry = kind == PhotoKind.pantry;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: switch (view.stage) {
          ScanStage.idle => _Pick(kind: kind),
          ScanStage.working => const _Working(),
          // A medicine reading leaves the sheet the moment it lands.
          ScanStage.ready when !isPantry => const _Working(),
          ScanStage.unreadable => _Retry(
            kind: kind,
            title: isPantry ? 'مالقيتش أصناف في الصورة' : 'مقدرتش أقرا العلبة',
            message: isPantry
                ? 'قرّب أكتر وخلّي الأصناف والكلام اللي عليها باين، والإضاءة '
                      'كويسة.'
                : 'صوّر وش العلبة اللي عليه اسم الدواء، قريب ومن غير لمعة.',
            tone: ZadEmptyTone.waiting,
          ),
          ScanStage.failed => _Retry(
            kind: kind,
            title: 'مقدرتش أوصل للسيرفر',
            message: 'جرب تاني لما النت يرجع.',
            tone: ZadEmptyTone.problem,
          ),
          ScanStage.ready => _PantryReading(view: view),
        },
      ),
    );
  }
}

class _Pick extends ConsumerWidget {
  const new({required this.kind});

  final PhotoKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(photoScanControllerProvider.notifier);
    final isPantry = kind == PhotoKind.pantry;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          isPantry ? 'صوّر المخزن' : 'صوّر علبة الدواء',
          style: ZadType.titleMedium,
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          isPantry
              ? 'الرف أو التلاجة أو شنطة المشتريات — هقرا الأصناف وكمياتها، '
                    'وأوريهالك تختار منها قبل ما تدخل المخزن.'
              : 'هقرا الاسم والعدد والجرعة والانتهاء، وأفتحلك فورم الإضافة '
                    'متعبّي تراجعه قبل الحفظ.',
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.xl),
        FilledButton.icon(
          onPressed: () => controller.scan(kind, ReceiptImageSource.camera),
          icon: const Icon(ZadIcons.scan),
          label: const Text('افتح الكاميرا'),
        ),
        const SizedBox(height: ZadSpacing.md),
        OutlinedButton.icon(
          onPressed: () => controller.scan(kind, ReceiptImageSource.gallery),
          icon: const Icon(ZadIcons.inventory),
          label: const Text('اختار من الصور'),
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
        'بقرا الصورة…',
        style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
      ),
      const SizedBox(height: ZadSpacing.xl),
    ],
  );
}

class _Retry extends ConsumerWidget {
  const new({
    required this.kind,
    required this.title,
    required this.message,
    required this.tone,
  });

  final PhotoKind kind;
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
              .read(photoScanControllerProvider.notifier)
              .scan(kind, ReceiptImageSource.camera),
          child: const Text('صوّر تاني'),
        ),
        const SizedBox(height: ZadSpacing.sm),
        TextButton(
          onPressed: ref.read(photoScanControllerProvider.notifier).reset,
          child: const Text('اختار صورة تانية'),
        ),
      ],
    );
  }
}

/// The items a pantry photo showed, each with a tick.
class _PantryReading extends ConsumerWidget {
  const new({required this.view});

  final PhotoScanView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(photoScanControllerProvider.notifier);
    final busy = view.isSaving;
    final count = view.ticked.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('لقيت ${view.items.length} صنف', style: ZadType.titleMedium),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          'شيل علامة أي حاجة غلط. اللي موجود هتزيد كميته، واللي في قايمة '
          'المشتريات هيتشال منها.',
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                for (final (i, item) in view.items.indexed)
                  CheckboxListTile(
                    value: !view.excluded.contains(i),
                    onChanged: busy ? null : (_) => controller.toggleItem(i),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    title: Text(item.name, style: ZadType.bodyMedium),
                    subtitle: Text(
                      <String>[
                        '${item.quantity} ${item.unit}',
                        if (item.category case final c? when c.isNotEmpty) c,
                      ].join('  •  '),
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZadSpacing.xl),
        FilledButton(
          onPressed: busy || count == 0
              ? null
              : () => _save(context, controller.savePantry),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('ضيف للمخزن ($count)'),
        ),
        const SizedBox(height: ZadSpacing.sm),
        TextButton(
          onPressed: busy ? null : controller.reset,
          child: const Text('صوّر تاني'),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, Future<bool> Function() save) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final saved = await save();
    // Said on the screen underneath, which outlives this sheet.
    final said = pantryPhotoMessage(
      container.read(photoScanControllerProvider).lastIntake,
    );
    if (said != null) messenger?.showSnackBar(SnackBar(content: Text(said)));
    if (saved) await HapticFeedback.mediumImpact();
    if (navigator.mounted) navigator.pop();
  }
}

/// What a pantry photo did, in one line.
String? pantryPhotoMessage(PantryIntakeResult? intake) {
  if (intake == null) return null;
  if (intake.failed) {
    return 'الأصناف مادخلتش المخزن كلها — راجع المخزن وضيف الناقص بإيدك.';
  }
  final parts = <String>[
    if (intake.added > 0) '${intake.added} جديد',
    if (intake.toppedUp > 0) '${intake.toppedUp} زادت كميته',
    if (intake.ticked > 0) '${intake.ticked} اتشال من المشتريات',
  ];
  if (parts.isEmpty) return null;
  return 'المخزن: ${parts.join('، ')}.';
}
