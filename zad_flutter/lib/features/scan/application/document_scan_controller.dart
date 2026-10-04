/// A prescription or a school timetable, from shutter to saved rows
/// (docs/agent/ZAD_LIVING_BRAIN.md slice 21).
///
/// Same rule as every photo: nothing is written until the customer has seen
/// the reading. A prescription's medicines go into the pharmacy one row each
/// — with the times derived from the frequency written on the paper, a course
/// that ends when its doses do, and who they are for. A line the server could
/// not read is unticked from the start. A timetable replaces that child's
/// timetable whole.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/scan/data/document_scanner.dart';
import 'package:zad/shared/scan/data/receipt_scanner.dart';
import 'package:zad/shared/scan/domain/scanned_document.dart';

/// What the document sheet draws.
class DocumentScanView {
  /// Creates a view.
  const new({
    this.stage = ScanStage.idle,
    this.prescription,
    this.timetable,
    this.excluded = const <int>{},
    this.person = '',
    this.isSaving = false,
    this.saved,
    this.error,
  });

  /// Where things stand.
  final ScanStage stage;

  /// A prescription's reading.
  final ScannedPrescription? prescription;

  /// A timetable's reading.
  final ScannedTimetable? timetable;

  /// Prescription lines unticked, by index.
  final Set<int> excluded;

  /// Who it is for: empty is the customer on a prescription, and required on
  /// a timetable.
  final String person;

  /// Whether a save is in flight.
  final bool isSaving;

  /// How many rows the last save wrote; null before one.
  final int? saved;

  /// The transport failure behind [ScanStage.failed].
  final Object? error;

  /// The prescription lines still ticked.
  List<PrescriptionLine> get ticked => <PrescriptionLine>[
    for (final (i, m)
        in (prescription?.medicines ?? const <PrescriptionLine>[]).indexed)
      if (!excluded.contains(i)) m,
  ];

  /// A copy with some fields changed.
  DocumentScanView copyWith({
    Set<int>? excluded,
    String? person,
    bool? isSaving,
  }) => DocumentScanView(
    stage: stage,
    prescription: prescription,
    timetable: timetable,
    excluded: excluded ?? this.excluded,
    person: person ?? this.person,
    isSaving: isSaving ?? this.isSaving,
    saved: saved,
    error: error,
  );
}

/// The pharmacy row a prescription line becomes.
({
  int quantity,
  String unit,
  int dailyDoseCount,
  String? doseTimes,
  String? dosage,
  bool isRecurring,
})
pharmacyRowFor(PrescriptionLine m) => (
  // A course's doses when both are written; otherwise 0 — «not bought yet»,
  // never a count the paper did not give.
  quantity: m.courseDoses ?? 0,
  unit: (m.form?.trim().isNotEmpty ?? false) ? m.form!.trim() : 'قرص',
  dailyDoseCount: m.timesPerDay ?? 1,
  doseTimes: m.legible ? m.suggestedTimes : null,
  dosage: _dosage(m),
  // No duration written and not «as needed»: an ongoing medicine.
  isRecurring: m.durationDays == null && !m.asNeeded,
);

String? _dosage(PrescriptionLine m) {
  final parts = <String>[
    if (m.strength?.trim().isNotEmpty ?? false) m.strength!.trim(),
    if (m.instructions?.trim().isNotEmpty ?? false) m.instructions!.trim(),
  ];
  return parts.isEmpty ? null : parts.join(' — ');
}

/// Drives one document photo.
class DocumentScanController extends Notifier<DocumentScanView> {
  @override
  DocumentScanView build() => const DocumentScanView();

  /// Takes a photograph and has it read as [kind].
  Future<void> scan(DocumentKind kind, ReceiptImageSource source) async {
    if (!ref.mounted || state.stage == ScanStage.working) return;
    final userId = ref.read(signedInUserIdProvider)();
    if (userId == null || userId.isEmpty) {
      state = DocumentScanView(
        stage: ScanStage.failed,
        error: StateError('no signed-in user to read a document for'),
      );
      return;
    }
    state = const DocumentScanView(stage: ScanStage.working);
    try {
      final image = await ref.read(receiptCameraProvider).capture(source);
      if (!ref.mounted) return;
      if (image == null) {
        state = const DocumentScanView();
        return;
      }
      final scanner = ref.read(documentScannerProvider);
      switch (kind) {
        case DocumentKind.prescription:
          final p = await scanner.prescription(userId: userId, image: image);
          if (!ref.mounted) return;
          state = p == null
              ? const DocumentScanView(stage: ScanStage.unreadable)
              : DocumentScanView(
                  stage: ScanStage.ready,
                  prescription: p,
                  // What the server could not read stays out unless ticked.
                  excluded: <int>{
                    for (final (i, m) in p.medicines.indexed)
                      if (!m.legible) i,
                  },
                );
        case DocumentKind.timetable:
          final t = await scanner.timetable(userId: userId, image: image);
          if (!ref.mounted) return;
          state = t == null
              ? const DocumentScanView(stage: ScanStage.unreadable)
              : DocumentScanView(
                  stage: ScanStage.ready,
                  timetable: t,
                  person: t.studentName?.trim() ?? '',
                );
      }
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = DocumentScanView(stage: ScanStage.failed, error: error);
    }
  }

  /// Ticks or unticks one prescription line.
  void toggleLine(int index) {
    if (!ref.mounted) return;
    final next = <int>{...state.excluded};
    if (!next.remove(index)) next.add(index);
    state = state.copyWith(excluded: next);
  }

  /// Who the document is for.
  void setPerson(String person) {
    if (ref.mounted) state = state.copyWith(person: person);
  }

  /// Adds the ticked medicines to the pharmacy. The number added.
  Future<int> savePrescription() async {
    final lines = state.ticked;
    if (!ref.mounted || state.isSaving || lines.isEmpty) return 0;
    state = state.copyWith(isSaving: true);
    final person = state.person.trim();
    final pharmacy = ref.read(pharmacyControllerProvider.notifier);
    var added = 0;
    try {
      for (final m in lines) {
        final row = pharmacyRowFor(m);
        await pharmacy.add(
          name: m.name,
          quantity: row.quantity,
          unit: row.unit,
          dailyDoseCount: row.dailyDoseCount,
          doseTimes: row.doseTimes,
          dosage: row.dosage,
          isRecurring: row.isRecurring,
          forPerson: person.isEmpty ? null : person,
        );
        added++;
      }
    } on Object catch (error) {
      if (ref.mounted) {
        state = DocumentScanView(
          stage: ScanStage.failed,
          error: error,
          saved: added,
        );
      }
      return added;
    }
    if (ref.mounted) state = DocumentScanView(saved: added);
    return added;
  }

  /// Keeps the timetable for [DocumentScanView.person]. The periods kept.
  Future<int> saveTimetable() async {
    final t = state.timetable;
    final person = state.person.trim();
    if (!ref.mounted || state.isSaving || t == null || person.isEmpty) return 0;
    state = state.copyWith(isSaving: true);
    try {
      final kept = await ref
          .read(documentScannerProvider)
          .saveTimetable(person: person, days: t.days);
      if (ref.mounted) state = DocumentScanView(saved: kept);
      return kept;
    } on Object catch (error) {
      if (ref.mounted) {
        state = DocumentScanView(stage: ScanStage.failed, error: error);
      }
      return 0;
    }
  }

  /// Throws the reading away.
  void reset() {
    if (ref.mounted) state = const DocumentScanView();
  }
}

/// One document read.
final documentScanControllerProvider =
    NotifierProvider<DocumentScanController, DocumentScanView>(
      DocumentScanController.new,
    );
