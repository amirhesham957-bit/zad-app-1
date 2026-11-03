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
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/scan/application/photo_scan_controller.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/shared/ads/presentation/watch_ad_button.dart';
import 'package:zad/shared/inventory/application/pantry_intake.dart';
import 'package:zad/shared/quota/domain/server_refusal.dart';
import 'package:zad/shared/scan/data/receipt_scanner.dart';
import 'package:zad/shared/scan/data/vision_scanner.dart';

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
    useSafeArea: true,
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
    // The balance or the pace, said as the server said it (meter.ts).
    final refusal = serverRefusal(view.error, context.l10n);
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
            title: isPantry
                ? context.l10n.scanNoPantryItems
                : context.l10n.scanBoxUnreadable,
            message: isPantry
                ? context.l10n.scanPantryPhotoHint
                : context.l10n.scanBoxPhotoHint,
            tone: ZadEmptyTone.waiting,
          ),
          ScanStage.failed => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Retry(
                kind: kind,
                title: refusal?.title ?? context.l10n.scanServerUnreachable,
                message: refusal?.message ?? context.l10n.scanTryWhenOnline,
                tone: refusal != null
                    ? ZadEmptyTone.waiting
                    : ZadEmptyTone.problem,
              ),
              // The balance ran out: an ad can bring an attempt (٨ب.٢).
              if (refusal?.outOfAttempts ?? false) ...<Widget>[
                const SizedBox(height: ZadSpacing.md),
                const WatchAdButton(),
              ],
            ],
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
          isPantry ? context.l10n.scanPantryTitle : context.l10n.scanBoxTitle,
          style: ZadType.titleMedium,
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          isPantry ? context.l10n.scanPantryIntro : context.l10n.scanBoxIntro,
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.xl),
        FilledButton.icon(
          onPressed: () => controller.scan(kind, ReceiptImageSource.camera),
          icon: const Icon(ZadIcons.scan),
          label: Text(context.l10n.scanOpenCamera),
        ),
        const SizedBox(height: ZadSpacing.md),
        OutlinedButton.icon(
          onPressed: () => controller.scan(kind, ReceiptImageSource.gallery),
          icon: const Icon(ZadIcons.inventory),
          label: Text(context.l10n.scanPickFromGallery),
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
        context.l10n.scanReadingPhoto,
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
          child: Text(context.l10n.scanRetake),
        ),
        const SizedBox(height: ZadSpacing.sm),
        TextButton(
          onPressed: ref.read(photoScanControllerProvider.notifier).reset,
          child: Text(context.l10n.scanPickAnother),
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
        Text(
          context.l10n.scanFoundItems(view.items.length),
          style: ZadType.titleMedium,
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          context.l10n.scanFoundItemsHint,
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
              : Text(context.l10n.scanAddToPantryCount(count)),
        ),
        const SizedBox(height: ZadSpacing.sm),
        TextButton(
          onPressed: busy ? null : controller.reset,
          child: Text(context.l10n.scanRetake),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, Future<bool> Function() save) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final l10n = context.l10n;
    final saved = await save();
    // Said on the screen underneath, which outlives this sheet.
    final said = pantryPhotoMessage(
      container.read(photoScanControllerProvider).lastIntake,
      l10n,
    );
    if (said != null) messenger?.showSnackBar(SnackBar(content: Text(said)));
    if (saved) await HapticFeedback.mediumImpact();
    if (navigator.mounted) navigator.pop();
  }
}

/// What a pantry photo did, in one line — in [l10n]'s language, Arabic by
/// default.
String? pantryPhotoMessage(PantryIntakeResult? intake, [ZadL10n? l10n]) {
  if (intake == null) return null;
  final t = l10n ?? zadL10nArabic;
  if (intake.failed) return t.scanPantryPartial;
  final parts = <String>[
    if (intake.added > 0) t.scanPartNew(intake.added),
    if (intake.toppedUp > 0) t.scanPartToppedUp(intake.toppedUp),
    if (intake.ticked > 0) t.scanPartTicked(intake.ticked),
  ];
  if (parts.isEmpty) return null;
  return t.scanPantryResult(parts.reduce(t.scanPartsJoin));
}
