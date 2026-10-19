/// «أجّل»: a bank proposal swiped left leaves home for a few hours, on this
/// phone only (ZAD_PLAN ٢.٤). Nothing is sent: the proposal is still waiting
/// on the server and on the proposals screen, and comes back on its own.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';

/// How long a postponed proposal stays off home.
const Duration kProposalSnooze = Duration(hours: 4);

/// Proposal id → when it comes back.
class ProposalSnoozeController extends Notifier<Map<String, DateTime>> {
  static const String _key = 'proposal_snooze';

  @override
  Map<String, DateTime> build() {
    try {
      final raw = ref.read(localStoreProvider).device.get(_key);
      if (raw == null) return const <String, DateTime>{};
      final now = ref.read(nowProvider)();
      return <String, DateTime>{
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          if (DateTime.tryParse(e.value as String) case final until?
              when until.isAfter(now))
            e.key: until,
      };
    } on Object {
      // No store (a test) or a damaged value: nothing is postponed.
      return const <String, DateTime>{};
    }
  }

  /// Takes [id] off home for [kProposalSnooze].
  void snooze(String id) {
    final until = ref.read(nowProvider)().add(kProposalSnooze);
    state = <String, DateTime>{...state, id: until};
    try {
      unawaited(
        ref
            .read(localStoreProvider)
            .device
            .put(
              _key,
              jsonEncode(<String, String>{
                for (final e in state.entries)
                  e.key: e.value.toUtc().toIso8601String(),
              }),
            ),
      );
    } on Object {
      // No store (a test): it holds for this run only.
    }
  }

  /// Whether [id] is off home at [now].
  bool isSnoozed(String id, DateTime now) => state[id]?.isAfter(now) ?? false;
}

/// The postponed proposals.
final proposalSnoozeProvider =
    NotifierProvider<ProposalSnoozeController, Map<String, DateTime>>(
      ProposalSnoozeController.new,
    );
