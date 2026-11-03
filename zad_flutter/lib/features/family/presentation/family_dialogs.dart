/// The family screen's dialogs, Kotlin's one for one: invite (QR, link, code,
/// WhatsApp), join, add a chore, spending limits, a purchase request, a poll,
/// the chat's quick task and quick grocery, and the SOS confirmation.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zad/core/design/components/zad_field_dialog.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/application/family_format.dart';
import 'package:zad/shared/family/application/family_life_controller.dart';
import 'package:zad/shared/family/domain/family.dart';

// ── SOS ────────────────────────────────────────────────────────────────────

/// "تأكيد نداء الطوارئ" — true when the customer sent it.
Future<bool> confirmAndSendSos(BuildContext context, WidgetRef ref) async {
  unawaited(HapticFeedback.heavyImpact());
  final sure = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: Icon(ZadIcons.sos, color: ZadColors.terracottaRust),
      title: Text(context.l10n.familySosConfirmTitle),
      content: Text(context.l10n.familySosConfirmBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ZadColors.terracottaRust,
          ),
          onPressed: () => Navigator.of(c).pop(true),
          child: Text(context.l10n.familySosSend),
        ),
      ],
    ),
  );
  if (!(sure ?? false)) return false;
  return await ref.read(familyLifeControllerProvider.notifier).sendSos();
}

// ── Invite ─────────────────────────────────────────────────────────────────

/// Kotlin's `InviteMemberDialog`.
Future<void> showInviteDialog(BuildContext context, String code) =>
    showDialog<void>(
      context: context,
      builder: (_) => _InviteDialog(code: code),
    );

class _InviteDialog extends StatefulWidget {
  const new({required this.code});

  final String code;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  int _method = 0;
  bool _sent = false;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _flash() {
    setState(() => _sent = true);
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _sent = false);
    });
  }

  String get _shareText =>
      context.l10n.familyInviteShareText(widget.code, inviteLink(widget.code));

  Future<void> _share(String text) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: context.l10n.familyShareInvite),
    );
    if (mounted) _flash();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(ZadIcons.invite, color: ZadColors.green700),
          const SizedBox(width: ZadSpacing.sm),
          Text(context.l10n.familyInviteNew),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: ZadSpacing.xs,
              children: <Widget>[
                for (final (i, label) in <String>[
                  'QR',
                  context.l10n.familyInviteMethodLink,
                  context.l10n.familyInviteMethodCode,
                  context.l10n.familyInviteMethodWhatsapp,
                ].indexed)
                  FilterChip(
                    label: Text(label),
                    selected: _method == i,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _method = i),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.lg),
            ...switch (_method) {
              0 => <Widget>[
                _label(context.l10n.familyInviteScanToJoin),
                const SizedBox(height: ZadSpacing.sm),
                Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(ZadSpacing.sm),
                    child: QrImageView(
                      data: inviteLink(code),
                      size: 180,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: ZadColors.green800,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: ZadColors.green800,
                      ),
                    ),
                  ),
                ),
              ],
              1 => <Widget>[
                _label(context.l10n.familyInviteLinkLabel),
                const SizedBox(height: ZadSpacing.sm),
                Container(
                  padding: const EdgeInsetsDirectional.only(
                    start: ZadSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: ZadColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          inviteLink(code),
                          textDirection: TextDirection.ltr,
                          style: ZadType.labelMedium.copyWith(
                            color: ZadColors.green700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.familyCopy,
                        icon: const Icon(
                          ZadIcons.copy,
                          size: 18,
                          color: ZadColors.green700,
                        ),
                        onPressed: () {
                          unawaited(
                            Clipboard.setData(
                              ClipboardData(text: inviteLink(code)),
                            ),
                          );
                          _flash();
                        },
                      ),
                    ],
                  ),
                ),
              ],
              2 => <Widget>[
                _label(context.l10n.familyInviteCodeColon),
                const SizedBox(height: ZadSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(ZadSpacing.lg),
                  decoration: BoxDecoration(
                    color: ZadColors.green700.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    code,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: ZadType.headlineMedium.copyWith(
                      color: ZadColors.green700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              _ => <Widget>[
                _label(context.l10n.familyInviteShareWhatsapp),
                const SizedBox(height: ZadSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                        ),
                        onPressed: () => unawaited(_share(_shareText)),
                        icon: const Icon(ZadIcons.ask, size: 16),
                        label: Text(context.l10n.familyInviteMethodWhatsapp),
                      ),
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => unawaited(_share(_shareText)),
                        icon: const Icon(ZadIcons.share, size: 16),
                        label: Text(context.l10n.familyInviteAllApps),
                      ),
                    ),
                  ],
                ),
              ],
            },
            const SizedBox(height: ZadSpacing.lg),
            FilledButton.icon(
              onPressed: () => unawaited(
                _share(switch (_method) {
                  0 => context.l10n.familyInviteShareQr(inviteLink(code)),
                  1 => context.l10n.familyInviteShareLink(inviteLink(code)),
                  _ => context.l10n.familyInviteShareCode(code),
                }),
              ),
              icon: const Icon(ZadIcons.share, size: 18),
              label: Text(context.l10n.familyShare),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _sent
                  ? Padding(
                      padding: const EdgeInsets.only(top: ZadSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(
                            ZadIcons.selected,
                            color: ZadColors.green600,
                            size: 20,
                          ),
                          const SizedBox(width: ZadSpacing.xs),
                          Text(
                            context.l10n.commonDone,
                            style: ZadType.labelMedium.copyWith(
                              color: ZadColors.green700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonDone),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
    text,
    style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
  );
}

// ── Join ───────────────────────────────────────────────────────────────────

/// Kotlin's `JoinFamilyDialog`.
Future<void> showJoinFamilyDialog(
  BuildContext context,
  WidgetRef ref, {
  String initialCode = '',
}) async {
  final picked = await showDialog<(String, String)>(
    context: context,
    builder: (_) => _JoinDialog(initialCode: initialCode),
  );
  if (picked == null) return;
  await ref
      .read(familyControllerProvider.notifier)
      .join(code: picked.$1, alias: picked.$2);
}

class _JoinDialog extends StatefulWidget {
  const new({required this.initialCode});

  final String initialCode;

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode,
  );
  final TextEditingController _alias = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _alias.dispose();
    super.dispose();
  }

  // The code alone is enough (see the family screen's canJoin).
  bool get _ready => _code.text.trim().isNotEmpty;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty || !mounted) return;
    setState(() => _code.text = extractInviteCode(text));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: <Widget>[
        const Icon(ZadIcons.joinFamily, color: ZadColors.green700),
        const SizedBox(width: ZadSpacing.sm),
        Text(context.l10n.familyJoin),
      ],
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _alias,
            decoration: InputDecoration(
              labelText: context.l10n.familyAliasLabel,
              hintText: context.l10n.familyAliasHint,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _code,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.l10n.familyInviteCodeLabel,
              hintText: context.l10n.familyInviteCodeHint,
            ),
            onChanged: (v) {
              final code = extractInviteCode(v);
              if (code != v) {
                _code.value = TextEditingValue(
                  text: code,
                  selection: TextSelection.collapsed(offset: code.length),
                );
              }
              setState(() {});
            },
          ),
          const SizedBox(height: ZadSpacing.md),
          OutlinedButton.icon(
            onPressed: () => unawaited(_paste()),
            icon: const Icon(ZadIcons.copy, size: 18),
            label: Text(context.l10n.familyPasteInvite),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: _ready
            ? () =>
                  Navigator.of(context)
                      .pop((_code.text.trim(), _alias.text.trim()))
            : null,
        child: Text(context.l10n.familyJoin),
      ),
    ],
  );
}

// ── Chores ─────────────────────────────────────────────────────────────────

/// Kotlin's `AddChoreDialog`: title, reward, who, and an optional due date.
Future<void> showAddChoreDialog(
  BuildContext context,
  WidgetRef ref,
  List<FamilyMember> members,
) => showDialog<void>(
  context: context,
  builder: (_) => _AddChoreDialog(members: members),
);

class _AddChoreDialog extends ConsumerStatefulWidget {
  const new({required this.members});

  final List<FamilyMember> members;

  @override
  ConsumerState<_AddChoreDialog> createState() => _AddChoreDialogState();
}

class _AddChoreDialogState extends ConsumerState<_AddChoreDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _reward = TextEditingController();
  late String? _assignee = widget.members.firstOrNull?.id;
  DateTime? _due;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _reward.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final assignee = _assignee;
    if (_title.text.trim().isEmpty || assignee == null) return;
    setState(() => _saving = true);
    final ok = await ref
        .read(familyLifeControllerProvider.notifier)
        .addChore(
          assignedTo: assignee,
          title: _title.text,
          dueDate: _due == null
              ? null
              : '${_due!.year}-${_due!.month.toString().padLeft(2, '0')}-'
                    '${_due!.day.toString().padLeft(2, '0')}',
          reward: parseMoneyInput(_reward.text) ?? 0,
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
    final currency = familyCurrency(ref);
    return AlertDialog(
      title: Text(context.l10n.familyAddTaskTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _title,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.familyTaskNameLabel,
                hintText: context.l10n.familyTaskNameHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.sm),
            TextField(
              controller: _reward,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: currency.isEmpty
                    ? context.l10n.familyReward
                    : context.l10n.familyRewardIn(currency),
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            Text(context.l10n.familyAssignee, style: ZadType.labelMedium),
            const SizedBox(height: ZadSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: RadioGroup<String>(
                  groupValue: _assignee,
                  onChanged: (v) => setState(() => _assignee = v),
                  child: Column(
                    children: <Widget>[
                      for (final m in widget.members)
                        RadioListTile<String>(
                          value: m.id,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(m.alias),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: ZadSpacing.sm),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _due ?? now,
                  firstDate: now.subtract(const Duration(days: 1)),
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _due = picked);
              },
              icon: const Icon(ZadIcons.duration, size: 16),
              label: Text(
                _due == null
                    ? context.l10n.familyDueDateOptional
                    : '${_due!.year}/${_due!.month}/${_due!.day}',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving || _title.text.trim().isEmpty
              ? null
              : () => unawaited(_save()),
          child: Text(context.l10n.commonAdd),
        ),
      ],
    );
  }
}

/// The chat's quick task: title and who, no reward — anyone may set one.
Future<void> showQuickTaskDialog(
  BuildContext context,
  WidgetRef ref,
  List<FamilyMember> members,
  FamilyMember me,
) async {
  var assignee = me.id;
  final result = await showFieldDialog<(String, String)>(
    context: context,
    initial: const <String>[''],
    builder: (c, fields) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(context.l10n.familyAddTaskTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: fields[0],
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.familyTaskNameLabel,
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: assignee,
              decoration: InputDecoration(
                labelText: context.l10n.familyAssignee,
              ),
              items: <DropdownMenuItem<String>>[
                for (final m in members)
                  DropdownMenuItem<String>(value: m.id, child: Text(m.alias)),
              ],
              onChanged: (v) => setState(() => assignee = v ?? assignee),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final title = fields[0].text.trim();
              if (title.isNotEmpty) Navigator.of(c).pop((assignee, title));
            },
            child: Text(context.l10n.commonAdd),
          ),
        ],
      ),
    ),
  );
  if (result == null) return;
  await ref
      .read(familyLifeControllerProvider.notifier)
      .addChore(assignedTo: result.$1, title: result.$2);
}

/// The chat's "نزّلها في التسوق".
Future<void> showQuickGroceryDialog(BuildContext context, WidgetRef ref) async {
  final name = await _askText(
    context,
    title: context.l10n.familyQuickGroceryTitle,
    hint: context.l10n.familyQuickGroceryHint,
    action: context.l10n.commonAdd,
  );
  if (name == null) return;
  await ref.read(familyLifeControllerProvider.notifier).addGrocery(name);
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String hint,
  required String action,
}) async {
  final said = await showFieldDialog<String>(
    context: context,
    initial: const <String>[''],
    builder: (c, fields) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: fields[0],
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(c).pop(fields[0].text.trim()),
          child: Text(action),
        ),
      ],
    ),
  );
  return said == null || said.isEmpty ? null : said;
}

// ── Money ──────────────────────────────────────────────────────────────────

/// Kotlin's purchase-request dialog: what, and how much.
Future<void> showPurchaseRequestDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final currency = familyCurrency(ref);
  final result = await showFieldDialog<(String, double)>(
    context: context,
    initial: const <String>['', ''],
    builder: (c, fields) => AlertDialog(
      title: Text(context.l10n.familyMoneyRequestTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: fields[0],
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.familyMoneyRequestWhat,
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          TextField(
            controller: fields[1],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: currency.isEmpty
                  ? context.l10n.familyMoneyRequestAmount
                  : context.l10n.familyMoneyRequestAmountIn(currency),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final what = fields[0].text.trim();
            final value = parseMoneyInput(fields[1].text);
            if (what.isNotEmpty && value != null) {
              Navigator.of(c).pop((what, value));
            }
          },
          child: Text(context.l10n.familyMoneyRequestSend),
        ),
      ],
    ),
  );
  if (result == null) return;
  await ref
      .read(familyLifeControllerProvider.notifier)
      .requestMoney(result.$1, result.$2);
}

/// Kotlin's `SpendLimitDialog`: daily and weekly caps; empty clears one.
Future<void> showSpendLimitDialog(
  BuildContext context,
  WidgetRef ref,
  FamilyMember member,
) async {
  String initial(double? v) => v == null || v <= 0
      ? ''
      : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');
  final currency = familyCurrency(ref);
  final saved = await showFieldDialog<(double?, double?)>(
    context: context,
    initial: <String>[initial(member.dailyLimit), initial(member.weeklyLimit)],
    builder: (c, fields) => AlertDialog(
      title: Text(context.l10n.familySpendLimitTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            context.l10n.familySpendLimitBody(member.alias),
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: fields[0],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: context.l10n.familyDailyLimitIn(currency),
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          TextField(
            controller: fields[1],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: context.l10n.familyWeeklyLimitIn(currency),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(c).pop((
            parseMoneyInput(fields[0].text),
            parseMoneyInput(fields[1].text),
          )),
          child: Text(context.l10n.commonDone),
        ),
      ],
    ),
  );
  if (saved == null) return;
  await ref
      .read(familyLifeControllerProvider.notifier)
      .setSpendLimits(member, daily: saved.$1, weekly: saved.$2);
}

// ── Poll ───────────────────────────────────────────────────────────────────

/// A question, two to six options (the server's limits), and when it
/// closes — Zad announces the result in the chat then.
Future<void> showPollDialog(BuildContext context, WidgetRef ref) async {
  final result = await showDialog<(String, List<String>, Duration?)>(
    context: context,
    builder: (_) => const _PollDialog(),
  );
  if (result == null) return;
  await ref
      .read(familyLifeControllerProvider.notifier)
      .sendPoll(result.$1, result.$2, closesIn: result.$3);
}

/// The server's poll limits (20261004130000).
const int pollMaxOptions = 6;
const int _pollQuestionMax = 200;
const int _pollOptionMax = 60;

/// When a poll closes on its own: a label and the duration (null = by hand).
List<(String, Duration?)> pollClosings(ZadL10n l10n) => <(String, Duration?)>[
  (l10n.familyPollClosesTomorrow, const Duration(days: 1)),
  (l10n.familyPollClosesTwoDays, const Duration(days: 2)),
  (l10n.familyPollClosesWeek, const Duration(days: 7)),
  (l10n.familyPollClosesByHand, null),
];

class _PollDialog extends StatefulWidget {
  const new();

  @override
  State<_PollDialog> createState() => _PollDialogState();
}

class _PollDialogState extends State<_PollDialog> {
  final TextEditingController _question = TextEditingController();
  final List<TextEditingController> _options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  int _closing = 1;

  @override
  void dispose() {
    _question.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.familyPollTitle),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _question,
            autofocus: true,
            maxLength: _pollQuestionMax,
            decoration: InputDecoration(
              labelText: context.l10n.familyPollQuestion,
              counterText: '',
            ),
          ),
          for (final (i, o) in _options.indexed)
            Padding(
              padding: const EdgeInsets.only(top: ZadSpacing.xs),
              child: TextField(
                controller: o,
                maxLength: _pollOptionMax,
                decoration: InputDecoration(
                  labelText: context.l10n.familyPollOption(i + 1),
                  counterText: '',
                ),
              ),
            ),
          if (_options.length < pollMaxOptions)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () =>
                    setState(() => _options.add(TextEditingController())),
                child: Text(context.l10n.familyPollAddOption),
              ),
            ),
          const SizedBox(height: ZadSpacing.sm),
          Text(context.l10n.familyPollClosesWhen, style: ZadType.labelMedium),
          const SizedBox(height: ZadSpacing.xs),
          Wrap(
            spacing: ZadSpacing.xs,
            runSpacing: ZadSpacing.xs,
            children: <Widget>[
              for (final (i, c) in pollClosings(context.l10n).indexed)
                ChoiceChip(
                  label: Text(c.$1),
                  selected: _closing == i,
                  onSelected: (_) => setState(() => _closing = i),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: () {
          final valid = <String>{
            for (final o in _options)
              if (o.text.trim().isNotEmpty) o.text.trim(),
          }.toList();
          if (_question.text.trim().isNotEmpty && valid.length >= 2) {
            Navigator.of(context).pop((
              _question.text.trim(),
              valid,
              pollClosings(context.l10n)[_closing].$2,
            ));
          }
        },
        child: Text(context.l10n.familyPollSend),
      ),
    ],
  );
}
