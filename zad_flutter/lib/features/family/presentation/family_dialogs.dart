/// The family screen's dialogs, Kotlin's one for one: invite (QR, link, code,
/// WhatsApp), join, add a chore, spending limits, a purchase request, a poll,
/// the chat's quick task and quick grocery, and the SOS confirmation.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/application/family_life_controller.dart';
import 'package:zad/features/family/domain/family.dart';

/// An amount with the account's currency.
String familyMoney(double v, String currency) =>
    '${NumberFormat('#,##0.##', 'en').format(v)} $currency'.trim();

/// The account's currency symbol, or empty.
String familyCurrency(WidgetRef ref) => ref.watch(
  budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
);

/// The invite deep link.
String inviteLink(String code) => 'zad://invite?code=$code';

/// Kotlin's `extractInviteCode`: a pasted link or message becomes its code.
String extractInviteCode(String raw) {
  final fromLink = RegExp(r'code=([A-Za-z0-9\-]+)').firstMatch(raw);
  if (fromLink != null) return fromLink.group(1)!.toUpperCase();
  final code = RegExp('ZAD-[A-Za-z0-9]+', caseSensitive: false).firstMatch(raw);
  return (code?.group(0) ?? raw.trim()).toUpperCase();
}

// ── SOS ────────────────────────────────────────────────────────────────────

/// "تأكيد نداء الطوارئ" — true when the customer sent it.
Future<bool> confirmAndSendSos(BuildContext context, WidgetRef ref) async {
  unawaited(HapticFeedback.heavyImpact());
  final sure = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(ZadIcons.sos, color: ZadColors.terracottaRust),
      title: const Text('تأكيد نداء الطوارئ'),
      content: const Text(
        'هيتبعت تنبيه فوري لكل أفراد العائلة إنك محتاج مساعدة. متأكد؟',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ZadColors.terracottaRust,
          ),
          onPressed: () => Navigator.of(c).pop(true),
          child: const Text('أرسل النداء'),
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
      'انضم إلى عائلتي في تطبيق زاد!\nكود الدعوة: ${widget.code}\n'
      'أو افتح الرابط: ${inviteLink(widget.code)}';

  Future<void> _share(String text) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'مشاركة الدعوة'),
    );
    if (mounted) _flash();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    return AlertDialog(
      title: const Row(
        children: <Widget>[
          Icon(ZadIcons.invite, color: ZadColors.green700),
          SizedBox(width: ZadSpacing.sm),
          Text('دعوة أفراد جدد'),
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
                  'رابط',
                  'كود',
                  'واتساب',
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
                _label('مسح الرمز للانضمام:'),
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
                _label('رابط الدعوة:'),
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
                        tooltip: 'انسخ',
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
                _label('كود الدعوة:'),
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
                _label('شارك عبر واتساب:'),
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
                        label: const Text('واتساب'),
                      ),
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => unawaited(_share(_shareText)),
                        icon: const Icon(ZadIcons.share, size: 16),
                        label: const Text('جميع التطبيقات'),
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
                  0 =>
                    'انضم إلى عائلتي في تطبيق زاد! امسح الرمز: '
                        '${inviteLink(code)}',
                  1 =>
                    'انضم إلى عائلتي في تطبيق زاد!\n'
                        'رابط الدعوة: ${inviteLink(code)}',
                  _ => 'انضم إلى عائلتي في تطبيق زاد!\nكود الدعوة: $code',
                }),
              ),
              icon: const Icon(ZadIcons.share, size: 18),
              label: const Text('مشاركة'),
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
                            'تم',
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
          child: const Text('تم'),
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

  bool get _ready =>
      _code.text.trim().isNotEmpty && _alias.text.trim().isNotEmpty;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty || !mounted) return;
    setState(() => _code.text = extractInviteCode(text));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: <Widget>[
        Icon(ZadIcons.joinFamily, color: ZadColors.green700),
        SizedBox(width: ZadSpacing.sm),
        Text('الانضمام للعائلة'),
      ],
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _alias,
            decoration: const InputDecoration(
              labelText: 'اسمك (Alias)',
              hintText: 'مثال: الابن أحمد',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _code,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'كود الدعوة',
              hintText: 'مثال: ZAD-1234',
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
            label: const Text('الصق رابط أو كود الدعوة'),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: _ready
            ? () =>
                  Navigator.of(context)
                      .pop((_code.text.trim(), _alias.text.trim()))
            : null,
        child: const Text('الانضمام للعائلة'),
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
      title: const Text('إضافة مهمة جديدة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم المهمة',
                hintText: 'مثال: ترتيب الغرفة',
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
                    ? 'المكافأة'
                    : 'المكافأة ($currency)',
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            const Text('المكلف بالمهمة:', style: ZadType.labelMedium),
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
                    ? 'تاريخ التسليم (اختياري)'
                    : '${_due!.year}/${_due!.month}/${_due!.day}',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving || _title.text.trim().isEmpty
              ? null
              : () => unawaited(_save()),
          child: const Text('إضافة'),
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
  final title = TextEditingController();
  var assignee = me.id;
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: const Text('إضافة مهمة جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'اسم المهمة'),
            ),
            const SizedBox(height: ZadSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: assignee,
              decoration: const InputDecoration(labelText: 'المكلف بالمهمة:'),
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
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isNotEmpty) {
                Navigator.of(c).pop((assignee, title.text.trim()));
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  if (result == null) return;
  await ref
      .read(familyLifeControllerProvider.notifier)
      .addChore(assignedTo: result.$1, title: result.$2);
}

/// The chat's "نزّلها في التسوق".
Future<void> showQuickGroceryDialog(BuildContext context, WidgetRef ref) async {
  final name = await _askText(
    context,
    title: 'نزّلها في التسوق',
    hint: 'مثلاً: حليب',
    action: 'إضافة',
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
  final text = TextEditingController();
  final said = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: text,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(c).pop(text.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  );
  text.dispose();
  return said == null || said.isEmpty ? null : said;
}

// ── Money ──────────────────────────────────────────────────────────────────

/// Kotlin's purchase-request dialog: what, and how much.
Future<void> showPurchaseRequestDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final what = TextEditingController();
  final amount = TextEditingController();
  final currency = familyCurrency(ref);
  final result = await showDialog<(String, double)>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('طلب مصروف أو مشتريات'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: what,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'ماذا تريد أن تشتري؟'),
          ),
          const SizedBox(height: ZadSpacing.sm),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: currency.isEmpty
                  ? 'المبلغ المطلوب'
                  : 'المبلغ المطلوب ($currency)',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            final value = parseMoneyInput(amount.text);
            if (what.text.trim().isNotEmpty && value != null) {
              Navigator.of(c).pop((what.text.trim(), value));
            }
          },
          child: const Text('إرسال الطلب'),
        ),
      ],
    ),
  );
  what.dispose();
  amount.dispose();
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
  final daily = TextEditingController(text: initial(member.dailyLimit));
  final weekly = TextEditingController(text: initial(member.weeklyLimit));
  final currency = familyCurrency(ref);
  final saved = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('حد الإنفاق'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'حدد أقصى مبلغ يقدر ${member.alias} يصرفه يومياً/أسبوعياً. '
            'اتركه فارغاً لإلغاء الحد.',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: daily,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: 'الحد اليومي ($currency)'),
          ),
          const SizedBox(height: ZadSpacing.sm),
          TextField(
            controller: weekly,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: 'الحد الأسبوعي ($currency)'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: const Text('تم'),
        ),
      ],
    ),
  );
  final d = parseMoneyInput(daily.text);
  final w = parseMoneyInput(weekly.text);
  daily.dispose();
  weekly.dispose();
  if (!(saved ?? false)) return;
  await ref
      .read(familyLifeControllerProvider.notifier)
      .setSpendLimits(member, daily: d, weekly: w);
}

// ── Poll ───────────────────────────────────────────────────────────────────

/// Kotlin's poll dialog: a question and at least two options.
Future<void> showPollDialog(BuildContext context, WidgetRef ref) async {
  final result = await showDialog<(String, List<String>)>(
    context: context,
    builder: (_) => const _PollDialog(),
  );
  if (result == null) return;
  await ref
      .read(familyLifeControllerProvider.notifier)
      .sendPoll(result.$1, result.$2);
}

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
    title: const Text('تصويت عائلي'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _question,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'السؤال'),
          ),
          for (final (i, o) in _options.indexed)
            Padding(
              padding: const EdgeInsets.only(top: ZadSpacing.xs),
              child: TextField(
                controller: o,
                decoration: InputDecoration(labelText: 'خيار ${i + 1}'),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () =>
                  setState(() => _options.add(TextEditingController())),
              child: const Text('+ إضافة خيار'),
            ),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          final valid = <String>[
            for (final o in _options)
              if (o.text.trim().isNotEmpty) o.text.trim(),
          ];
          if (_question.text.trim().isNotEmpty && valid.length >= 2) {
            Navigator.of(context).pop((_question.text.trim(), valid));
          }
        },
        child: const Text('إرسال التصويت'),
      ),
    ],
  );
}
