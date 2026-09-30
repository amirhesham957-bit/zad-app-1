/// Kotlin's ZadQuestionCard: an insight asked as a question with its answers.
/// Shown by Home, the notification center and the stuck bank notifications.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/insights/domain/insight.dart';

/// Kotlin's `ZadQuestionCard` (`ui/widgets/ZadQuestionCard.kt`): a brain
/// question with the answer its `answer_type` asks for.
class ZadQuestionCard extends StatefulWidget {
  /// Creates the card.
  const new({
    required this.insight,
    required this.onAnswer,
    required this.onDismiss,
    this.onOpenCamera,
    super.key,
  });

  /// The question.
  final ZadInsight insight;

  /// Sends an answer.
  final ValueChanged<String> onAnswer;

  /// Puts it off.
  final VoidCallback onDismiss;

  /// A camera question.
  final VoidCallback? onOpenCamera;

  @override
  State<ZadQuestionCard> createState() => _ZadQuestionCardState();
}

class _ZadQuestionCardState extends State<ZadQuestionCard> {
  final TextEditingController _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final insight = widget.insight;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.help_outline, size: 18, color: scheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      insight.title,
                      style: ZadType.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      insight.body,
                      style: ZadType.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: widget.onDismiss,
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._answer(scheme, insight),
        ],
      ),
    );
  }

  List<Widget> _answer(ColorScheme scheme, ZadInsight insight) {
    switch (insight.actionType) {
      case 'yes_no':
        return <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                height: 32,
                child: FilledButton(
                  onPressed: () => widget.onAnswer('أيوة'),
                  child: const Text('أيوة', style: ZadType.labelSmall),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: () => widget.onAnswer('لأ'),
                  child: const Text('لأ', style: ZadType.labelSmall),
                ),
              ),
            ],
          ),
        ];
      case 'camera':
        return <Widget>[
          SizedBox(
            height: 32,
            child: FilledButton.icon(
              onPressed: widget.onOpenCamera,
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('افتح الكاميرا', style: ZadType.labelSmall),
            ),
          ),
        ];
      case 'number':
        return <Widget>[_field(numeric: true)];
      default:
        // An unknown type is still answered, as free text — never a question
        // with no way to respond.
        return <Widget>[_field(numeric: false)];
    }
  }

  Widget _field({required bool numeric}) {
    final valid = numeric
        ? int.tryParse(_value.text) != null
        : _value.text.trim().isNotEmpty;
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: 56,
            child: TextField(
              controller: _value,
              keyboardType: numeric ? TextInputType.number : null,
              inputFormatters: numeric
                  ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
                  : null,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 40,
          child: FilledButton(
            // The theme's minimum is full width, which a Row cannot give.
            style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: numeric && !valid
                ? null
                : () {
                    if (!valid) return;
                    final text = numeric
                        ? int.parse(_value.text).toString()
                        : _value.text;
                    widget.onAnswer(text);
                  },
            child: const Text('إرسال', style: ZadType.labelSmall),
          ),
        ),
      ],
    );
  }
}
