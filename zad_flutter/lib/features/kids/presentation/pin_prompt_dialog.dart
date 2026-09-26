/// Kotlin's `PinPromptDialog`: the one PIN for entering and leaving kids
/// mode. The first use sets it (typed twice), after that it is checked, and a
/// wrong guess locks the field for a moment.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/features/kids/application/kids_mode_controller.dart';

/// Asks for the PIN; true once it is set or verified.
Future<bool> showPinPrompt(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => const PinPromptDialog(),
    ) ??
    false;

enum _Stage { verify, setupEnter, setupConfirm }

/// The PIN dialog.
class PinPromptDialog extends ConsumerStatefulWidget {
  /// Creates the dialog.
  const new({super.key});

  @override
  ConsumerState<PinPromptDialog> createState() => _PinPromptDialogState();
}

class _PinPromptDialogState extends ConsumerState<PinPromptDialog> {
  late _Stage _stage = ref.read(kidsModeProvider.notifier).hasPin
      ? _Stage.verify
      : _Stage.setupEnter;
  final TextEditingController _pin = TextEditingController();
  String _first = '';
  String? _error;
  Timer? _poll;
  Duration _lock = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Polls the controller-level delay, as Kotlin does, so guessing stays
    // throttled however often the dialog is reopened.
    _poll = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final left = ref.read(kidsModeProvider.notifier).backoffRemaining;
      if (left != _lock && mounted) setState(() => _lock = left);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    if (_lock > Duration.zero) return;
    final pin = _pin.text;
    if (pin.length < 4) {
      setState(() => _error = 'أدخل 4 أرقام على الأقل');
      return;
    }
    final kids = ref.read(kidsModeProvider.notifier);
    switch (_stage) {
      case _Stage.verify:
        if (kids.verify(pin)) {
          Navigator.of(context).pop(true);
        } else {
          _pin.clear();
          setState(() {
            _error = 'PIN غلط، حاول تاني';
            _lock = kids.backoffRemaining;
          });
        }
      case _Stage.setupEnter:
        _first = pin;
        _pin.clear();
        setState(() {
          _error = null;
          _stage = _Stage.setupConfirm;
        });
      case _Stage.setupConfirm:
        if (pin == _first) {
          kids.setPin(pin);
          Navigator.of(context).pop(true);
        } else {
          _pin.clear();
          _first = '';
          setState(() {
            _error = 'الرقمين مش متطابقين، من الأول';
            _stage = _Stage.setupEnter;
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lock > Duration.zero;
    return AlertDialog(
      title: Text(switch (_stage) {
        _Stage.verify => 'PIN وضع الأطفال',
        _Stage.setupEnter => 'حدّد PIN للخروج من وضع الأطفال',
        _Stage.setupConfirm => 'أكّد الـ PIN',
      }),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_stage != _Stage.verify) ...<Widget>[
            Text(
              'هتحتاجه في كل مرة تحب تخرج من وضع الأطفال على الجهاز ده',
              style: TextStyle(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _pin,
            autofocus: true,
            enabled: !locked,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'PIN',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(_error!, style: TextStyle(color: ZadColors.terracottaRust)),
          ],
          if (locked) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'استنى ثانية وحاول تاني',
              style: TextStyle(color: ZadColors.inkMuted),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: locked ? null : _submit,
          child: const Text('تأكيد'),
        ),
      ],
    );
  }
}
