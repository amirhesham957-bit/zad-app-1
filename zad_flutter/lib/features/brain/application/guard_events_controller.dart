/// "صحة العقل"'s state: the refusals, read when the screen opens.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/features/brain/data/guard_events_repository.dart';
import 'package:zad/features/brain/domain/guard_event.dart';

/// The refusals. Riverpod disposes it when the screen closes, so every open
/// reads the server again.
final guardEventsProvider = FutureProvider<GuardEventsSnapshot>(
  (ref) => ref.watch(guardEventsRepositoryProvider).load(),
);
