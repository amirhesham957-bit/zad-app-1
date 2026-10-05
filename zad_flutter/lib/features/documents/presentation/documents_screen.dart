/// «مستنداتي» — حارس المستندات (ZAD_LIVING_BRAIN.md الشريحة ٣٢): الجواز
/// والبطاقة والإقامة والرخص، الأقرب للانتهاء الأول، كل واحد بحالته (منتهي،
/// قرب، تمام)، وزرار + يضيف. المخزّن النوع وصاحبه وتاريخ الانتهاء بس — مفيش
/// خانة لرقم المستند أصلاً. بعد كل تغيير التذكيرات على الموبايل بتتظبط من جديد.
/// Rows live in `zad_documents`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_field_dialog.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/documents/domain/important_document.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

/// Opens the screen.
Future<void> showDocumentsScreen(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const DocumentsScreen()));

const Color _warning = Color(0xFFD97706);

/// The screen.
class DocumentsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsState();
}

class _DocumentsState extends ConsumerState<DocumentsScreen> {
  List<ImportantDocument> _docs = const <ImportantDocument>[];
  bool _loading = true;

  /// Today in the account's market zone, not the device's.
  DateTime get _today {
    final t = tz.TZDateTime.from(
      ref.read(nowProvider)().toUtc(),
      tz.getLocation(ref.read(accountTimeZoneProvider)),
    );
    return DateTime(t.year, t.month, t.day);
  }

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  static List<ImportantDocument> _read(List<Map<String, dynamic>> rows) =>
      <ImportantDocument>[for (final r in rows) ?ImportantDocument.fromRow(r)];

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final cache = ref.read(screenCacheProvider);
    // Last time's list first; the server's answer replaces it.
    if (_loading) {
      if (cache.read('documents', userId) case final cached?) {
        setState(() {
          _docs = _read(cached);
          _loading = false;
        });
      }
    }
    try {
      final rows = await client
          .from('zad_documents')
          .select('id,kind,holder,label,expires_on')
          .eq('user_id', userId);
      unawaited(cache.write('documents', userId, rows));
      if (!mounted) return;
      setState(() {
        _docs = _read(rows);
        _loading = false;
      });
    } on Object catch (e) {
      debugPrint('documents read failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The server's rows, then the phone's reminders from them.
  Future<void> _afterChange() async {
    await _load();
    try {
      await ref.read(localRemindersProvider).syncDocuments(_docs);
    } on Object catch (e) {
      debugPrint('document reminders failed: $e');
    }
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _edit([ImportantDocument? doc]) async {
    final draft = await _showDocumentDialog(context, doc, _today);
    if (draft == null) return;
    final client = ref.read(supabaseClientProvider);
    final values = <String, dynamic>{
      'kind': draft.kind.wire,
      'holder': draft.holder,
      'label': draft.kind == DocumentKind.other ? draft.label : '',
      'expires_on': draft.expiresOnIso,
    };
    try {
      if (doc == null) {
        // Same (kind, holder, name) again is a renewal, not a second one.
        await client.from('zad_documents').upsert(<String, dynamic>{
          ...values,
          'user_id': client.auth.currentUser?.id,
        }, onConflict: 'user_id,kind,holder,label');
      } else {
        await client.from('zad_documents').update(values).eq('id', doc.id);
      }
      unawaited(HapticFeedback.lightImpact());
    } on Object catch (e) {
      debugPrint('document save failed: $e');
      _say(
        doc != null
            ? 'ماتحفظش — يمكن فيه مستند بنفس النوع والاسم، أو النت مقطوع.'
            : 'ماتحفظش — اتأكد من النت.',
      );
    }
    await _afterChange();
  }

  Future<void> _delete(ImportantDocument doc) async {
    setState(() {
      _docs = <ImportantDocument>[
        for (final d in _docs)
          if (d.id != doc.id) d,
      ];
    });
    try {
      await ref
          .read(supabaseClientProvider)
          .from('zad_documents')
          .delete()
          .eq('id', doc.id);
    } on Object catch (e) {
      debugPrint('document delete failed: $e');
      _say('ماتشالش — اتأكد من النت.');
    }
    await _afterChange();
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final sorted = _docs.toList()
      ..sort((a, b) => a.expiresOn.compareTo(b.expiresOn));
    final due = sorted.where((d) => d.stageOn(today) != null).length;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('مستنداتي')),
        floatingActionButton: FloatingActionButton(
          tooltip: 'إضافة مستند',
          onPressed: () => unawaited(_edit()),
          child: const Icon(ZadIcons.add),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.lg,
              ZadSpacing.md,
              ZadSpacing.lg,
              120,
            ),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(ZadIcons.privacy, size: 16, color: ZadColors.inkMuted),
                  const SizedBox(width: ZadSpacing.sm),
                  Expanded(
                    child: Text(
                      'زاد بيحفظ نوع المستند وتاريخ انتهائه بس — من غير '
                      'رقم ولا صورة — ويفكّرك قبلها.',
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
              if (due > 0) ...<Widget>[
                const SizedBox(height: ZadSpacing.md),
                Text(
                  due == 1
                      ? 'مستند واحد محتاج تجديد قريب'
                      : '$due مستندات محتاجة تجديد قريب',
                  style: ZadType.titleSmall.copyWith(
                    color: ZadColors.terracottaRust,
                  ),
                ),
              ],
              const SizedBox(height: ZadSpacing.md),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (sorted.isEmpty)
                const ZadEmptyState(
                  icon: ZadIcons.document,
                  title: 'مفيش مستندات متسجلة',
                  message:
                      'ضيف الجواز أو البطاقة أو الرخصة بتاريخ انتهائها، وزاد '
                      'يفكّرك قبلها بوقت كفاية للتجديد. أو قول لزاد في الشات: '
                      '«جوازي بينتهي ١٥ مارس ٢٠٢٧».',
                )
              else
                for (final (i, doc) in sorted.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ZadSpacing.md),
                    child:
                        _DocumentCard(
                              doc: doc,
                              today: today,
                              onEdit: () => unawaited(_edit(doc)),
                              onDelete: () => unawaited(_delete(doc)),
                            )
                            .animate(delay: (i * 40).clamp(0, 400).ms)
                            .fadeIn(duration: ZadDuration.enter)
                            .moveY(begin: 8, curve: ZadCurves.standard),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The colour and words for where a document stands on [today].
(Color, String) documentStatus(ImportantDocument doc, DateTime today) {
  final left = doc.daysLeft(today);
  if (left < 0) return (ZadColors.terracottaRust, 'منتهي من ${-left} يوم');
  if (left == 0) return (ZadColors.terracottaRust, 'بينتهي النهارده');
  final stage = doc.stageOn(today);
  if (stage != null && stage <= 7) {
    return (ZadColors.terracottaRust, 'خلال $left يوم');
  }
  if (stage != null) return (_warning, 'خلال $left يوم');
  return (ZadColors.green700, 'ساري');
}

class _DocumentCard extends StatelessWidget {
  const new({
    required this.doc,
    required this.today,
    required this.onEdit,
    required this.onDelete,
  });

  final ImportantDocument doc;
  final DateTime today;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (color, status) = documentStatus(doc, today);
    return Material(
      color: ZadColors.surface,
      borderRadius: BorderRadius.circular(ZadRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZadRadii.card),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.lg,
            ZadSpacing.md,
            ZadSpacing.sm,
            ZadSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(ZadIcons.document, color: color),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      doc.holder.isEmpty
                          ? doc.title
                          : '${doc.title} — ${doc.holder}',
                      style: ZadType.titleSmall,
                    ),
                    const SizedBox(height: ZadSpacing.xs),
                    Text(
                      'بينتهي ${doc.expiresOnIso}',
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZadSpacing.sm,
                  vertical: ZadSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ZadRadii.pill),
                ),
                child: Text(
                  status,
                  style: ZadType.labelSmall.copyWith(color: color),
                ),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: onDelete,
                icon: Icon(ZadIcons.delete, color: ZadColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The add/edit dialog: the kind, whose, a name for an «other», and the
/// expiry from a date picker. No field for the number, on purpose.
Future<ImportantDocument?> _showDocumentDialog(
  BuildContext context,
  ImportantDocument? doc,
  DateTime today,
) => showFieldDialog<ImportantDocument>(
  context: context,
  initial: <String>[doc?.holder ?? '', doc?.label ?? ''],
  builder: (context, fields) =>
      _DocumentDialog(doc: doc, today: today, fields: fields),
);

/// The kind and the date live in this State, not in the dialog's builder:
/// the builder runs again when the keyboard opens, and would reset them.
class _DocumentDialog extends StatefulWidget {
  const new({required this.doc, required this.today, required this.fields});

  final ImportantDocument? doc;
  final DateTime today;

  /// [0] whose, [1] the name of an «other» — owned by showFieldDialog.
  final List<TextEditingController> fields;

  @override
  State<_DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends State<_DocumentDialog> {
  late DocumentKind _kind = widget.doc?.kind ?? DocumentKind.passport;
  late DateTime? _expires = widget.doc?.expiresOn;
  bool _missing = false;

  TextEditingController get _holder => widget.fields[0];
  TextEditingController get _label => widget.fields[1];

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: const OutlineInputBorder(),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expires ?? widget.today.add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'تاريخ الانتهاء',
    );
    if (picked != null && mounted) setState(() => _expires = picked);
  }

  void _save() {
    final label = _label.text.trim();
    final date = _expires;
    if (date == null || (_kind == DocumentKind.other && label.isEmpty)) {
      setState(() => _missing = true);
      return;
    }
    Navigator.of(context).pop(
      ImportantDocument(
        id: widget.doc?.id ?? '',
        kind: _kind,
        holder: _holder.text.trim(),
        label: _kind == DocumentKind.other ? label : '',
        expiresOn: DateTime.utc(date.year, date.month, date.day),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expires = _expires;
    return AlertDialog(
      title: Text(
        widget.doc == null ? 'إضافة مستند' : 'تعديل المستند',
        style: ZadType.titleLarge,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.xs,
              children: <Widget>[
                for (final k in DocumentKind.values)
                  ChoiceChip(
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                    label: Text(k.label),
                  ),
              ],
            ),
            if (_kind == DocumentKind.other) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              TextField(
                controller: _label,
                maxLength: 40,
                decoration: _deco('اسم المستند', hint: 'كارنيه النادي'),
              ),
            ],
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _holder,
              maxLength: 40,
              decoration: _deco('لمين؟', hint: 'فاضي لو بتاعك'),
            ),
            const SizedBox(height: ZadSpacing.sm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.event),
              label: Text(
                expires == null ? 'تاريخ الانتهاء' : 'بينتهي ${_iso(expires)}',
              ),
              onPressed: () => unawaited(_pickDate()),
            ),
            if (_missing)
              Padding(
                padding: const EdgeInsets.only(top: ZadSpacing.sm),
                child: Text(
                  _kind == DocumentKind.other && _label.text.trim().isEmpty
                      ? 'اكتب اسم المستند واختار تاريخ انتهائه.'
                      : 'اختار تاريخ الانتهاء.',
                  style: ZadType.bodySmall.copyWith(
                    color: ZadColors.terracottaRust,
                  ),
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
          style: FilledButton.styleFrom(shape: const StadiumBorder()),
          onPressed: _save,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

String _iso(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
