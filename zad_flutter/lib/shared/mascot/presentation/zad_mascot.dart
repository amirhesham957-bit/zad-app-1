/// Zad's mascot where Zad is the subject of the screen — the chat's header,
/// the voice sheet. Plays the designer's Rive file when it is in the app,
/// and draws the orb (`CompanionOrb`) when it is not, while it loads, or if
/// it fails: the screen never shows an empty space where Zad should be.
///
/// Until `assets/rive/zad_mascot.riv` is added this is exactly the orb.
/// The names the file must have are in `mascot_contract.dart`; the spec for
/// the designer is `docs/agent/ZAD_MASCOT_RIVE_SPEC.md`.
///
/// Small copies of Zad (a message's 18dp avatar) stay orbs: one Rive
/// instance per bubble would cost far more than it shows.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' as rive;
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/mascot/domain/mascot_contract.dart';
import 'package:zad/shared/orb/application/orb_accessory_controller.dart';
import 'package:zad/shared/orb/application/orb_occasion_controller.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/domain/orb_occasion.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// Whether the designer's file is in this build. Read once from the asset
/// manifest, so a build without it never touches the Rive runtime.
final FutureProvider<bool> mascotFileProvider = FutureProvider<bool>((
  ref,
) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest.listAssets().contains(MascotContract.asset);
  } on Object {
    return false;
  }
});

/// The mascot.
class ZadMascot extends ConsumerWidget {
  /// Creates the mascot.
  const new({
    required this.state,
    this.size = 96,
    this.audioLevel,
    this.onTap,
    super.key,
  });

  /// What Zad is doing.
  final CompanionState state;

  /// The box it is drawn in.
  final double size;

  /// The voice's loudness, 0..1, while listening or speaking.
  final ValueListenable<double>? audioLevel;

  /// A tap, after Zad's own reaction to it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orb = CompanionOrb(
      state: state,
      size: size,
      audioLevel: audioLevel,
      onTap: onTap,
    );
    final hasFile = ref.watch(mascotFileProvider).value ?? false;
    if (!hasFile) return orb;
    return _RiveMascot(
      state: state,
      size: size,
      audioLevel: audioLevel,
      onTap: onTap,
      fallback: orb,
    );
  }
}

class _RiveMascot extends ConsumerStatefulWidget {
  const new({
    required this.state,
    required this.size,
    required this.audioLevel,
    required this.onTap,
    required this.fallback,
  });

  final CompanionState state;
  final double size;
  final ValueListenable<double>? audioLevel;
  final VoidCallback? onTap;
  final Widget fallback;

  @override
  ConsumerState<_RiveMascot> createState() => _RiveMascotState();
}

class _RiveMascotState extends ConsumerState<_RiveMascot> {
  late final rive.FileLoader _loader = rive.FileLoader.fromAsset(
    MascotContract.asset,
    riveFactory: rive.Factory.rive,
  );
  MascotBinder? _binder;

  @override
  void initState() {
    super.initState();
    widget.audioLevel?.addListener(_onLevel);
  }

  @override
  void didUpdateWidget(_RiveMascot old) {
    super.didUpdateWidget(old);
    if (old.audioLevel != widget.audioLevel) {
      old.audioLevel?.removeListener(_onLevel);
      widget.audioLevel?.addListener(_onLevel);
    }
  }

  @override
  void dispose() {
    widget.audioLevel?.removeListener(_onLevel);
    _loader.dispose();
    super.dispose();
  }

  void _onLevel() => _binder?.level(widget.audioLevel?.value ?? 0);

  MascotInputs _inputs() => MascotInputs.from(
    state: widget.state,
    occasion: ref.watch<OrbOccasion>(orbOccasionProvider),
    accessory: ref.watch(orbAccessoryProvider),
    look: ref.watch(companionLookProvider),
  );

  void _onLoaded(rive.RiveLoaded loaded) {
    final binder = MascotBinder(
      _ViewModelSink(loaded.viewModelInstance),
      // A file built to an older spec: say which name, once per name.
      onMissing: (name) => debugPrint(
        '[mascot] ${MascotContract.asset} has no «$name» — see '
        'docs/agent/ZAD_MASCOT_RIVE_SPEC.md',
      ),
    );
    _binder = binder;
    binder.apply(_inputs());
    _onLevel();
  }

  @override
  Widget build(BuildContext context) {
    final inputs = _inputs();
    // Diffed inside: an unchanged mood touches nothing in the file.
    _binder?.apply(inputs);
    return SizedBox.square(
      dimension: widget.size,
      child: rive.RiveWidgetBuilder(
        fileLoader: _loader,
        artboardSelector: rive.ArtboardSelector.byName(MascotContract.artboard),
        stateMachineSelector: rive.StateMachineSelector.byName(
          MascotContract.stateMachine,
        ),
        dataBind: rive.DataBind.auto(),
        onLoaded: _onLoaded,
        onFailed: (error, _) =>
            debugPrint('[mascot] falling back to the orb: $error'),
        builder: (context, state) => switch (state) {
          rive.RiveLoaded(:final controller) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _binder?.tap();
              widget.onTap?.call();
            },
            child: Semantics(
              label: widget.state.description,
              // Fit.contain, the default: the whole of Zad, never cropped.
              child: rive.RiveWidget(controller: controller),
            ),
          ),
          _ => widget.fallback,
        },
      ),
    );
  }
}

/// The bound View Model. Each property is looked up once and kept; the
/// runtime frees the wrappers with the instance (they carry a finalizer).
class _ViewModelSink implements MascotSink {
  new(this._vmi);

  final rive.ViewModelInstance? _vmi;
  final Map<String, rive.ViewModelInstanceEnum?> _enums =
      <String, rive.ViewModelInstanceEnum?>{};
  final Map<String, rive.ViewModelInstanceNumber?> _numbers =
      <String, rive.ViewModelInstanceNumber?>{};
  final Map<String, rive.ViewModelInstanceColor?> _colors =
      <String, rive.ViewModelInstanceColor?>{};
  final Map<String, rive.ViewModelInstanceBoolean?> _bools =
      <String, rive.ViewModelInstanceBoolean?>{};
  final Map<String, rive.ViewModelInstanceTrigger?> _triggers =
      <String, rive.ViewModelInstanceTrigger?>{};

  @override
  bool setEnum(String name, String value) {
    final p = _enums.putIfAbsent(name, () => _vmi?.enumerator(name));
    if (p == null) return false;
    p.value = value;
    return true;
  }

  @override
  bool setNumber(String name, double value) {
    final p = _numbers.putIfAbsent(name, () => _vmi?.number(name));
    if (p == null) return false;
    p.value = value;
    return true;
  }

  @override
  bool setColor(String name, Color value) {
    final p = _colors.putIfAbsent(name, () => _vmi?.color(name));
    if (p == null) return false;
    p.value = value;
    return true;
  }

  @override
  bool setBool(String name, {required bool value}) {
    final p = _bools.putIfAbsent(name, () => _vmi?.boolean(name));
    if (p == null) return false;
    p.value = value;
    return true;
  }

  @override
  bool fire(String name) {
    final p = _triggers.putIfAbsent(name, () => _vmi?.trigger(name));
    if (p == null) return false;
    p.trigger();
    return true;
  }
}
