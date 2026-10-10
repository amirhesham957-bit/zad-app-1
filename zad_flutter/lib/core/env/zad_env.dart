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

  /// The Amazon Associates store id every amazon.sa link carries. Public by
  /// nature (it is in every link); `.env.example`'s value is the default so a
  /// build without it still earns the commission.
  static const String amazonAssociateTag = String.fromEnvironment(
    'AMAZON_ASSOCIATE_TAG',
    defaultValue: 'zad0b-21',
  );

  /// The store id for amazon.eg. Associates is a separate programme per
  /// store: the Saudi id earns nothing on amazon.eg, so Egypt has its own
  /// (owner, 2026-10-10).
  static const String amazonAssociateTagEg = String.fromEnvironment(
    'AMAZON_ASSOCIATE_TAG_EG',
    defaultValue: 'zad04-21',
  );

  /// Where crash reports go (Sentry, org `zad-9u`, project `flutter`). A DSN
  /// is public by design — it ships inside every APK and only lets a client
  /// *send* events — so it defaults here, like the associate tag, and every
  /// build reports without an env.json entry. `SENTRY_DSN=""` turns it off.
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue:
        'https://763634d3af16091f9a83cb8a1e854af2@o4512172184043520'
        '.ingest.us.sentry.io/4512172230443008',
  );

  /// Children's school zones (docs/agent/ZAD_LIVING_BRAIN.md slice 2). On by
  /// default — the sideloaded APK. A Google Play build can pass
  /// `--dart-define=ENABLE_KIDS_GEOFENCING=false` if review asks for it
  /// (owner, 2026-10-03): the app then offers no zones and watches none, and
  /// android/app/build.gradle.kts drops the isMonitoringTool declaration.
  static const bool kidsGeofencing = bool.fromEnvironment(
    'ENABLE_KIDS_GEOFENCING',
    defaultValue: true,
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
