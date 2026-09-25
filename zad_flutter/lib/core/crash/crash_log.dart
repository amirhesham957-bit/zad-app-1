/// Kotlin's `ZadCrashLog`: the last 20 crashes, kept on the phone and sent
/// nowhere unless the user shares them from the support screen. No crash
/// service — "your privacy first" rules out automatic reports.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

/// The crash log, in the `device` box (it survives sign-out, like Kotlin's
/// SharedPreferences file).
class CrashLog {
  /// Wraps the device box.
  const new(this._box);

  final Box<String> _box;

  static const String _countKey = 'crash_count';
  static const String _prefix = 'crash_';
  static const int _max = 20;

  /// Records one failure. Never throws: a failing crash handler would hide
  /// the crash it was recording.
  void record(Object error, StackTrace? stack) {
    try {
      final count = int.tryParse(_box.get(_countKey) ?? '') ?? 0;
      final now = DateTime.now().toIso8601String().substring(0, 19);
      final trace = (stack ?? StackTrace.empty).toString();
      final entry =
          '${now.replaceFirst('T', ' ')}\n${error.runtimeType}: $error\n'
          '${trace.length > 3000 ? trace.substring(0, 3000) : trace}';
      unawaited(_box.put('$_prefix${count % _max}', entry));
      unawaited(_box.put(_countKey, '${count + 1}'));
    } on Object catch (e) {
      debugPrint('CrashLog.record failed: $e');
    }
  }

  /// Everything, as one text to show or share.
  String exportAll() {
    final count = int.tryParse(_box.get(_countKey) ?? '') ?? 0;
    if (count == 0) return 'لا توجد أعطال مسجلة ✅';
    final out = StringBuffer('=== سجل أعطال زاد ===\n\n');
    for (var i = 0; i < (count < _max ? count : _max); i++) {
      final entry = _box.get('$_prefix$i');
      if (entry != null) out.write('$entry\n\n———\n\n');
    }
    return out.toString();
  }

  /// Forgets every entry.
  Future<void> clear() async {
    await _box.delete(_countKey);
    for (var i = 0; i < _max; i++) {
      await _box.delete('$_prefix$i');
    }
  }

  /// Sends framework and uncaught async errors here, keeping the handlers
  /// that were already installed.
  void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exception, details.stack);
      previous?.call(details);
    };
    final dispatcher = PlatformDispatcher.instance;
    final previousAsync = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      record(error, stack);
      return previousAsync?.call(error, stack) ?? false;
    };
  }
}
