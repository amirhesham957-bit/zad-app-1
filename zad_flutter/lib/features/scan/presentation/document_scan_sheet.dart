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
import 'package:zad/features/scan/application/document_scan_controller.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
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
    backgroundColor: ZadColors.surface,
    shape: zadSquircle(ZadRadii.sheet),
    builder: (_) => DocumentScanSheet(kind: kind),
  );
}

/// What a schedule line says, in words.
String scheduleText(PrescriptionLine m) {
  if (!m.legible) return 'مش واضحة في الصورة — صحّحها أو شيلها';
  if (m.asNeeded) return 'عند اللزوم — من غير مواعيد';
  final parts = <String>[
    if (m.timesPerDay case final n?) '$n مرات في اليوم',
    if (m.suggestedTimes case final t?) t.replaceAll(',', '، '),
    if (m.durationDays case final d?) 'لمدة $d يوم',
  ];
  return parts.isEmpty
      ? 'المرات مش مكتوبة — حددها في الصيدلية'
      : parts.join(' · ');
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
                ? 'مقدرتش أقرا الروشتة'
                : 'مقدرتش أقرا الجدول',
            message: 'صوّر الورقة كلها قريب، من غير لمعة وفي إضاءة كويسة.',
            tone: ZadEmptyTone.waiting,
          ),
          ScanStage.failed => _Retry(
            kind: kind,
            title: 'مقدرتش أكمّل',
            message: 'النت أو السيرفر — جرب تاني كمان شوية.',
            tone: ZadEmptyTone.problem,
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
          isPrescription ? 'صوّر الروشتة' : 'صوّر جدول الحصص',
          style: ZadType.titleMedium,
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          isPrescription
              ? 'هنقل الأدوية والجرعات زي ما هي مكتوبة، وتراجعها قبل ما '
                    'تدخل الصيدلية بمواعيدها.'
              : 'هقرا الأيام والحصص، وتراجعها قبل ما أحفظها — وبالليل '
                    'أفكّرك بشنطة بكرة.',
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
          icon: Icon(
            isPrescription ? ZadIcons.prescription : ZadIcons.timetable,
          ),
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
        'بقرا الورقة…',
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
          child: const Text('صوّر تاني'),
        ),
        const SizedBox(height: ZadSpacing.sm),
        TextButton(
          onPressed: controller.reset,
          child: const Text('اختار صورة تانية'),
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
        Text('لقيت ${p.medicines.length} دوا', style: ZadType.titleMedium),
        const SizedBox(height: ZadSpacing.sm),
        Container(
          padding: const EdgeInsets.all(ZadSpacing.md),
          decoration: BoxDecoration(
            color: ZadColors.mustardLight,
            borderRadius: BorderRadius.circular(ZadRadii.chip),
          ),
          child: Text(
            'زاد بينقل اللي مكتوب في الروشتة بس — راجع الجرعات والمواعيد '
            'مع الصيدلي أو الدكتور.',
            style: ZadType.bodySmall.copyWith(color: ZadColors.ink),
          ),
        ),
        const SizedBox(height: ZadSpacing.md),
        _PersonField(
          label: 'الروشتة لمين؟',
          hint: p.patientName != null
              ? 'مكتوب عليها: ${p.patientName} — فاضي = ليك'
              : 'فاضي = ليك',
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
                scheduleText(m),
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
          child: busy ? const _Spinner() : Text('ضيف للصيدلية ($count)'),
        ),
        const SizedBox(height: ZadSpacing.sm),
        TextButton(
          onPressed: busy ? null : controller.reset,
          child: const Text('صوّر تاني'),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, Future<int> Function() save) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final added = await save();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          added > 0
              ? 'اتضاف $added دوا للصيدلية بمواعيدهم.'
              : 'مااتضافش حاجة — راجع الصيدلية وضيف بإيدك.',
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
        Text('جدول ${t.days.length} أيام', style: ZadType.titleMedium),
        const SizedBox(height: ZadSpacing.md),
        _PersonField(
          label: 'الجدول ده لمين؟',
          hint: t.className != null ? 'فصل ${t.className}' : 'اسم الطفل',
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
                    kWeekdayNames[d.weekday],
                    style: ZadType.labelLarge,
                  ),
                ),
                Expanded(
                  child: Text(
                    d.periods.map((p) => p.subject).join('، '),
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
              : Text(person.isEmpty ? 'اكتب اسمه الأول' : 'احفظ جدول $person'),
        ),
        const SizedBox(height: ZadSpacing.sm),
        TextButton(
          onPressed: busy ? null : controller.reset,
          child: const Text('صوّر تاني'),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, Future<int> Function() save) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final kept = await save();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          kept > 0
              ? 'اتحفظ الجدول ($kept حصة) — هفكّرك بشنطة بكرة بالليل.'
              : 'مااتحفظش الجدول — جرب تاني.',
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
