/// The app's strings, by `context.l10n` (ZAD_PLAN ٦.١).
///
/// Use this, not `ZadL10n.of`: a widget drawn without the app's delegates (a
/// test's bare `MaterialApp`, a sheet built for a PDF) gets the Arabic
/// strings instead of a null-check crash, which is what the app showed before
/// it had a second language.
library;

import 'package:flutter/widgets.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';

export 'package:zad/core/l10n/generated/zad_l10n.dart' show ZadL10n;

/// `context.l10n.appTitle`.
extension ZadL10nContext on BuildContext {
  /// The strings for this context's locale; Arabic when no delegate is there.
  ZadL10n get l10n =>
      Localizations.of<ZadL10n>(this, ZadL10n) ??
      lookupZadL10n(const Locale('ar'));
}
