/// The two photo reads besides the receipt — a pantry shelf and a medicine
/// box, Kotlin's `INVENTORY` and `PHARMACY` camera modes.
///
/// Same rule as the receipt: nothing is written until the customer has seen
/// the reading. A pantry photo's items are listed with a tick each and go in
/// through the receipt's own [intakeIntoPantry] — the same name matching, the
/// same shopping-list loop, the same before-and-after readings. A medicine
/// box's reading is handed to the add form, filled in, and saved from there.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/inventory/domain/receipt_intake.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/data/receipt_scanner.dart';
import 'package:zad/features/scan/data/vision_scanner.dart';

/// What was photographed.
enum PhotoKind {
  /// A shelf, a fridge, a bag of shopping.
  pantry,

  /// One medicine box.
  medicine,
}

/// What the photo sheet draws.
class PhotoScanView {
  /// Creates a view.
  const new({
    this.stage = ScanStage.idle,
    this.items = const <ScannedPantryItem>[],
    this.excluded = const <int>{},
    this.medicine,
    this.isSaving = false,
    this.error,
    this.lastIntake,
  });

  /// Where things stand.
  final ScanStage stage;

  /// A pantry photo's items.
  final List<ScannedPantryItem> items;

  /// Items the customer unticked, by index into [items].
  final Set<int> excluded;

  /// A medicine box's reading.
  final ScannedMedicine? medicine;

  /// Whether a save is in flight.
  final bool isSaving;

  /// The transport failure behind [ScanStage.failed].
  final Object? error;

  /// What the last save did to the pantry.
  final PantryIntakeResult? lastIntake;

  /// The items still ticked.
  List<ScannedPantryItem> get ticked => <ScannedPantryItem>[
    for (final (i, item) in items.indexed)
      if (!excluded.contains(i)) item,
  ];

  /// Whether the screen is waiting on the camera or the model.
  bool get isWorking => stage == ScanStage.working;
}

/// Drives one photo from shutter to saved rows.
class PhotoScanController extends Notifier<PhotoScanView> {
  @override
  PhotoScanView build() => const PhotoScanView();

  /// Takes a photograph and has it read as [kind].
  Future<void> scan(PhotoKind kind, ReceiptImageSource source) async {
    if (!ref.mounted || state.isWorking) return;

    final userId = ref.read(signedInUserIdProvider)();
    if (userId == null || userId.isEmpty) {
      state = PhotoScanView(
        stage: ScanStage.failed,
        error: StateError('no signed-in user to read a photo for'),
      );
      return;
    }

    state = const PhotoScanView(stage: ScanStage.working);
    try {
      final image = await ref.read(receiptCameraProvider).capture(source);
      if (!ref.mounted) return;
      if (image == null) {
        state = const PhotoScanView();
        return;
      }

      final scanner = ref.read(visionScannerProvider);
      switch (kind) {
        case PhotoKind.pantry:
          final items = await scanner.pantry(userId: userId, image: image);
          if (!ref.mounted) return;
          state = PhotoScanView(
            stage: items.isEmpty ? ScanStage.unreadable : ScanStage.ready,
            items: items,
          );
        case PhotoKind.medicine:
          final medicine = await scanner.medicine(userId: userId, image: image);
          if (!ref.mounted) return;
          state = PhotoScanView(
            stage: medicine == null ? ScanStage.unreadable : ScanStage.ready,
            medicine: medicine,
          );
      }
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = PhotoScanView(stage: ScanStage.failed, error: error);
    }
  }

  /// Ticks or unticks one pantry item.
  void toggleItem(int index) {
    if (!ref.mounted || index < 0 || index >= state.items.length) return;
    final next = <int>{...state.excluded};
    if (!next.remove(index)) next.add(index);
    state = PhotoScanView(
      stage: state.stage,
      items: state.items,
      excluded: next,
    );
  }

  /// Puts the ticked items into the pantry. True when they went in.
  Future<bool> savePantry() async {
    final ticked = state.ticked;
    if (!ref.mounted || state.isSaving || ticked.isEmpty) return false;

    state = PhotoScanView(
      stage: state.stage,
      items: state.items,
      excluded: state.excluded,
      isSaving: true,
    );
    final intake = await intakeIntoPantry(ref, <IntakeLine>[
      for (final item in ticked)
        IntakeLine(
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          category: item.category,
        ),
    ]);
    // Cleared either way. A failure can land after some rows were already
    // written, so keeping the reading for a second tap would add those twice.
    if (ref.mounted) state = PhotoScanView(lastIntake: intake);
    return !intake.failed;
  }

  /// Throws the reading away.
  void reset() {
    if (ref.mounted) state = const PhotoScanView();
  }
}

/// One photo read.
final photoScanControllerProvider =
    NotifierProvider<PhotoScanController, PhotoScanView>(
      PhotoScanController.new,
    );
