/// The pieces sign-in and sign-up are built from: a labelled field, the
/// country row, the consent row and the line that switches screens.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/auth/domain/auth_failure.dart';
import 'package:zad/shared/market/domain/market.dart';

const Color _fieldBorder = Color(0xFFE1E4DD);
const double _fieldRadius = 14;

InputDecoration _decoration(BuildContext context, {Widget? suffix}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(_fieldRadius),
    borderSide: BorderSide(color: c, width: 1.5),
  );
  return InputDecoration(
    filled: true,
    fillColor: ZadColors.canvasTop,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: ZadSpacing.md + 2,
      vertical: ZadSpacing.md,
    ),
    suffixIcon: suffix,
    enabledBorder: border(_fieldBorder),
    focusedBorder: border(ZadColors.green600),
    border: border(_fieldBorder),
  );
}

/// A label over a 48dp field.
class AuthField extends StatelessWidget {
  /// Creates the field.
  const new({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.obscure = false,
    this.suffix,
    this.keyboard,
    this.action = TextInputAction.next,
    this.hints = const <String>[],
    this.ltr = false,
    this.onSubmitted,
    super.key,
  });

  /// The label above.
  final String label;

  /// The text.
  final TextEditingController controller;

  /// Focus, which Zado watches.
  final FocusNode focusNode;

  /// Called on every edit.
  final VoidCallback onChanged;

  /// Hides the text.
  final bool obscure;

  /// A button at the end (show / hide).
  final Widget? suffix;

  /// The keyboard.
  final TextInputType? keyboard;

  /// The keyboard's action key.
  final TextInputAction action;

  /// What the autofill service may put here.
  final List<String> hints;

  /// Left to right text (an address).
  final bool ltr;

  /// The action key on the last field.
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: ZadSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: ZadType.labelLarge.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZadSpacing.xs),
          TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscure,
            keyboardType: keyboard,
            textInputAction: action,
            autofillHints: hints,
            autocorrect: false,
            enableSuggestions: !obscure && !ltr,
            textDirection: ltr ? TextDirection.ltr : null,
            onChanged: (_) => onChanged(),
            onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
            style: TextStyle(color: scheme.onSurface),
            decoration: _decoration(context, suffix: suffix),
          ),
        ],
      ),
    );
  }
}

/// The show / hide button at the end of a password field.
class PasswordToggle extends StatelessWidget {
  /// Creates the toggle.
  const new({required this.visible, required this.onPressed, super.key});

  /// Whether the text shows.
  final bool visible;

  /// Flips it.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.authTogglePassword,
    onPressed: onPressed,
    icon: Icon(
      visible ? Icons.visibility : Icons.visibility_off,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

/// The country row: opens the market picker.
class AuthMarketField extends StatelessWidget {
  /// Creates the row.
  const new({required this.market, required this.onTap, super.key});

  /// What was picked.
  final Market? market;

  /// Opens the picker.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = market;
    return Padding(
      padding: const EdgeInsets.only(top: ZadSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.authCountry,
            style: ZadType.labelLarge.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZadSpacing.xs),
          InkWell(
            key: const ValueKey<String>('sign-up-market'),
            borderRadius: BorderRadius.circular(_fieldRadius),
            onTap: onTap,
            child: InputDecorator(
              decoration: _decoration(
                context,
                suffix: Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
              ),
              child: Text(
                m == null
                    ? context.l10n.authPickCountry
                    : '${m.flag}  ${m.nameAr} · ${m.currencySymbol}',
                style: TextStyle(
                  color: m == null ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The checkbox, «أوافق على» and the link that opens the consent sheet.
class AuthConsentRow extends StatelessWidget {
  /// Creates the row.
  const new({
    required this.agreed,
    required this.onChanged,
    required this.onOpen,
    super.key,
  });

  /// Whether the terms were accepted.
  final bool agreed;

  /// The box was toggled.
  final ValueChanged<bool> onChanged;

  /// The link was tapped.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: ZadSpacing.sm),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Semantics(
            label: context.l10n.authTermsLink,
            child: Checkbox(
              value: agreed,
              activeColor: ZadColors.forestEmerald,
              side: const BorderSide(color: Color(0xFFB9C0B8), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
              onChanged: (v) => onChanged(v ?? false),
            ),
          ),
          Text(
            context.l10n.authAgreeTo,
            style: ZadType.bodySmall.copyWith(color: scheme.onSurfaceVariant),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
            ),
            onPressed: onOpen,
            child: Text(
              context.l10n.authTermsLink,
              style: ZadType.bodySmall.copyWith(
                color: ZadColors.forestEmerald,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A failure in words, above the button.
class AuthErrorText extends StatelessWidget {
  /// Creates the text.
  const new({required this.failure, super.key});

  /// What went wrong.
  final AuthFailure failure;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: ZadSpacing.sm),
    child: Text(
      failure.localized(context.l10n),
      style: ZadType.bodySmall.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}

/// «ليس لديك حساب؟ سجل الآن» / «لديك حساب بالفعل؟ تسجيل الدخول».
class AuthSwitchRow extends StatelessWidget {
  /// Creates the row.
  const new({
    required this.question,
    required this.action,
    required this.onPressed,
    super.key,
  });

  /// The question.
  final String question;

  /// The button's label.
  final String action;

  /// Switches screen.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            question,
            style: ZadType.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
            ),
            onPressed: onPressed,
            child: Text(
              action,
              style: ZadType.bodyMedium.copyWith(
                color: ZadColors.forestEmerald,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
