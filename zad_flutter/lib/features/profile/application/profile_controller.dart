/// The profile: the customer's name and picture, the analysis consent, and
/// the account's deletion — Kotlin's `ProfileScreen` state.
///
/// The name and picture live in `zad_users` (`name`, `avatar_uri`), the
/// picture itself in the `avatars` bucket at `<user id>/avatar.jpg`, as Kotlin
/// writes them. Each change is online and read back; the last answer is kept
/// on the device so the header draws at once.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/auth/application/session_controller.dart';

/// What the profile screen draws.
class ProfileView {
  /// Creates a view.
  const new({
    this.name,
    this.avatarUrl,
    this.email = '',
    this.shortId = '',
    this.isUploading = false,
    this.behaviorConsent = false,
  });

  /// What the customer is called; null until they say.
  final String? name;

  /// The picture's public address.
  final String? avatarUrl;

  /// The sign-in email.
  final String email;

  /// Kotlin's `#ZAD-` id: the account id's first eight characters.
  final String shortId;

  /// Whether a picture is on its way up.
  final bool isUploading;

  /// PDPL: whether the customer agreed to behaviour analysis.
  final bool behaviorConsent;

  /// The name to show, falling back to the email's local part.
  String get displayName {
    final n = name?.trim() ?? '';
    if (n.isNotEmpty) return n;
    final local = email.split('@').first;
    if (local.isEmpty) return 'مستخدم جديد';
    return local[0].toUpperCase() + local.substring(1);
  }

  /// A copy with the given fields replaced.
  ProfileView copyWith({
    String? name,
    String? avatarUrl,
    bool? isUploading,
    bool? behaviorConsent,
  }) => ProfileView(
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    email: email,
    shortId: shortId,
    isUploading: isUploading ?? this.isUploading,
    behaviorConsent: behaviorConsent ?? this.behaviorConsent,
  );
}

/// Holds the profile and changes it.
class ProfileController extends Notifier<ProfileView> {
  static const String _cacheKey = 'profile';
  static const String _consentKey = 'behavior_consent_given';

  SupabaseClient get _client => ref.read(supabaseClientProvider);

  @override
  ProfileView build() {
    ref.watch(sessionControllerProvider);
    final user = _client.auth.currentUser;
    final box = ref.read(localStoreProvider).documents;
    var cached = const <String, dynamic>{};
    try {
      final raw = box.get(_cacheKey);
      if (raw != null) {
        cached = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } on Object {
      // A bad cache is no cache.
    }
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return ProfileView(
      name: cached['name'] as String?,
      avatarUrl: cached['avatar_uri'] as String?,
      email: user?.email ?? '',
      shortId: (user?.id ?? '').replaceAll('-', '').take(8).toUpperCase(),
      behaviorConsent: box.get(_consentKey) == 'true',
    );
  }

  /// Reads the name and picture again.
  Future<void> refresh() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await _client
          .from('zad_users')
          .select('name, avatar_uri')
          .eq('id', uid)
          .maybeSingle();
      if (row == null || !ref.mounted) return;
      _remember(row);
      state = state.copyWith(
        name: row['name'] as String?,
        avatarUrl: row['avatar_uri'] as String?,
      );
    } on Object {
      // What is on screen stays.
    }
  }

  void _remember(Map<String, dynamic> row) {
    unawaited(
      ref
          .read(localStoreProvider)
          .documents
          .put(
            _cacheKey,
            jsonEncode(<String, dynamic>{
              'name': row['name'],
              'avatar_uri': row['avatar_uri'],
            }),
          ),
    );
  }

  /// Renames the customer — in the account and in their family, as Kotlin's
  /// edit screen does. True when the server kept it.
  Future<bool> setName(String name) async {
    final uid = _client.auth.currentUser?.id;
    final clean = name.trim();
    if (uid == null || clean.isEmpty) return false;
    try {
      final row = await _client
          .from('zad_users')
          .update(<String, dynamic>{'name': clean})
          .eq('id', uid)
          .select('name, avatar_uri')
          .maybeSingle();
      if (row == null) return false;
      // The family calls them the same. Best effort: no family is fine.
      unawaited(
        _client
            .from('family_members')
            .update(<String, dynamic>{'alias': clean})
            .eq('user_id', uid)
            .then((_) {}, onError: (Object _) {}),
      );
      if (!ref.mounted) return true;
      _remember(row);
      state = state.copyWith(name: row['name'] as String?);
      return true;
    } on Object {
      return false;
    }
  }

  /// Uploads a picture (JPEG bytes) and makes it the profile's.
  Future<bool> setAvatar(Uint8List jpeg) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || state.isUploading) return false;
    state = state.copyWith(isUploading: true);
    try {
      final path = '$uid/avatar.jpg';
      await _client.storage
          .from('avatars')
          .uploadBinary(
            path,
            jpeg,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      // A fresh query string, so no image cache keeps the old picture.
      final url =
          '${_client.storage.from('avatars').getPublicUrl(path)}'
          '?t=${DateTime.now().millisecondsSinceEpoch}';
      final row = await _client
          .from('zad_users')
          .update(<String, dynamic>{'avatar_uri': url})
          .eq('id', uid)
          .select('name, avatar_uri')
          .maybeSingle();
      if (!ref.mounted) return row != null;
      if (row != null) _remember(row);
      state = state.copyWith(
        isUploading: false,
        avatarUrl: row?['avatar_uri'] as String?,
      );
      return row != null;
    } on Object {
      if (ref.mounted) state = state.copyWith(isUploading: false);
      return false;
    }
  }

  /// Records the analysis consent on this device.
  Future<void> setBehaviorConsent({required bool given}) async {
    await ref
        .read(localStoreProvider)
        .documents
        .put(_consentKey, given ? 'true' : 'false');
    if (ref.mounted) state = state.copyWith(behaviorConsent: given);
  }

  /// Deletes the account for good: `delete-account` cleans every table and
  /// the auth user on the server, then this device signs out. True when the
  /// server did it.
  Future<bool> deleteAccount() async {
    try {
      await _client.functions.invoke('delete-account');
    } on Object {
      return false;
    }
    try {
      await ref.read(sessionControllerProvider.notifier).signOut();
    } on Object {
      // The account is gone; a local sign-out that reports an error has
      // still cleared the device.
    }
    return true;
  }
}

extension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}

/// The profile.
final NotifierProvider<ProfileController, ProfileView>
profileControllerProvider = NotifierProvider<ProfileController, ProfileView>(
  ProfileController.new,
);
