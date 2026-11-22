/// M5.2, sharing the housework. An admin asks the server for a distribution
/// (Hungarian over each chore's minutes and each member's week and taste),
/// sees it, and applies it in one go. Every member sets their own minutes a
/// week and the chores they like and dislike; an admin, anyone's.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/family/presentation/chore_inputs.dart';
import 'package:zad/shared/family/application/family_life_controller.dart';
import 'package:zad/shared/family/domain/family.dart';
import 'package:zad/shared/family/domain/family_life.dart';

/// The admin's "وزّع المهام": asks the server, shows the plan, applies it.
Future<void> showChorePlanSheet(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(familyLifeControllerProvider.notifier);
  final plan = await controller.planChores();
  if (plan == null || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) => _ChorePlanSheet(plan: plan),
  );
}

class _ChorePlanSheet extends ConsumerStatefulWidget {
  const new({required this.plan});

  final ChorePlan plan;

  @override
  ConsumerState<_ChorePlanSheet> createState() => _ChorePlanSheetState();
}

class _ChorePlanSheetState extends ConsumerState<_ChorePlanSheet> {
  bool _applying = false;

  Future<void> _apply() async {
    setState(() => _applying = true);
    final ok = await ref
        .read(familyLifeControllerProvider.notifier)
        .applyChorePlan(widget.plan);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.lg,
          0,
          ZadSpacing.lg,
          ZadSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Text(l.chorePlanTitle, style: ZadType.titleMedium),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                l.chorePlanSubtitle,
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.md),
              if (plan.lines.isEmpty)
                ZadEmptyState(
                  icon: ZadIcons.chore,
                  title: l.chorePlanEmptyTitle,
                  message: l.chorePlanEmptyMessage,
                )
              else
                for (final line in plan.lines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 48,
                    leading: const Icon(ZadIcons.chore),
                    title: Text(line.title),
                    subtitle: Text(l.choreMinutesValue(line.minutes)),
                    trailing: Text(line.memberName, style: ZadType.labelLarge),
                  ),
              if (plan.unassigned.isNotEmpty) ...<Widget>[
                const SizedBox(height: ZadSpacing.sm),
                Text(
                  l.choreNoTimeFor(plan.unassigned.join('، ')), // l10n: data
                  style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
                ),
              ],
              if (plan.load.isNotEmpty) ...<Widget>[
                const Divider(height: ZadSpacing.xl),
                for (final (name, minutes, week) in plan.load)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: ZadSpacing.xs,
                    ),
                    child: Text(
                      l.choreLoadLine(name, minutes, week),
                      style: ZadType.bodySmall,
                    ),
                  ),
              ],
              const SizedBox(height: ZadSpacing.lg),
              FilledButton(
                onPressed: _applying || plan.lines.isEmpty
                    ? null
                    : () => unawaited(_apply()),
                child: Text(l.choreApplyPlan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A member's chore time and taste. [members] is everyone the caller may
/// edit: themselves, or the whole family for an admin.
Future<void> showChorePreferenceDialog(
  BuildContext context,
  WidgetRef ref,
  List<FamilyMember> members,
) async {
  if (members.isEmpty) return;
  final prefs = await ref
      .read(familyLifeControllerProvider.notifier)
      .chorePreferences();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _ChorePreferenceDialog(members: members, prefs: prefs),
  );
}

class _ChorePreferenceDialog extends ConsumerStatefulWidget {
  const new({required this.members, required this.prefs});

  final List<FamilyMember> members;
  final Map<String, ChorePreference> prefs;

  @override
  ConsumerState<_ChorePreferenceDialog> createState() =>
      _ChorePreferenceDialogState();
}

class _ChorePreferenceDialogState
    extends ConsumerState<_ChorePreferenceDialog> {
  late String _member = widget.members.first.id;
  final TextEditingController _minutes = TextEditingController();
  final TextEditingController _likes = TextEditingController();
  final TextEditingController _dislikes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final p = widget.prefs[_member] ?? ChorePreference(memberId: _member);
    _minutes.text = '${p.minutesPerWeek}';
    // The same separator [choreTitles] splits on.
    _likes.text = p.likes.join('، '); // l10n: data
    _dislikes.text = p.dislikes.join('، '); // l10n: data
  }

  @override
  void dispose() {
    _minutes.dispose();
    _likes.dispose();
    _dislikes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final minutes = chorePrefMinutes(_minutes.text);
    if (minutes == null) return;
    setState(() => _saving = true);
    final ok = await ref
        .read(familyLifeControllerProvider.notifier)
        .saveChorePreference(
          ChorePreference(
            memberId: _member,
            minutesPerWeek: minutes,
            likes: choreTitles(_likes.text),
            dislikes: choreTitles(_dislikes.text),
          ),
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.chorePrefsTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.members.length > 1) ...<Widget>[
              DropdownButtonFormField<String>(
                initialValue: _member,
                decoration: InputDecoration(labelText: l.chorePrefsMember),
                items: <DropdownMenuItem<String>>[
                  for (final m in widget.members)
                    DropdownMenuItem<String>(value: m.id, child: Text(m.alias)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _member = v;
                    _load();
                  });
                },
              ),
              const SizedBox(height: ZadSpacing.sm),
            ],
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.chorePrefsMinutes,
                helperText: l.chorePrefsMinutesHelper,
              ),
            ),
            const SizedBox(height: ZadSpacing.sm),
            TextField(
              controller: _likes,
              decoration: InputDecoration(
                labelText: l.chorePrefsLikes,
                hintText: l.chorePrefsLikesHint,
              ),
            ),
            const SizedBox(height: ZadSpacing.sm),
            TextField(
              controller: _dislikes,
              decoration: InputDecoration(
                labelText: l.chorePrefsDislikes,
                hintText: l.chorePrefsDislikesHint,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.choreCancel),
        ),
        FilledButton(
          onPressed: _saving || chorePrefMinutes(_minutes.text) == null
              ? null
              : () => unawaited(_save()),
          child: Text(l.choreSave),
        ),
      ],
    );
  }
}
