/// Kotlin's `LoginScreen` and `SignUpScreen` (`ui/screens/auth/`), on the
/// auth canvas (`ZadAuthBackground`): brand mark, form, «دخول» / «إنشاء
/// حساب», the forgot-password dialog and the terms dialog — Kotlin's text,
/// sizes and colours. Submitting goes through the existing auth controller.
///
/// Kotlin's language toggle beside «تسجيل الدخول» is not here: this client
/// has no second language to switch to yet.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_appear.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/tokens/zad_extended_colors.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/auth/application/auth_controller.dart';
import 'package:zad/features/auth/presentation/terms_content.dart';
import 'package:zad/features/market/domain/market.dart';
import 'package:zad/features/market/presentation/market_picker_grid.dart';

/// The way in: Kotlin's two screens, one at a time.
class LoginScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(authControllerProvider.select((f) => f.mode));
    return Scaffold(
      body: ZadAuthBackground(
        child: SafeArea(
          child: mode == AuthMode.signUp
              ? const _SignUpView()
              : const _SignInView(),
        ),
      ),
    );
  }
}

/// Kotlin's `ZadAuthBackground`: the canvas with a warm wash top-start and a
/// cool one bottom-end.
class ZadAuthBackground extends StatelessWidget {
  /// Creates the background.
  const new({required this.child, super.key});

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = context.zadExt;
    return LayoutBuilder(
      builder: (context, c) {
        final r = (c.maxWidth > c.maxHeight ? c.maxWidth : c.maxHeight) * 0.9;
        RadialGradient wash(Color color, double x, double y) => RadialGradient(
          center: Alignment(x * 2 - 1, y * 2 - 1),
          radius: r / (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight),
          colors: <Color>[color.withValues(alpha: 0.55), Colors.transparent],
        );
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: wash(ext.authWashWarm, 0.15, 0.10),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: wash(ext.authWashCool, 0.85, 0.90),
                  ),
                ),
              ),
              Positioned.fill(child: child),
            ],
          ),
        );
      },
    );
  }
}

/// Kotlin's `ZadPrimaryButton` (`ZadDesignPrimitives.kt`): a 56dp primary
/// pill, white label, elevation 10.
class ZadPrimaryButton extends StatelessWidget {
  /// Creates the button.
  const new({
    required this.text,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
    super.key,
  });

  /// The label.
  final String text;

  /// The action.
  final VoidCallback onPressed;

  /// Whether it can be pressed.
  final bool enabled;

  /// Shows a spinner instead of the label.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ZadPressable(
      onPressed: enabled && !loading ? onPressed : null,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled && !loading ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: primary.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            elevation: 10,
            shape: const StadiumBorder(),
          ),
          child: loading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  text,
                  style: ZadType.titleMedium.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  required Color fill,
  String? hint,
  Widget? suffix,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    filled: true,
    fillColor: fill,
    hintText: hint,
    hintStyle: TextStyle(color: scheme.outline),
    suffixIcon: suffix,
    enabledBorder: border(scheme.outline),
    focusedBorder: border(scheme.primary),
    border: border(scheme.outline),
  );
}

class _BrandMark extends StatelessWidget {
  const new({required this.wordmarkSize, required this.gap});

  final double wordmarkSize;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      SvgPicture.asset(
        'assets/brand/carrot_logo.svg',
        width: 60,
        height: 60,
        semanticsLabel: 'زاد',
      ),
      SizedBox(height: gap),
      Text(
        'ZAD',
        style: TextStyle(
          fontSize: wordmarkSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: context.zadExt.primaryLight,
        ),
      ),
    ],
  );
}

class _SignInView extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends ConsumerState<_SignInView> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _forgot() =>
      showDialog<void>(context: context, builder: (_) => const _ResetDialog());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final form = ref.watch(authControllerProvider);
    final canSubmit =
        _email.text.trim().isNotEmpty && _password.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 64),
          ZadAppearOnEntry(
            child: Column(
              children: <Widget>[
                const _BrandMark(wordmarkSize: 32, gap: 20),
                const SizedBox(height: 10),
                Text(
                  'تدبير ذكي لبيت هادئ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          ZadAppearOnEntry(
            delayMs: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'تسجيل الدخول',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أدخل بريدك الإلكتروني وكلمة المرور',
                  style: ZadType.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          ZadAppearOnEntry(
            delayMs: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'البريد الإلكتروني',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                  decoration: _fieldDecoration(context, fill: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  'كلمة المرور',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _password,
                  obscureText: !_visible,
                  onChanged: (_) => setState(() {}),
                  decoration: _fieldDecoration(
                    context,
                    fill: Colors.white,
                    suffix: IconButton(
                      tooltip: 'إظهار/إخفاء كلمة المرور',
                      onPressed: () => setState(() => _visible = !_visible),
                      icon: Icon(
                        _visible ? Icons.visibility : Icons.visibility_off,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => unawaited(_forgot()),
                    child: Text(
                      'نسيت كلمة المرور؟',
                      style: TextStyle(color: scheme.onSurface, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (form.failure case final failure?)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                failure.message,
                style: ZadType.bodySmall.copyWith(color: scheme.error),
              ),
            ),
          ZadPrimaryButton(
            text: 'دخول',
            enabled: canSubmit,
            loading: form.submitting,
            onPressed: () => unawaited(
              ref
                  .read(authControllerProvider.notifier)
                  .submit(
                    email: _email.text,
                    password: _password.text,
                    name: '',
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'ليس لديك حساب؟ ',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .setMode(AuthMode.signUp),
                  child: Text(
                    'سجل الآن',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetDialog extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends ConsumerState<_ResetDialog> {
  final TextEditingController _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('استعادة كلمة المرور'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'أدخل بريدك الإلكتروني. سنرسل لك رابطاً لاستعادة كلمة المرور.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                border: OutlineInputBorder(),
              ),
            ),
            if (_sent) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'تم إرسال الرابط بنجاح!',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await ref
                  .read(authGatewayProvider)
                  .sendPasswordReset(_email.text.trim());
              if (mounted) setState(() => _sent = true);
            } on Object {
              // Kotlin shows the error on the screen behind; nothing here.
            }
          },
          child: const Text('إرسال'),
        ),
      ],
    );
  }
}

class _SignUpView extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<_SignUpView> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _visible = false;
  bool _terms = false;
  bool _success = false;

  /// Asked here, not after the first sign-in: the account is created with it
  /// (the provisioning trigger reads it from the metadata), so a slow first
  /// launch can no longer skip the question and leave the account on UTC.
  Market? _market;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
    final agreed = await showDialog<bool>(
      context: context,
      builder: (c) {
        final scheme = Theme.of(c).colorScheme;
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                kTermsTitle,
                style: ZadType.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                'Version $kTermsVersion — $kTermsLastUpdated',
                style: ZadType.bodySmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: Text(
                kTermsFullText,
                style: ZadType.bodySmall.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 18 / 13,
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: Text(
                'رفض',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text(
                'موافق ومتابعة',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (agreed != null && mounted) setState(() => _terms = agreed);
  }

  Future<void> _pickMarket() async {
    final picked = await showModalBottomSheet<Market>(
      context: context,
      isScrollControlled: true,
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

  Widget _marketField() {
    final scheme = Theme.of(context).colorScheme;
    final market = _market;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'البلد',
            style: ZadType.labelMedium.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            key: const ValueKey<String>('sign-up-market'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => unawaited(_pickMarket()),
            child: InputDecorator(
              decoration: _fieldDecoration(
                context,
                fill: Colors.transparent,
                hint: '',
                suffix: Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
              ),
              child: Text(
                switch (market) {
                  null => 'اختار بلدك',
                  final m => '${m.flag}  ${m.nameAr} · ${m.currencySymbol}',
                },
                style: TextStyle(
                  color: market == null
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String hint = '',
    bool password = false,
    Widget? suffix,
    TextInputType? keyboard,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: ZadType.labelMedium.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: password,
            keyboardType: keyboard,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: scheme.onSurface),
            decoration: _fieldDecoration(
              context,
              fill: Colors.transparent,
              hint: hint,
              suffix: suffix,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final form = ref.watch(authControllerProvider);
    final canSubmit =
        _email.text.trim().isNotEmpty &&
        _password.text.trim().isNotEmpty &&
        _market != null &&
        _terms;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 48),
          const ZadAppearOnEntry(child: _BrandMark(wordmarkSize: 28, gap: 16)),
          const SizedBox(height: 48),
          ZadAppearOnEntry(
            delayMs: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'إنشاء حساب',
                  style: ZadType.displayMedium.copyWith(
                    fontSize: 28,
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أدخل بياناتك للمتابعة',
                  style: ZadType.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ZadAppearOnEntry(
            delayMs: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _field(
                  label: 'اسم المستخدم',
                  controller: _name,
                  hint: 'محمد أحمد',
                ),
                const SizedBox(height: 16),
                _field(
                  label: 'البريد الإلكتروني',
                  controller: _email,
                  hint: 'your.email@gmail.com',
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _marketField(),
                const SizedBox(height: 16),
                _field(
                  label: 'كلمة المرور',
                  controller: _password,
                  password: !_visible,
                  suffix: IconButton(
                    tooltip: 'إظهار/إخفاء كلمة المرور',
                    onPressed: () => setState(() => _visible = !_visible),
                    icon: Icon(
                      _visible ? Icons.visibility : Icons.visibility_off,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: <Widget>[
                    Checkbox(
                      value: _terms,
                      activeColor: scheme.primary,
                      onChanged: (v) => setState(() => _terms = v ?? false),
                    ),
                    Text(
                      'أوافق على ',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => unawaited(_showTerms()),
                      child: Text(
                        'الشروط وسياسة الخصوصية',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_success)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: <Widget>[
                  Lottie.asset(
                    'assets/lottie/lottie_success_check.json',
                    width: 72,
                    height: 72,
                    repeat: false,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تم التسجيل بنجاح! جاري التوجيه...',
                    style: ZadType.bodyMedium.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (form.failure case final failure?)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                failure.message,
                style: ZadType.bodySmall.copyWith(color: scheme.error),
              ),
            ),
          ZadPrimaryButton(
            text: 'إنشاء حساب',
            enabled: canSubmit,
            loading: form.submitting,
            onPressed: () => unawaited(_submit()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'لديك حساب بالفعل؟ ',
                  style: TextStyle(color: scheme.onSurface, fontSize: 14),
                ),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .setMode(AuthMode.signIn),
                  child: Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
