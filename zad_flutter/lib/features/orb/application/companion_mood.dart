/// Kotlin's `companionMood`: the one mood every orb in the app reads.
///
/// The voice wins while it runs — it is something the customer started just
/// now — and when it stops the mood falls back to the conversation's, not to
/// calm: Kotlin's `companionMoodForVoice` returns null for an idle mic so a
/// resting microphone cannot talk over an alert.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/chat/application/voice_input_controller.dart';
import 'package:zad/features/orb/domain/companion_state.dart';

/// The mood.
final Provider<CompanionState> companionMoodProvider = Provider<CompanionState>(
  (ref) {
    final stage = ref.watch(
      voiceInputControllerProvider.select((v) => v.stage),
    );
    switch (stage) {
      case VoiceStage.recording:
        return CompanionState.listening;
      case VoiceStage.transcribing:
        return CompanionState.focused;
      // Everything else (idle, too short, denied, failed) means the voice
      // has nothing to say — Kotlin's null — and the chat's mood stands.
      // ignore: no_default_cases
      default:
        break;
    }

    // Kotlin sets Focused while a turn is out, then reads the reply's tone.
    final awaiting = ref.watch(
      chatControllerProvider.select((v) => v.isAwaitingReply),
    );
    if (awaiting) return CompanionState.focused;
    final lastReply = ref.watch(
      chatControllerProvider.select((v) {
        for (var i = v.messages.length - 1; i >= 0; i--) {
          if (!v.messages[i].isUser) return v.messages[i].text;
        }
        return null;
      }),
    );
    return lastReply == null
        ? CompanionState.idle
        : companionStateForMessage(lastReply);
  },
);
