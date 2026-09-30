/// Kotlin's `ZadVoiceBottomSheet`, in the turn-by-turn mode Kotlin falls back
/// to: hold the microphone and speak, let go and زاد answers in her voice —
/// one voice, a girl's, in the account's dialect (the owner's decision,
/// 2026-09-27; Kotlin's Sarah/Karim/pet persona picker is not carried over).
/// The dark sheet, the status pill, the orb, the 26 wave bars, the
/// hold-to-talk button and the ready questions — as Kotlin draws them.
///
/// The live call (`zad-voice-live`) is cancelled for good, so this is the
/// sheet's only mode, and Kotlin's «المكالمة المباشرة مش متاحة» note and its
/// retry button have nothing to point at. The turn goes through the chat —
/// Whisper, then the same agent turn a typed message makes, sent with
/// `viaVoice` (Kotlin's `voiceMode = true`: a short reply written to be heard)
/// — and the chat controller speaks the reply once, never followed by
/// listening on its own (Kotlin's loop fix). A failed turn says so; it never
/// re-speaks the previous answer.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_palette.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/chat/application/voice_input_controller.dart';
import 'package:zad/shared/orb/application/companion_mood.dart';
import 'package:zad/shared/orb/application/pet_sound.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';
import 'package:zad/shared/voice/application/voice_output_controller.dart';
import 'package:zad/shared/voice/application/zad_voice.dart';

/// Opens the sheet.
Future<void> showZadVoiceSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZadPalette.voiceDarkSheetBg,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => const ZadVoiceSheet(),
    );

/// The sheet.
class ZadVoiceSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const new({super.key});

  @override
  ConsumerState<ZadVoiceSheet> createState() => _ZadVoiceSheetState();
}

class _ZadVoiceSheetState extends ConsumerState<ZadVoiceSheet> {
  static const List<String> _chips = <String>[
    'حلل مصاريفي',
    'اقترح وجبة',
    'كام فاضل في الميزانية؟',
    'صرفت 50 على القهوة',
  ];

  // Both captured in initState: `ref` may not be used in dispose.
  late final ZadVoice _voice;
  late final VoiceInputController _input;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(zadVoiceProvider);
    _input = ref.read(voiceInputControllerProvider.notifier);
    // «لحظة واحدة…» in her voice, kept for the next question — once per
    // install, a few requests, never on the way of this one.
    unawaited(ref.read(voiceOpenersProvider).warmUp());
  }

  final ValueNotifier<double> _mic = ValueNotifier<double>(0);
  String _recognized = '';
  // Zad's answer, shown the moment it arrives: the audio takes seconds more,
  // and a silent sheet in between read as «مش شغال» (owner, 2026-10-01).
  String _reply = '';

  /// A turn this sheet sent that has not settled yet.
  bool _awaitingTurn = false;

  /// The last turn this sheet sent failed.
  bool _turnFailed = false;

  @override
  void dispose() {
    _mic.dispose();
    _voice.stop();
    if (_recording) unawaited(_input.cancel());
    super.dispose();
  }

  void _submit(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _recognized = text;
      _reply = '';
      _awaitingTurn = true;
      _turnFailed = false;
    });
    unawaited(
      ref.read(chatControllerProvider.notifier).send(text, viaVoice: true),
    );
  }

  Future<void> _pressDown() async {
    _voice.stop();
    if (_turnFailed) setState(() => _turnFailed = false);
    await ref.read(voiceInputControllerProvider.notifier).start();
  }

  Future<void> _release() async {
    await ref.read(voiceInputControllerProvider.notifier).stopAndTranscribe();
  }

  @override
  Widget build(BuildContext context) {
    final input = ref.watch(voiceInputControllerProvider);
    final chat = ref.watch(chatControllerProvider);

    // Whisper's words become the turn — Kotlin's fallback submits what the
    // recogniser heard.
    ref
      ..listen(voiceInputControllerProvider, (_, next) {
        _recording = next.isRecording;
        _mic.value = next.isRecording ? next.amplitude : 0;
        final heard = next.transcript;
        if (heard != null) {
          ref.read(voiceInputControllerProvider.notifier).transcriptTaken();
          _submit(heard);
        }
      })
      ..listen(chatControllerProvider.select((v) => v.isAwaitingReply), (
        was,
        now,
      ) {
        if (was != true || now || !_awaitingTurn) return;
        // The chat controller speaks a good reply itself (viaVoice). A failed
        // turn has nothing to say — and must not fall back on the last one.
        final after = ref.read(chatControllerProvider);
        setState(() {
          _awaitingTurn = false;
          _turnFailed = after.error != null;
          _reply = _turnFailed
              ? ''
              : after.messages
                    .lastWhere(
                      (m) => !m.isUser,
                      orElse: () => after.messages.last,
                    )
                    .text;
        });
      });

    // What the voice is doing, not whether it is busy: the reply's speech is
    // set up the moment a turn is sent, and «زاد بيتكلم…» over ten seconds of
    // silence read as «مش شغال» (owner, 2026-10-01).
    final voiceStage = ref.watch(
      voiceOutputControllerProvider.select((v) => v.stage),
    );
    return Builder(
      builder: (context) {
        final isSpeaking = voiceStage == VoiceOutputStage.speaking;
        final isActive = input.isRecording;
        final transcribing = input.stage == VoiceStage.transcribing;
        final thinking =
            transcribing || (_awaitingTurn && chat.isAwaitingReply);
        final preparingVoice = voiceStage == VoiceOutputStage.preparing;
        final error = switch (input.stage) {
          VoiceStage.denied => 'امنح التطبيق إذن استخدام الميكروفون',
          VoiceStage.failed => 'حدث خطأ في التعرف على الصوت',
          VoiceStage.tooShort => 'لم أسمع كلامًا واضحًا، حاول مرة أخرى',
          _ when _turnFailed => 'ماقدرتش أوصل لعقل زاد دلوقتي',
          _ => null,
        };
        final indicator = error != null || isSpeaking
            ? ZadPalette.voiceAlertAmber
            : isActive
            ? ZadPalette.voiceWaveMint
            : ZadPalette.voiceTextSoft;
        final levels = isSpeaking ? _voice.level : _mic;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _Pulse(
                              on: isActive,
                              min: 0.85,
                              max: 1.35,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: indicator,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isSpeaking
                                  ? 'زاد بيتكلم…'
                                  : transcribing
                                  ? 'بكتب كلامك…'
                                  : thinking
                                  ? 'بيفكر…'
                                  : preparingVoice
                                  ? 'بيجهز صوته…'
                                  : 'مساعد زاد الصوتي',
                              style: ZadType.labelLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          _SheetIconButton(
                            icon: Icons.close,
                            label: 'إغلاق',
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CompanionOrb(
                    state: ref.watch(companionMoodProvider),
                    size: 144,
                    audioLevel: levels,
                    onTap: () => playPetSound(PetSound.happyChirp, volume: 0.5),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ValueListenableBuilder<double>(
                      valueListenable: levels,
                      builder: (_, level, _) => ZadAudioWavebars(
                        isListening: isActive,
                        soundLevel: level,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      error != null
                          ? '⚠️ $error\nاضغط المايك وجرّب تاني'
                          : _recognized.isNotEmpty && !isActive
                          ? _recognized
                          : isSpeaking
                          ? 'زاد بيتكلم… اتكلم في أي وقت تقاطعه'
                          : thinking
                          ? 'يفكر عقل زاد وينفذ طلبك…'
                          : isActive
                          ? 'زاد سامعك — اتكلم براحتك'
                          : 'اضغط المايك وكلّم زاد 🎙️',
                      textAlign: TextAlign.center,
                      style: ZadType.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: error != null
                            ? ZadPalette.voiceAlertAmber
                            : Colors.white,
                      ),
                    ),
                  ),
                  if (_reply.isNotEmpty &&
                      error == null &&
                      !isActive) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 160),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _reply,
                          textAlign: TextAlign.start,
                          style: ZadType.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label: 'دوس مع الاستمرار واتكلم',
                    child: Listener(
                      onPointerDown: (_) => unawaited(_pressDown()),
                      onPointerUp: (_) => unawaited(_release()),
                      onPointerCancel: (_) => unawaited(_release()),
                      child: _Pulse(
                        on: isActive,
                        min: 1,
                        max: 1.07,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: isSpeaking
                                  ? const <Color>[
                                      ZadPalette.voiceAlertAmber,
                                      ZadPalette.voiceAlertBrown,
                                    ]
                                  : isActive
                                  ? const <Color>[
                                      ZadPalette.voiceDangerStart,
                                      ZadPalette.voiceDangerEnd,
                                    ]
                                  : const <Color>[
                                      ZadPalette.voiceWaveEmerald,
                                      ZadPalette.voiceWaveTealDark,
                                    ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isActive
                        ? 'بسمعك… سيب عشان أرد'
                        : isSpeaking
                        ? 'دوس واتكلم عشان تقاطعني'
                        : 'دوس مع الاستمرار واتكلم',
                    style: ZadType.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? ZadPalette.voiceTextMint
                          : ZadPalette.voiceAlertAmber,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'أو اختار سؤال جاهز:',
                    style: ZadType.labelMedium.copyWith(
                      color: ZadPalette.voiceTextSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final chip in _chips)
                        Material(
                          color: Colors.white.withValues(alpha: 0.10),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _submit(chip),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Center(
                                  widthFactor: 1,
                                  child: Text(
                                    chip,
                                    style: ZadType.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: ZadPalette.voiceTextMint,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SheetIconButton extends StatelessWidget {
  const new({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.08),
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: SizedBox.square(
        dimension: 44,
        child: Icon(
          icon,
          size: 20,
          color: Colors.white.withValues(alpha: 0.9),
          semanticLabel: label,
        ),
      ),
    ),
  );
}

/// Kotlin's `pulseGlow`: a 900ms scale between [min] and [max], reversing.
class _Pulse extends StatefulWidget {
  const new({
    required this.on,
    required this.min,
    required this.max,
    required this.child,
  });

  final bool on;
  final double min;
  final double max;
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    if (old.on != widget.on) _sync();
  }

  void _sync() {
    if (widget.on) {
      _t.repeat(reverse: true);
    } else {
      _t
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      builder: (_, child) => Transform.scale(
        scale:
            widget.min +
            (widget.max - widget.min) *
                Curves.fastOutSlowIn.transform(_t.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Kotlin's `ZadAudioWavebars`: 26 thin bars on a parabolic envelope, a
/// 1400ms travelling wave, lifted by the sound level while listening.
class ZadAudioWavebars extends StatefulWidget {
  /// Creates the bars.
  const new({required this.isListening, this.soundLevel = 0, super.key});

  /// Whether the microphone is live.
  final bool isListening;

  /// Loudness, 0..1.
  final double soundLevel;

  @override
  State<ZadAudioWavebars> createState() => _WavebarsState();
}

class _WavebarsState extends State<ZadAudioWavebars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _phase,
    builder: (_, _) => CustomPaint(
      painter: _WavebarsPainter(
        phase: _phase.value * 2 * math.pi,
        listening: widget.isListening,
        level: widget.soundLevel,
      ),
    ),
  );
}

class _WavebarsPainter extends CustomPainter {
  new({required this.phase, required this.listening, required this.level});

  final double phase;
  final bool listening;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 26;
    const barWidth = 3.2;
    const spacing = 3.6;
    const total = count * barWidth + (count - 1) * spacing;
    final startX = (size.width - total) / 2;
    final centerY = size.height / 2;
    for (var i = 0; i < count; i++) {
      final norm = (i - (count - 1) / 2) / ((count - 1) / 2);
      final envelope = (1 - norm * norm * 0.72).clamp(0.25, 1.0);
      final wave = math.sin(phase + i * 0.42);
      final boost = (level * 1.8).clamp(0.0, 1.0);
      final dynamicScale = (0.28 + 0.35 * wave + 0.95 * boost).clamp(0.12, 1.0);
      final multiplier = listening
          ? (envelope * dynamicScale).clamp(0.18, 1.0)
          : (0.12 + 0.06 * wave).clamp(0.08, 0.20);
      final h = math.max<double>(size.height * 0.88 * multiplier, 4);
      final rect = Rect.fromLTWH(
        startX + i * (barWidth + spacing),
        centerY - h / 2,
        barWidth,
        h,
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: listening
              ? const <Color>[
                  ZadPalette.voiceWaveMint,
                  ZadPalette.voiceWaveEmerald,
                  ZadPalette.voiceWaveTealDark,
                ]
              : <Color>[
                  ZadPalette.voiceWaveInactiveTop.withValues(alpha: 0.5),
                  ZadPalette.voiceWaveInactiveBottom.withValues(alpha: 0.3),
                ],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavebarsPainter old) =>
      old.phase != phase || old.listening != listening || old.level != level;
}
