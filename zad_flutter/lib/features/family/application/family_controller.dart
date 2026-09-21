/// The family screen's state.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/family/data/family_repository.dart';
import 'package:zad/features/family/domain/family.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';

/// What the screen draws.
class FamilyView {
  /// Creates a view.
  const new({
    required this.status,
    required this.userId,
    this.isBusy = false,
    this.failure,
  });

  /// What the device knows.
  final FamilyStatus status;

  /// The signed-in account, to find its own row.
  final String userId;

  /// Whether a change is in flight.
  final bool isBusy;

  /// Why the last change did not happen.
  final FamilyFailure? failure;

  /// The family, when there is one.
  Family? get family => switch (status) {
    InFamily(:final family) => family,
    _ => null,
  };

  /// Whether the signed-in account runs the family.
  bool get isAdmin => family?.isAdmin(userId) ?? false;

  /// A copy with the given fields replaced.
  FamilyView copyWith({
    FamilyStatus? status,
    bool? isBusy,
    FamilyFailure? failure,
    bool clearFailure = false,
  }) => FamilyView(
    status: status ?? this.status,
    userId: userId,
    isBusy: isBusy ?? this.isBusy,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Holds the family and changes it.
class FamilyController extends Notifier<FamilyView> {
  @override
  FamilyView build() {
    final repo = ref.read(familyRepositoryProvider);
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return FamilyView(
      status: repo.cached(),
      userId: ref.read(signedInUserIdProvider)() ?? '',
    );
  }

  /// Reads the membership again. Keeps what is on screen if that fails.
  Future<void> refresh() async {
    try {
      final status = await ref.read(familyRepositoryProvider).refresh();
      if (ref.mounted) state = state.copyWith(status: status);
    } on Object {
      // The cached family stays: a dead network never empties the screen.
    }
  }

  /// Starts a family.
  Future<bool> create({String? alias}) => _change(
    () => ref.read(familyRepositoryProvider).create(alias: alias),
    householdChanged: true,
  );

  /// Joins one by code.
  Future<bool> join({required String code, String? alias}) => _change(
    () => ref.read(familyRepositoryProvider).join(code: code, alias: alias),
    householdChanged: true,
  );

  /// Leaves it.
  Future<bool> leave() => _change(
    () => ref.read(familyRepositoryProvider).leave(),
    householdChanged: true,
  );

  /// Changes a member's role.
  Future<bool> setRole(FamilyMember member, FamilyRole role) =>
      _change(() => ref.read(familyRepositoryProvider).setRole(member, role));

  /// Removes a member.
  Future<bool> remove(FamilyMember member) =>
      _change(() => ref.read(familyRepositoryProvider).remove(member));

  /// Mints a new invite code.
  Future<bool> rotateInviteCode() =>
      _change(() => ref.read(familyRepositoryProvider).rotateInviteCode());

  Future<bool> _change(
    Future<Object?> Function() action, {
    bool householdChanged = false,
  }) async {
    if (state.isBusy) return false;
    state = state.copyWith(isBusy: true, clearFailure: true);
    try {
      await action();
      if (!ref.mounted) return true;
      state = state.copyWith(
        status: ref.read(familyRepositoryProvider).cached(),
        isBusy: false,
      );
      if (householdChanged) {
        // The pantry and the shopping list are shared with the family, so
        // joining or leaving changes which rows this account sees.
        ref
          ..invalidate(pantryControllerProvider)
          ..invalidate(shoppingControllerProvider);
      }
      return true;
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          isBusy: false,
          failure: FamilyRepository.failureOf(e),
        );
      }
      return false;
    }
  }
}

/// The family.
final familyControllerProvider = NotifierProvider<FamilyController, FamilyView>(
  FamilyController.new,
);
