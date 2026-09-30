/// Whether the signed-in account still owes Zad its introduction.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/brain/application/memory_controller.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';

/// True when the server has answered and the profile lacks a name, a gender,
/// a household role or who the customer looks after.
///
/// Only on the server's word: before the first successful read, or after a
/// failed one, this is false and the app opens as usual — asking again a
/// customer who has already answered is worse than asking a little late.
/// Never in kids mode: a child on a parent's phone must not fill in the
/// parent's profile.
final needsIntroductionProvider = Provider<bool>((ref) {
  if (ref.watch(kidsModeActiveProvider)) return false;
  final view = ref.watch(memoryControllerProvider);
  if (!view.hasFetched) return false;
  return !(view.snapshot.profile?.isIntroduced ?? false);
});
