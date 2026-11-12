/// The name Zad calls the customer by.
///
/// «أناديك بإيه؟» asks it on the first day and stores it as
/// `zad_customer_profile.preferred_name`; the home greeting kept reading the
/// account's sign-up name instead, so a customer who asked to be called
/// «أبو فهد» was greeted «أهلاً يا SaudiTest» (emulator, 2026-11-12).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/brain/application/memory_controller.dart';
import 'package:zad/shared/profile/application/profile_controller.dart';

/// [preferred] when it says something, else [account], else null.
String? callNameFrom({String? preferred, String? account}) {
  final chosen = preferred?.trim();
  if (chosen != null && chosen.isNotEmpty) return chosen;
  final fallback = account?.trim();
  return fallback == null || fallback.isEmpty ? null : fallback;
}

/// The name to greet the customer with, or null before either is known.
final customerCallNameProvider = Provider<String?>((ref) {
  String? preferred;
  try {
    preferred = ref.watch(
      memoryControllerProvider.select((v) => v.snapshot.profile?.preferredName),
    );
  } on Object {
    preferred = null;
  }
  return callNameFrom(
    preferred: preferred,
    account: ref.watch(profileControllerProvider.select((v) => v.name)),
  );
});
