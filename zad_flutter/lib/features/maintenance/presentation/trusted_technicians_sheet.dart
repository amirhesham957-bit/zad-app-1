/// «فنيين بثق فيهم» — حارس الطوارئ المنزلية (ZAD_LIVING_BRAIN.md الشريحة
/// ٤١). Opened from «الصيانة» any time, and from the chat with one tap when
/// a message reads like a home emergency, with that trade first.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_field_dialog.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/household/domain/home_emergency.dart';

/// Opens the sheet; [trade] (a stored value) puts that trade first.
Future<void> showTrustedTechnicians(BuildContext context, {String? trade}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TrustedTechniciansSheet(
        first: trade == null ? null : TechnicianTrade.fromWire(trade),
      ),
    );

/// Puts [first]'s trade on top, keeping the rest in their order.
List<TrustedTechnician> technicianOrder(
  List<TrustedTechnician> all,
  TechnicianTrade? first,
) {
  if (first == null) return all;
  return <TrustedTechnician>[
    ...all.where((t) => t.trade == first),
    ...all.where((t) => t.trade != first),
  ];
}

/// The sheet.
class TrustedTechniciansSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const new({this.first, super.key});

  /// The trade the emergency called for, if any.
  final TechnicianTrade? first;

  @override
  ConsumerState<TrustedTechniciansSheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<TrustedTechniciansSheet> {
  List<TrustedTechnician>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    try {
      if (uid == null) throw StateError('signed out');
      final rows = await client
          .from('zad_trusted_technicians')
          .select('id,name,trade,phone,notes')
          .eq('user_id', uid)
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _items = <TrustedTechnician>[
          for (final r in rows) technicianFromJson(r),
        ];
        _failed = false;
      });
    } on Object catch (e) {
      debugPrint('[technicians] not read: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _call(TrustedTechnician t) async {
    final messenger = ScaffoldMessenger.of(context);
    final phone = t.phone.replaceAll(RegExp('[ -]'), '');
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone))
        .catchError((Object _) => false);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text('اتصل على $phone')));
    }
  }

  Future<void> _delete(TrustedTechnician t) async {
    try {
      await ref
          .read(supabaseClientProvider)
          .from('zad_trusted_technicians')
          .delete()
          .eq('id', t.id);
    } on Object catch (e) {
      debugPrint('[technicians] not deleted: $e');
    }
    await _load();
  }

  Future<void> _add() async {
    final saved = await showFieldDialog<bool>(
      context: context,
      initial: const <String>['', '', ''],
      builder: (context, fields) => _AddTechnicianDialog(
        fields: fields,
        trade: widget.first ?? TechnicianTrade.plumber,
      ),
    );
    if (saved ?? false) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final gas = widget.first == TechnicianTrade.gas;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.lg,
          0,
          ZadSpacing.lg,
          ZadSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'فنيين بثق فيهم',
              style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
            if (gas) ...<Widget>[
              const SizedBox(height: ZadSpacing.sm),
              Text(
                kGasSafetyLine,
                style: ZadType.bodyMedium.copyWith(
                  color: ZadColors.terracottaRust,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: ZadSpacing.md),
            if (items == null && !_failed)
              const Padding(
                padding: EdgeInsets.all(ZadSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_failed)
              const ZadEmptyState(
                icon: ZadIcons.failed,
                title: 'مقدرتش أجيب القايمة',
                message: 'اتأكد من النت وافتحها تاني.',
                tone: ZadEmptyTone.problem,
              )
            else if (items!.isEmpty)
              const ZadEmptyState(
                icon: Icons.handyman_outlined,
                title: 'مفيش فنيين لسه',
                message:
                    'ضيف السباك والكهربائي اللي بتثق فيهم — وقت الطوارئ '
                    'هيبقوا قدامك بنقرة من الشات.',
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final t in technicianOrder(items, widget.first))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.name, style: ZadType.titleMedium),
                        subtitle: Text(
                          <String>[
                            t.trade.label,
                            t.phone,
                            if (t.notes.isNotEmpty) t.notes,
                          ].join(' · '),
                          style: ZadType.bodySmall.copyWith(
                            color: ZadColors.inkMuted,
                          ),
                        ),
                        onLongPress: () => unawaited(_delete(t)),
                        trailing: IconButton.filled(
                          tooltip: 'اتصل بـ${t.name}',
                          onPressed: () => unawaited(_call(t)),
                          icon: const Icon(Icons.call),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: ZadSpacing.md),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => unawaited(_add()),
              icon: const Icon(Icons.add),
              label: const Text('ضيف فني'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTechnicianDialog extends ConsumerStatefulWidget {
  const new({required this.fields, required this.trade});

  /// Name, phone, notes — owned by [showFieldDialog].
  final List<TextEditingController> fields;
  final TechnicianTrade trade;

  @override
  ConsumerState<_AddTechnicianDialog> createState() => _AddState();
}

class _AddState extends ConsumerState<_AddTechnicianDialog> {
  late TechnicianTrade _trade = widget.trade;
  bool _saving = false;
  String? _error;

  TextEditingController get _name => widget.fields[0];
  TextEditingController get _phone => widget.fields[1];
  TextEditingController get _notes => widget.fields[2];

  bool get _valid =>
      _name.text.trim().length >= 2 &&
      kTechnicianPhone.hasMatch(_phone.text.trim());

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('zad_trusted_technicians').insert(<String, dynamic>{
        'user_id': client.auth.currentUser?.id,
        'name': _name.text.trim(),
        'trade': _trade.wire,
        'phone': _phone.text.trim(),
        'notes': _notes.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      debugPrint('[technicians] not saved: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'ماتسجلش — يمكن الرقم ده متسجل قبل كده. جرّب تاني.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'فني جديد',
      style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _name,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'الاسم',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 20,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'الرقم',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          Wrap(
            spacing: ZadSpacing.sm,
            runSpacing: ZadSpacing.xs,
            children: <Widget>[
              for (final t in TechnicianTrade.values)
                FilterChip(
                  selected: _trade == t,
                  onSelected: (_) => setState(() => _trade = t),
                  label: Text(t.label),
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: _notes,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'ملاحظة (اختياري)',
              hintText: 'بييجي بالليل، شاطر في السخانات…',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            Text(
              _error!,
              style: ZadType.bodySmall.copyWith(
                color: ZadColors.terracottaRust,
              ),
            ),
          ],
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: _valid && !_saving ? () => unawaited(_save()) : null,
        child: const Text('حفظ'),
      ),
    ],
  );
}
