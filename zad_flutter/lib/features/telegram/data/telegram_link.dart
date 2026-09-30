/// Kotlin's Telegram binding data (`SupabaseRepo.generateTelegramBindingCode`,
/// `telegramLinkStatus`, `unlinkTelegram`) and `TelegramLinkPrompt` — when the
/// link sheet and the home banner show.
///
/// The one-time code is the only proof of identity in the flow (EPIC_1_4.md:
/// "a chat_id is never an identity"): the row inserted here binds nothing
/// until the bot fills in `chat_id`/`bound_at`.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// The bot's real username (`getMe`, 2026-07-31). `ZadSmartBot` is only its
/// display name — searching Telegram for it finds nothing.
const String kTelegramBotUsername = 'ZadhApp_bot';

/// Reads and writes `telegram_bindings`.
class TelegramLinkRemote {
  /// Creates the remote.
  const new(this._client);

  final SupabaseClient _client;

  static const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// A fresh 8-character code, valid ten minutes; null on failure.
  Future<String?> generateBindingCode() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final random = Random.secure();
      final code = List<String>.generate(
        8,
        (_) => _codeChars[random.nextInt(_codeChars.length)],
      ).join();
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 600))
          .toIso8601String();
      await _client.from('telegram_bindings').insert(<String, dynamic>{
        'user_id': userId,
        'binding_code': code,
        'code_expires_at': expiresAt,
      });
      return code;
    } on Object catch (e) {
      debugPrint('generateTelegramBindingCode() FAILED: $e');
      return null;
    }
  }

  /// Whether a row with `bound_at` exists. Null when unknown — offline, or
  /// not signed in — so a linked customer opening the app offline is never
  /// asked to link.
  Future<bool?> linkStatus() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final rows = await _client
          .from('telegram_bindings')
          .select('bound_at')
          .eq('user_id', userId);
      return rows.any((r) => r['bound_at'] != null);
    } on Object catch (e) {
      debugPrint('telegramLinkStatus() FAILED: $e');
      return null;
    }
  }

  /// Removes every binding of this account.
  Future<void> unlink() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.from('telegram_bindings').delete().eq('user_id', userId);
    } on Object catch (e) {
      debugPrint('unlinkTelegram() FAILED: $e');
    }
  }
}

/// The remote.
final telegramLinkRemoteProvider = Provider<TelegramLinkRemote>(
  (ref) => TelegramLinkRemote(ref.watch(supabaseClientProvider)),
);

/// Kotlin's `TelegramLinkPrompt`, on the `device` box.
///
/// The sheet shows twice at most, three days apart. The banner stays while
/// the account is not linked, hidden three days at a time. The link status is
/// asked of the server at most every six hours, never on every open.
class TelegramLinkPrompt {
  /// Creates the prompt store.
  const new(this._box, this._now);

  final Box<String> _box;
  final DateTime Function() _now;

  /// Kotlin's `MAX_SHOWS`.
  static const int maxShows = 2;
  static const Duration _reshowAfter = Duration(days: 3);
  static const Duration _statusRecheck = Duration(hours: 6);
  static const Duration _bannerSnooze = Duration(days: 3);

  static const String _timesShown = 'telegram_link_prompt_times_shown';
  static const String _lastShownAt = 'telegram_link_prompt_last_shown_at';
  static const String _linked = 'telegram_link_status_linked';
  static const String _statusAt = 'telegram_link_status_checked_at';
  static const String _bannerHiddenUntil = 'telegram_link_banner_hidden_until';

  int _int(String key) => int.tryParse(_box.get(key) ?? '') ?? 0;
  int get _nowMs => _now().millisecondsSinceEpoch;

  /// Whether the sheet is due.
  bool isDue() {
    final times = _int(_timesShown);
    if (times >= maxShows) return false;
    final last = int.tryParse(_box.get(_lastShownAt) ?? '');
    if (times == 0 || last == null) return true;
    return _nowMs - last >= _reshowAfter.inMilliseconds;
  }

  /// Counted when it actually shows.
  void recordShown() {
    unawaited(_box.put(_timesShown, '${_int(_timesShown) + 1}'));
    unawaited(_box.put(_lastShownAt, '$_nowMs'));
  }

  /// Linked: never ask again.
  void recordLinked() {
    unawaited(_box.put(_timesShown, '$maxShows'));
    recordStatus(linked: true);
  }

  /// The last known status, or null.
  bool? knownStatus() => switch (_box.get(_linked)) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  /// Whether the status should be asked again.
  bool isStatusStale() {
    final at = int.tryParse(_box.get(_statusAt) ?? '');
    return at == null || _nowMs - at >= _statusRecheck.inMilliseconds;
  }

  /// Remembers the status.
  void recordStatus({required bool linked}) {
    unawaited(_box.put(_linked, '$linked'));
    unawaited(_box.put(_statusAt, '$_nowMs'));
  }

  /// Unknown status means no banner — a linked customer is never nagged.
  bool bannerVisible() {
    final hidden = _int(_bannerHiddenUntil);
    return knownStatus() == false && _nowMs >= hidden;
  }

  /// «مش دلوقتي» on the banner: three days.
  void snoozeBanner() => unawaited(
    _box.put(_bannerHiddenUntil, '${_nowMs + _bannerSnooze.inMilliseconds}'),
  );
}

/// The prompt store.
final telegramLinkPromptProvider = Provider<TelegramLinkPrompt>(
  (ref) => TelegramLinkPrompt(
    ref.watch(localStoreProvider).device,
    ref.watch(nowProvider),
  ),
);

/// What home shows: the banner, and whether the sheet is due this session.
@immutable
class TelegramHomeState {
  /// Creates a state.
  const new({required this.bannerVisible, required this.promptDue});

  /// The home banner.
  final bool bannerVisible;

  /// The link sheet, once per session.
  final bool promptDue;
}

/// Kotlin's home `LaunchedEffect`: asks the server only when the sheet is
/// due or the stored status is older than six hours.
class TelegramHomeController extends Notifier<TelegramHomeState> {
  @override
  TelegramHomeState build() {
    final prompt = ref.read(telegramLinkPromptProvider);
    unawaited(Future<void>.microtask(_check));
    return TelegramHomeState(
      bannerVisible: prompt.bannerVisible(),
      promptDue: false,
    );
  }

  Future<void> _check() async {
    final prompt = ref.read(telegramLinkPromptProvider);
    final due = prompt.isDue();
    if (!due && !prompt.isStatusStale()) return;
    final status = await ref.read(telegramLinkRemoteProvider).linkStatus();
    if (!ref.mounted) return;
    var promptDue = false;
    switch (status) {
      case false:
        prompt.recordStatus(linked: false);
        promptDue = due;
      case true:
        prompt.recordLinked();
      case null:
        break;
    }
    state = TelegramHomeState(
      bannerVisible: prompt.bannerVisible(),
      promptDue: promptDue,
    );
  }

  /// The sheet was shown.
  void promptShown() {
    ref.read(telegramLinkPromptProvider).recordShown();
    state = TelegramHomeState(
      bannerVisible: state.bannerVisible,
      promptDue: false,
    );
  }

  /// «مش دلوقتي» on the banner.
  void snoozeBanner() {
    ref.read(telegramLinkPromptProvider).snoozeBanner();
    state = TelegramHomeState(bannerVisible: false, promptDue: state.promptDue);
  }

  /// After the link sheet closes: linked now? Then the banner goes.
  Future<void> recheckAfterSheet() async {
    final status = await ref.read(telegramLinkRemoteProvider).linkStatus();
    if (!ref.mounted || status != true) return;
    ref.read(telegramLinkPromptProvider).recordLinked();
    state = TelegramHomeState(bannerVisible: false, promptDue: state.promptDue);
  }
}

/// Home's Telegram state.
final telegramHomeControllerProvider =
    NotifierProvider<TelegramHomeController, TelegramHomeState>(
      TelegramHomeController.new,
    );
