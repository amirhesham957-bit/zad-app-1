/// Kotlin's `SignUpScreen`, in the sign-in's look: a shorter hero with a
/// smaller Zado who greets the customer by name, the same white card, the
/// country picker, and the consent row that opens the consent sheet.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:zad/core/design/components/zad_auth_surfaces.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/auth/presentation/auth_form_parts.dart';
import 'package:zad/features/auth/presentation/auth_hero.dart';
import 'package:zad/features/auth/presentation/consent_sheet.dart';
import 'package:zad/shared/auth/application/auth_controller.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/market/presentation/market_picker_grid.dart';

/// The sign-up half of the login screen.
class SignUpView extends ConsumerStatefulWidget {
  /// Creates the view.
  const new({super.key});

  @override
  ConsumerState<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<SignUpView> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _visible = false;
  bool _terms = false;
  bool _success = false;
  int _hop = 0;

  /// Asked here, not after the first sign-in: the account is created with it
  /// (the provisioning trigger reads it from the metadata), so a slow first
  /// launch can no longer skip the question and leave the account on UTC.
  Market? _market;

  @override
  void initState() {
    super.initState();
    for (final f in <FocusNode>[_nameFocus, _emailFocus, _passwordFocus]) {
      f.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _canSubmit =>
      _email.text.trim().isNotEmpty &&
      _password.text.trim().isNotEmpty &&
      _market != null &&
      _terms;

  Future<void> _submit() async {
    if (!_canSubmit || ref.read(authControllerProvider).submitting) return;
    setState(() => _hop++);
    final controller = ref.read(authControllerProvider.notifier);
    await controller.submit(
      email: _email.text,
      password: _password.text,
      name: _name.text,
      market: _market,
    );
    if (!mounted) return;
    final form = ref.read(authControllerProvider);
    if (form.failure != null || form.submitting) return;
    // Kotlin: the success mark, 1.5 s, then back to sign-in.
    setState(() => _success = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) controller.setMode(AuthMode.signIn);
  }

  Future<void> _showTerms() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final agreed = await showConsentSheet(context);
    if (agreed != null && mounted) setState(() => _terms = agreed);
  }

  Future<void> _pickMarket() async {
    // Closing the sheet hands focus back to whatever had it, and a field that
    // had it brings the keyboard back over the password (emulator, 2026-11-01).
    // The field itself, not the scope: the scope would restore it on pop.
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showModalBottomSheet<Market>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(c).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(c).height * 0.75,
            ),
            child: MarketPickerGrid(
              selected: _market,
              onSelect: (m) => Navigator.of(c).pop(m),
            ),
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _market = picked);
  }

  /// The first word of the name, for Zado's greeting.
  String? get _firstName {
    final words = _name.text.trim().split(RegExp(r'\s+'));
    return words.first.isEmpty ? null : words.first;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final form = ref.watch(authControllerProvider);
    final gaze = _emailFocus.hasFocus
        ? authGazeFor(_email.text.length)
        : _nameFocus.hasFocus
        ? authGazeFor(_name.text.length, rtl: true)
        : Offset.zero;
    final first = _nameFocus.hasFocus ? _firstName : null;

    return AutofillGroup(
      child: AuthHeroShell(
        small: true,
        zado: AuthZado(
          small: true,
          gaze: gaze,
          cover: _passwordFocus.hasFocus,
          hop: _hop,
          bubble: first == null ? null : l.authZadoHello(first),
        ),
        card: <Widget>[
          Text(
            l.authSignUpTitle,
            style: ZadType.titleLarge.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            l.authSignUpSubtitle,
            style: ZadType.bodySmall.copyWith(color: scheme.onSurfaceVariant),
          ),
          AuthField(
            label: l.authName,
            controller: _name,
            focusNode: _nameFocus,
            onChanged: _refresh,
            keyboard: TextInputType.name,
            hints: const <String>[AutofillHints.name],
          ),
          AuthField(
            label: l.authEmail,
            controller: _email,
            focusNode: _emailFocus,
            onChanged: _refresh,
            keyboard: TextInputType.emailAddress,
            hints: const <String>[AutofillHints.email],
            ltr: true,
          ),
          AuthMarketField(
            market: _market,
            onTap: () => unawaited(_pickMarket()),
          ),
          AuthField(
            label: l.authPassword,
            controller: _password,
            focusNode: _passwordFocus,
            onChanged: _refresh,
            obscure: !_visible,
            action: TextInputAction.done,
            hints: const <String>[AutofillHints.newPassword],
            onSubmitted: () => unawaited(_submit()),
            suffix: PasswordToggle(
              visible: _visible,
              onPressed: () => setState(() => _visible = !_visible),
            ),
          ),
          AuthConsentRow(
            agreed: _terms,
            onChanged: (v) => setState(() => _terms = v),
            onOpen: () => unawaited(_showTerms()),
          ),
          if (_success)
            Padding(
              padding: const EdgeInsets.only(top: ZadSpacing.sm),
              child: Column(
                children: <Widget>[
                  Lottie.asset(
                    'assets/lottie/lottie_success_check.json',
                    width: 72,
                    height: 72,
                    repeat: false,
                  ),
                  Text(
                    l.authSignUpDone,
                    style: ZadType.bodyMedium.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (form.failure case final failure?) AuthErrorText(failure: failure),
          const SizedBox(height: ZadSpacing.sm),
          ZadPrimaryButton(
            text: l.authSignUpTitle,
            enabled: _canSubmit,
            loading: form.submitting,
            onPressed: () => unawaited(_submit()),
          ),
          const SizedBox(height: ZadSpacing.sm),
        ],
        footer: AuthSwitchRow(
          question: l.authHaveAccount,
          action: l.authSignInTitle,
          onPressed: () => ref
              .read(authControllerProvider.notifier)
              .setMode(AuthMode.signIn),
        ),
      ),
    );
  }
}
