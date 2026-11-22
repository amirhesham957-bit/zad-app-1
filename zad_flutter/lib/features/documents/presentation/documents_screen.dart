/// «مستنداتي» — حارس المستندات (ZAD_LIVING_BRAIN.md الشريحة ٣٢): الجواز
/// والبطاقة والإقامة والرخص، الأقرب للانتهاء الأول، كل واحد بحالته (منتهي،
/// قرب، تمام)، وزرار + يضيف. المخزّن النوع وصاحبه وتاريخ الانتهاء بس — مفيش
/// خانة لرقم المستند أصلاً. بعد كل تغيير التذكيرات على الموبايل بتتظبط من جديد.
/// Rows live in `zad_documents`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/local/screen_cache.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_field_dialog.dart';
import 'package:zad/core/design/components/zad_scroll_away.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/documents/presentation/documents_scene.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/documents/domain/important_document.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

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
    final l = context.l10n;
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
      _say(doc != null ? l.docsSaveFailedEdit : l.docsSaveFailedAdd);
    }
    await _afterChange();
  }

  Future<void> _delete(ImportantDocument doc) async {
    final l = context.l10n;
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
      _say(l.docsDeleteFailed);
    }
    await _afterChange();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: DocumentsWorld(
      docs: _docs,
      loading: _loading,
      today: _today,
      onRefresh: _load,
      onAdd: () => unawaited(_edit()),
      onEdit: (d) => unawaited(_edit(d)),
      onDelete: (d) => unawaited(_delete(d)),
    ),
  );
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

ZadIconArt _art(DocumentKind k) => switch (k) {
  DocumentKind.passport => ZadIconArt.passport,
  DocumentKind.nationalId || DocumentKind.residence => ZadIconArt.idcard,
  DocumentKind.drivingLicense || DocumentKind.vehicleLicense => ZadIconArt.car,
  DocumentKind.other => ZadIconArt.folder,
};

String _name(ImportantDocument d) =>
    d.holder.isEmpty ? d.title : '${d.title} — ${d.holder}';

/// The world: the nearest expiry on top, every document one row of a calm
/// card, add docked in the thumb zone.
class DocumentsWorld extends StatelessWidget {
  /// Creates the world over [docs].
  const new({
    required this.docs,
    required this.loading,
    required this.today,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  /// Every document, any order.
  final List<ImportantDocument> docs;

  /// The first answer has not come.
  final bool loading;

  /// Today in the account's zone.
  final DateTime today;

  /// Pull-to-refresh.
  final Future<void> Function() onRefresh;

  /// The add button.
  final VoidCallback onAdd;

  /// A row's tap: edit (rename, date).
  final void Function(ImportantDocument) onEdit;

  /// A row's delete.
  final void Function(ImportantDocument) onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sorted = docs.toList()
      ..sort((a, b) => a.expiresOn.compareTo(b.expiresOn));
    final due = sorted.where((d) => d.stageOn(today) != null).length;
    final nearest = sorted.firstOrNull;
    return ZadScrollAwayScope(
      child: ZadWorldScaffold(
        world: ZadWorld.docs,
        eyebrow: sorted.isEmpty ? null : l.docsEyebrowCount(sorted.length),
        title: l.worldLabelDocs,
        stateLine: nearest == null
            ? l.docsStateEmpty
            : l.docsStateNearest(
                _name(nearest),
                documentStatus(nearest, today).$2,
              ),
        scene: (loop) => DocumentsWorldScene(loop, urgent: due > 0),
        zado: const ZadWorldZado(left: 30, top: 50, state: CompanionState.idle),
        onRefresh: onRefresh,
        dockHeight: 80,
        overlay: Positioned(
          right: ZadSpacing.lg,
          bottom: ZadSpacing.md,
          child: ZadStepsAside(
            child: FloatingActionButton.extended(
              heroTag: 'documents-add',
              tooltip: l.docsAdd,
              onPressed: onAdd,
              icon: const Icon(ZadIcons.add),
              label: Text(l.docsAdd),
            ),
          ),
        ),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.gutter,
              ZadSpacing.md,
              ZadSpacing.gutter,
              0,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(ZadIcons.privacy, size: 16, color: ZadColors.inkMuted),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: Text(
                        l.docsPrivacy,
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
                    due == 1 ? l.docsDueOne : l.docsDueMany(due),
                    style: ZadType.titleSmall.copyWith(
                      color: ZadColors.terracottaRust,
                    ),
                  ),
                ],
                const SizedBox(height: ZadSpacing.md),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (sorted.isEmpty)
                  ZadEmptyState(
                    icon: ZadIcons.document,
                    title: l.docsEmptyTitle,
                    message: l.docsEmptyMessage,
                  )
                else
                  ZadWorldCard(
                    child: Column(
                      children: <Widget>[
                        for (final (i, doc) in sorted.indexed) ...<Widget>[
                          if (i > 0) const ZadWorldDivider(),
                          _row(l, doc),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(ZadL10n l, ImportantDocument doc) {
    final (color, status) = documentStatus(doc, today);
    return ZadWorldRow(
      leading: ZadWorldTile(
        color: color,
        child: ZadArt.icon(_art(doc.kind), size: 30),
      ),
      title: _name(doc),
      subtitle: '${l.docsExpires(doc.expiresOnIso)} · $status',
      stateColor: color,
      onTap: () => onEdit(doc),
      trailing: IconButton(
        tooltip: l.docsDelete,
        onPressed: () => onDelete(doc),
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
        icon: Icon(ZadIcons.delete, color: ZadColors.inkMuted),
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
