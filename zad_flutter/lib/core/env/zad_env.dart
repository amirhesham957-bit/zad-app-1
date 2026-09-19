/// Compile-time configuration.
///
/// Everything here is a `const` read from `--dart-define`, normally supplied in
/// bulk with `--dart-define-from-file=env.json`. Nothing is read from a file at
/// runtime, and `env.json` is gitignored, so no value reaches the repo:
///
/// ```sh
/// flutter run --dart-define-from-file=env.json
/// ```
///
/// ```json
/// { "SUPABASE_URL": "https://…supabase.co", "SUPABASE_ANON_KEY": "eyJ…" }
/// ```
///
/// The anon key is meant to be shipped in the app — RLS, not secrecy, is what
/// protects the data. It is kept out of the repo because rotating a key that is
/// committed means rewriting history, not because possessing it grants
/// anything.
library;

/// The build's configuration.
abstract final class ZadEnv {
  /// The Supabase project URL.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The Supabase anon key.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Whether both values were supplied at build time.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Throws unless the build was configured.
  ///
  /// This fails at startup on purpose. An unconfigured build that starts anyway
  /// looks like a working offline app until the first sync silently never
  /// happens.
  static void requireConfigured() {
    if (isConfigured) return;
    throw StateError(
      'SUPABASE_URL and SUPABASE_ANON_KEY were not set at build time. '
      'Pass --dart-define-from-file=env.json (see lib/core/env/zad_env.dart).',
    );
  }
}
