/// The garden's dialogs: rename a tree, plant one, start a family challenge.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_field_dialog.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/tasbiha/application/tasbiha_controller.dart';
import 'package:zad/shared/tasbiha/domain/tasbiha.dart';

/// Renames [tree].
Future<void> showRenameTreeDialog(
  BuildContext context,
  TasbihaController garden,
  GardenTree tree,
) async {
  final result = await showFieldDialog<String>(
    context: context,
    initial: <String>[tree.treeName],
    builder: (dialogContext, fields) {
      final l = dialogContext.l10n;
      return AlertDialog(
        title: Text(l.tasRenameTitle),
        content: TextField(
          controller: fields[0],
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.tasTreeNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.tasCancel),
          ),
          TextButton(
            onPressed: () {
              final v = fields[0].text.trim();
              if (v.isNotEmpty) Navigator.of(dialogContext).pop(v);
            },
            child: Text(l.tasSave),
          ),
        ],
      );
    },
  );
  if (result != null) await garden.rename(result);
}

/// Plants a new tree.
Future<void> showCreateTreeDialog(
  BuildContext context,
  TasbihaController garden,
) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => const _CreateTreeDialog(),
  );
  if (result != null) await garden.createTree(result);
}

class _CreateTreeDialog extends StatefulWidget {
  const new();

  @override
  State<_CreateTreeDialog> createState() => _CreateTreeDialogState();
}

class _CreateTreeDialogState extends State<_CreateTreeDialog> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.tasNewTree),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.tasNewTreeHint,
            style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _name,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.tasTreeNameLabel,
              hintText: l.tasTreeNameExample,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.tasCancel),
        ),
        TextButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_name.text.trim()),
          child: Text(l.tasAdd),
        ),
      ],
    );
  }
}

/// Starts a family challenge (the admin's).
Future<void> showCreateChallengeDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final result = await showDialog<(String, String?, String, int)>(
    context: context,
    builder: (_) => const _CreateChallengeDialog(),
  );
  if (result == null) return;
  await ref
      .read(tasbihaControllerProvider.notifier)
      .createChallenge(
        title: result.$1,
        description: result.$2,
        challengeType: result.$3,
        targetClicks: result.$4,
      );
}

class _CreateChallengeDialog extends StatefulWidget {
  const new();

  @override
  State<_CreateChallengeDialog> createState() => _CreateChallengeDialogState();
}

class _CreateChallengeDialogState extends State<_CreateChallengeDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _target = TextEditingController(text: '100');
  String _type = 'weekly';

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(
        l.tasNewChallenge,
        style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _title,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.tasChallengeTitleLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _description,
              decoration: InputDecoration(
                labelText: l.tasChallengeDescLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _target,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: l.tasChallengeTargetLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            Row(
              children: <Widget>[
                for (final t in const <String>['weekly', 'monthly'])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: ZadSpacing.sm,
                    ),
                    child: FilterChip(
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                      label: Text(t),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.tasCancel),
        ),
        FilledButton(
          onPressed: _title.text.trim().isEmpty
              ? null
              : () {
                  final d = _description.text.trim();
                  Navigator.of(context).pop((
                    _title.text.trim(),
                    d.isEmpty ? null : d,
                    _type,
                    int.tryParse(_target.text) ?? 100,
                  ));
                },
          child: Text(l.tasSave),
        ),
      ],
    );
  }
}
