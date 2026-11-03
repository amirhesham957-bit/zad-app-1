/// Photographing a prescription or a school timetable
/// (docs/agent/ZAD_LIVING_BRAIN.md slice 21).
///
/// The reading is a review, never a write: a prescription's lines each carry
/// a tick (an unreadable one starts unticked) and say what will be scheduled,
/// under a reminder that Zad copies the paper and the pharmacist confirms it.
/// A timetable shows each school day's subjects and asks whose it is.
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
import 'package:zad/features/scan/application/document_scan_controller.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/shared/ads/presentation/watch_ad_button.dart';
import 'package:zad/shared/quota/domain/server_refusal.dart';
import 'package:zad/shared/scan/data/receipt_scanner.dart';
import 'package:zad/shared/scan/domain/scanned_document.dart';

/// Opens the document photo for [kind].
Future<void> showDocumentScanSheet(BuildContext context, DocumentKind kind) {
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(documentScanControllerProvider.notifier).reset();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ZadColors.surface,
    shape: zadSquircle(ZadRadii.sheet),
    builder: (_) => DocumentScanSheet(kind: kind),
  );
}

/// What a schedule line says, in words — in [l10n]'s language, Arabic by
/// default.
String scheduleText(PrescriptionLine m, [ZadL10n? l10n]) {
  final l = l10n ?? zadL10nArabic;
  if (!m.legible) return l.scanLineIllegible;
  if (m.asNeeded) return l.scanLineAsNeeded;
  final parts = <String>[
    if (m.timesPerDay case final n?) l.scanLineTimesPerDay(n),
    if (m.suggestedTimes case final t?) t.replaceAll(',', l.scanTimesSeparator),
    if (m.durationDays case final d?) l.scanLineForDays(d),
  ];
  return parts.isEmpty ? l.scanLineNoTimes : parts.join(' · ');
}

/// The sheet.
class DocumentScanSheet extends ConsumerWidget {
  /// Creates the sheet for [kind].
  const new({required this.kind, super.key});

  /// What is being photographed.
  final DocumentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(documentScanControllerProvider);
    final isPrescription = kind == DocumentKind.prescription;
    // The balance or the pace, said as the server said it (meter.ts).
    final refusal = serverRefusal(view.error, context.l10n);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: switch (view.stage) {
          ScanStage.idle => _Pick(kind: kind),
          ScanStage.working => const _Working(),
          ScanStage.unreadable => _Retry(
            kind: kind,
            title: isPrescription
                ? context.l10n.scanPrescriptionUnreadable
                : context.l10n.scanTimetableUnreadable,
            message: context.l10n.scanPaperHint,
            tone: ZadEmptyTone.waiting,
          ),
          ScanStage.failed => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Retry(
                kind: kind,
                title: refusal?.title ?? context.l10n.scanCouldNotFinish,
                message:
                    refusal?.message ?? context.l10n.scanCouldNotFinishHint,
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
          ScanStage.ready when isPrescription => _PrescriptionReview(
            view: view,
          ),
          ScanStage.ready => _TimetableReview(view: view),
        },
      ),
    );
  }
}

class _Pick extends ConsumerWidget {
  const new({required this.kind});

  final DocumentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(documentScanControllerProvider.notifier);
    final isPrescription = kind == DocumentKind.prescription;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          isPrescription
              ? context.l10n.scanPrescriptionTitle
              : context.l10n.scanTimetableTitle,
          style: ZadType.titleMedium,
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          isPrescription
              ? context.l10n.scanPrescriptionIntro
              : context.l10n.scanTimetableIntro,
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
          icon: Icon(
            isPrescription ? ZadIcons.prescription : ZadIcons.timetable,
          ),
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
        context.l10n.scanReadingPaper,
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

  final DocumentKind kind;
  final String title;
  final String message;
  final ZadEmptyTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = tone == ZadEmptyTone.problem
        ? ZadColors.terracottaRust
        : ZadColors.mustardOchre;
    final controller = ref.read(documentScanControllerProvider.notifier);
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
          onPressed: () => controller.scan(kind, ReceiptImageSource.camera),
          child: Text(context.l10n.scanRetake),
        ),
        const SizedBox(height: ZadSpacing.sm),
        TextButton(
          onPressed: controller.reset,
          child: Text(context.l10n.scanPickAnother),
        ),
      ],
    );
  }
}

/// Who the document is for — the field owns its controller.
class _PersonField extends ConsumerStatefulWidget {
  const new({required this.label, required this.hint, required this.initial});

  final String label;
  final String hint;
  final String initial;

  @override
  ConsumerState<_PersonField> createState() => _PersonFieldState();
}

class _PersonFieldState extends ConsumerState<_PersonField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    maxLength: 40,
    decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
    onChanged: ref.read(documentScanControllerProvider.notifier).setPerson,
  );
}

class _PrescriptionReview extends ConsumerWidget {
  const new({required this.view});

  final DocumentScanView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(documentScanControllerProvider.notifier);
    final p = view.prescription!;
    final busy = view.isSaving;
    final count = view.ticked.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.scanFoundMedicines(p.medicines.length),
          style: ZadType.titleMedium,
        ),
        const SizedBox(height: ZadSpacing.sm),
        Container(
          padding: const EdgeInsets.all(ZadSpacing.md),
          decoration: BoxDecoration(
            color: ZadColors.mustardLight,
            borderRadius: BorderRadius.circular(ZadRadii.chip),
          ),
          child: Text(
            context.l10n.scanPrescriptionCaution,
            style: ZadType.bodySmall.copyWith(color: ZadColors.ink),
          ),
        ),
        const SizedBox(height: ZadSpacing.md),
        _PersonField(
          label: context.l10n.scanPrescriptionFor,
          hint: p.patientName != null
              ? context.l10n.scanPrescriptionForNamed(p.patientName!)
              : context.l10n.scanPrescriptionForYou,
          initial: view.person,
        ),
        for (final (i, m) in p.medicines.indexed)
          CheckboxListTile(
            value: !view.excluded.contains(i),
            onChanged: busy ? null : (_) => controller.toggleLine(i),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              <String>[
                m.name,
                if (m.strength case final s? when s.isNotEmpty) s,
              ].join(' '),
              style: ZadType.bodyMedium,
            ),
            subtitle: Text(
              <String>[
                if (m.instructions case final t? when t.isNotEmpty) '«$t»',
                scheduleText(m, context.l10n),
              ].join('\n'),
              style: ZadType.labelSmall.copyWith(
                color: m.legible
                    ? ZadColors.inkMuted
                    : ZadColors.terracottaRust,
              ),
            ),
          ),
        const SizedBox(height: ZadSpacing.lg),
        FilledButton(
          onPressed: busy || count == 0
              ? null
              : () => _save(context, controller.savePrescription),
          child: busy
              ? const _Spinner()
              : Text(context.l10n.scanAddToPharmacyCount(count)),
        ),
        const SizedBox(height: ZadSpacing.sm),
        TextButton(
          onPressed: busy ? null : controller.reset,
          child: Text(context.l10n.scanRetake),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, Future<int> Function() save) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    final added = await save();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          added > 0
              ? l10n.scanMedicinesAdded(added)
              : l10n.scanMedicinesNoneAdded,
        ),
      ),
    );
    if (added > 0) await HapticFeedback.mediumImpact();
    if (navigator.mounted && added > 0) navigator.pop();
  }
}

class _TimetableReview extends ConsumerWidget {
  const new({required this.view});

  final DocumentScanView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(documentScanControllerProvider.notifier);
    final t = view.timetable!;
    final busy = view.isSaving;
    final person = view.person.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.scanTimetableDays(t.days.length),
          style: ZadType.titleMedium,
        ),
        const SizedBox(height: ZadSpacing.md),
        _PersonField(
          label: context.l10n.scanTimetableFor,
          hint: t.className != null
              ? context.l10n.scanTimetableClass(t.className!)
              : context.l10n.scanChildName,
          initial: view.person,
        ),
        for (final d in t.days)
          Padding(
            padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 72,
                  child: Text(
                    // 0 = Sunday here; weekdayName counts from Monday.
                    context.l10n.weekdayName(
                      d.weekday == 0 ? 'd7' : 'd${d.weekday}',
                    ),
                    style: ZadType.labelLarge,
                  ),
                ),
                Expanded(
                  child: Text(
                    d.periods
                        .map((p) => p.subject)
                        .join(context.l10n.scanTimesSeparator),
                    style: ZadType.bodySmall.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: ZadSpacing.lg),
        FilledButton(
          onPressed: busy || person.isEmpty
              ? null
              : () => _save(context, controller.saveTimetable),
          child: busy
              ? const _Spinner()
              : Text(
                  person.isEmpty
                      ? context.l10n.scanNameFirst
                      : context.l10n.scanSaveTimetable(person),
                ),
        ),
        const SizedBox(height: ZadSpacing.sm),
        TextButton(
          onPressed: busy ? null : controller.reset,
          child: Text(context.l10n.scanRetake),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, Future<int> Function() save) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    final kept = await save();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          kept > 0 ? l10n.scanTimetableSaved(kept) : l10n.scanTimetableNotSaved,
        ),
      ),
    );
    if (kept > 0) await HapticFeedback.mediumImpact();
    if (navigator.mounted && kept > 0) navigator.pop();
  }
}

class _Spinner extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
