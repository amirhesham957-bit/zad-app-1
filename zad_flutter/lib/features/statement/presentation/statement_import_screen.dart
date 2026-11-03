/// Kotlin's `StatementImportScreen`: three steps — pick a CSV, map its columns
/// by hand, then tick the rows to import. Nothing is written before the
/// review, and a row already recorded (same amount, direction, day and a
/// fitting description) is skipped and counted.
///
/// A PDF or a photo of the statement skips the mapping: the server reads it
/// (`analyze_statement`) and the rows land in the same review, with a row the
/// statement's own balance disagrees with left unticked (ZAD_PLAN ٣.٣).
library;

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/statement/data/statement_reader.dart';
import 'package:zad/features/statement/domain/statement_import.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/quota/domain/server_refusal.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/data/merchant_categories.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// Opens the import.
Future<void> showStatementImportScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const StatementImportScreen()),
    );

/// A statement file the screen opens on, instead of asking for one.
typedef StatementFile = ({String name, Uint8List bytes});

/// Larger than this is not a statement a phone should upload in one go.
const int _maxScanBytes = 10 * 1024 * 1024;

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// The import.
class StatementImportScreen extends ConsumerStatefulWidget {
  /// Creates the screen; with [initialFile], it reads that file at once.
  const new({super.key, this.initialFile});

  /// A file shared to Zad from another app.
  final StatementFile? initialFile;

  @override
  ConsumerState<StatementImportScreen> createState() =>
      _StatementImportScreenState();
}

class _StatementImportScreenState extends ConsumerState<StatementImportScreen> {
  int _step = 0;
  CsvTable? _table;
  int? _date;
  int? _title;
  int? _amount;
  int? _category;
  bool _invert = false;
  List<PreviewRow> _rows = const <PreviewRow>[];
  Set<int> _checked = <int>{};
  bool _importing = false;
  bool _reading = false;
  String? _error;
  ScannedStatement? _scanned;

  @override
  void initState() {
    super.initState();
    final file = widget.initialFile;
    if (file == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open(file.name, file.bytes));
    });
  }

  Future<void> _pick() async {
    setState(() => _error = null);
    // The picker throws on a second tap while it is open (Android's
    // `already_active`) or when the system refuses; that was uncaught.
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile();
    } on Object {
      if (mounted) setState(() => _error = _unreadableFile);
      return;
    }
    if (file == null || !mounted) return;
    final Uint8List bytes;
    try {
      bytes = await file.xFile.readAsBytes();
    } on Object {
      if (mounted) setState(() => _error = _unreadableFile);
      return;
    }
    if (mounted) await _open(file.name, bytes);
  }

  String get _unreadableFile => context.l10n.statementUnreadableFile;

  Future<void> _open(String name, Uint8List bytes) async {
    switch (statementFileKind(name)) {
      case StatementFileKind.csv:
        _openCsv(bytes);
      case StatementFileKind.pdf || StatementFileKind.image:
        await _scan(name, bytes);
      case null:
        setState(() => _error = _unreadableFile);
    }
  }

  void _openCsv(Uint8List bytes) {
    CsvTable? table;
    try {
      table = readCsv(utf8.decode(bytes, allowMalformed: true));
    } on Object {
      table = null;
    }
    if (table != null && table.headers.isNotEmpty) {
      setState(() {
        _scanned = null;
        _table = table;
        _date = _title = _amount = _category = null;
        _step = 1;
      });
    } else {
      setState(() => _error = _unreadableFile);
    }
  }

  Future<void> _scan(String name, Uint8List bytes) async {
    if (bytes.length > _maxScanBytes) {
      setState(() => _error = context.l10n.statementTooBig);
      return;
    }
    final userId = ref.read(signedInUserIdProvider)() ?? '';
    final l10n = context.l10n;
    setState(() {
      _error = null;
      _reading = true;
    });
    String? error;
    ScannedStatement? scanned;
    try {
      final json = await ref
          .read(statementReaderProvider)
          .read(
            userId: userId,
            bytes: bytes,
            mimeType: statementMimeType(name),
          );
      scanned = json == null
          ? null
          : readScannedStatement(
              json,
              customCategory: ref.read(merchantCategoriesProvider).categoryFor,
            );
      if (scanned == null) {
        error = l10n.statementNoRows;
      }
    } on Object catch (e) {
      error = serverRefusal(e, l10n)?.message ?? l10n.statementServerDown;
    }
    if (!mounted) return;
    setState(() {
      _reading = false;
      _error = error;
      if (scanned != null) {
        _scanned = scanned;
        _rows = scanned.rows;
        // A row the statement's balance disagrees with waits for a tick.
        _checked = <int>{
          for (final r in scanned.rows)
            if (r.balanceOk != false) r.rowIndex,
        };
        _step = 2;
      }
    });
  }

  void _preview() {
    final custom = ref.read(merchantCategoriesProvider);
    final rows = buildPreview(_table!, (
      date: _date!,
      title: _title!,
      amount: _amount!,
      category: _category,
      invertSign: _invert,
    ), customCategory: custom.categoryFor);
    setState(() {
      _rows = rows;
      _checked = <int>{
        for (final r in rows)
          if (!r.hasError) r.rowIndex,
      };
      _step = 2;
    });
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    final repo = ref.read(transactionsRepositoryProvider);
    final userId = ref.read(signedInUserIdProvider)() ?? '';
    final existing = repo.allCached();
    final source = _scanned == null ? 'csv_import' : 'statement_scan';
    var imported = 0;
    var skipped = 0;
    for (final row in _rows.where((r) => _checked.contains(r.rowIndex))) {
      final amount = row.amount;
      final date = row.date;
      if (row.hasError || amount == null || date == null) continue;
      if (existing.any((tx) => isDuplicateOf(tx, row))) {
        skipped++;
        continue;
      }
      final at = DateTime.utc(date.year, date.month, date.day);
      await repo.record(
        (id) => row.isExpense
            ? ZadTransaction.expense(
                id: id,
                userId: userId,
                amount: amount,
                title: row.title,
                createdAt: at,
                wallet: Wallet.card,
                category: row.category,
                sourceType: source,
              )
            : ZadTransaction.income(
                id: id,
                userId: userId,
                amount: amount,
                title: row.title,
                createdAt: at,
                wallet: Wallet.card,
                category: row.category,
                sourceType: source,
              ),
      );
      imported++;
    }
    ref.read(transactionsControllerProvider.notifier).reloadFromCache();
    ref.read(budgetControllerProvider.notifier).recomputePending();
    if (!mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.statementImported(imported, skipped)),
      ),
    );
    setState(() {
      _importing = false;
      _step = 0;
      _table = null;
      _scanned = null;
      _rows = const <PreviewRow>[];
    });
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: ZadColors.canvas),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(context.l10n.statementTitle)),
      body: switch (_step) {
        0 => _PickStep(error: _error, reading: _reading, onPick: _pick),
        1 => _MappingStep(
          headers: _table!.headers,
          date: _date,
          title: _title,
          amount: _amount,
          category: _category,
          invert: _invert,
          onDate: (v) => setState(() => _date = v),
          onTitle: (v) => setState(() => _title = v),
          onAmount: (v) => setState(() => _amount = v),
          onCategory: (v) => setState(() => _category = v),
          onInvert: (v) => setState(() => _invert = v),
          onConfirm: _preview,
        ),
        _ => _PreviewStep(
          scanned: _scanned,
          rows: _rows,
          checked: _checked,
          importing: _importing,
          onToggle: (i) => setState(
            () => _checked.contains(i) ? _checked.remove(i) : _checked.add(i),
          ),
          onImport: () => unawaited(_import()),
        ),
      },
    ),
  );
}

class _PickStep extends StatelessWidget {
  const new({required this.error, required this.reading, required this.onPick});

  final String? error;
  final bool reading;
  final Future<void> Function() onPick;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(ZadSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.upload_file, size: 56, color: ZadColors.green700),
          const SizedBox(height: ZadSpacing.lg),
          Text(
            context.l10n.statementIntro,
            textAlign: TextAlign.center,
            style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: 20),
          if (error case final message?) ...<Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: ZadType.bodySmall.copyWith(
                color: ZadColors.terracottaRust,
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
          ],
          if (reading) ...<Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: ZadSpacing.md),
            Text(
              context.l10n.statementReading,
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
          ] else
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: () => unawaited(onPick()),
              child: Text(context.l10n.statementPick),
            ),
        ],
      ),
    ),
  );
}

class _MappingStep extends StatelessWidget {
  const new({
    required this.headers,
    required this.date,
    required this.title,
    required this.amount,
    required this.category,
    required this.invert,
    required this.onDate,
    required this.onTitle,
    required this.onAmount,
    required this.onCategory,
    required this.onInvert,
    required this.onConfirm,
  });

  final List<String> headers;
  final int? date;
  final int? title;
  final int? amount;
  final int? category;
  final bool invert;
  final ValueChanged<int> onDate;
  final ValueChanged<int> onTitle;
  final ValueChanged<int> onAmount;
  final ValueChanged<int> onCategory;
  final ValueChanged<bool> onInvert;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.statementMapHint,
          style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.lg),
        _ColumnPicker(context.l10n.statementColDate, headers, date, onDate),
        const SizedBox(height: ZadSpacing.md),
        _ColumnPicker(context.l10n.statementColTitle, headers, title, onTitle),
        const SizedBox(height: ZadSpacing.md),
        _ColumnPicker(
          context.l10n.statementColAmount,
          headers,
          amount,
          onAmount,
        ),
        const SizedBox(height: ZadSpacing.md),
        _ColumnPicker(
          context.l10n.statementColCategory,
          headers,
          category,
          onCategory,
          optional: true,
        ),
        const SizedBox(height: ZadSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                context.l10n.statementInvert,
                style: ZadType.bodyMedium,
              ),
            ),
            Switch(value: invert, onChanged: onInvert),
          ],
        ),
        const Spacer(),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: const StadiumBorder(),
          ),
          onPressed: date != null && title != null && amount != null
              ? onConfirm
              : null,
          child: Text(context.l10n.statementContinue),
        ),
      ],
    ),
  );
}

class _ColumnPicker extends StatelessWidget {
  const new(
    this.label,
    this.headers,
    this.selected,
    this.onSelect, {
    this.optional = false,
  });

  final String label;
  final List<String> headers;
  final int? selected;
  final ValueChanged<int> onSelect;
  final bool optional;

  @override
  Widget build(BuildContext context) => DropdownMenu<int>(
    expandedInsets: EdgeInsets.zero,
    label: Text(label),
    initialSelection: selected,
    hintText: optional ? context.l10n.statementNone : null,
    onSelected: (v) => v == null ? null : onSelect(v),
    dropdownMenuEntries: <DropdownMenuEntry<int>>[
      for (final (i, h) in headers.indexed)
        DropdownMenuEntry<int>(
          value: i,
          label: h.trim().isEmpty ? context.l10n.statementColumnN(i + 1) : h,
        ),
    ],
  );
}

class _PreviewStep extends StatelessWidget {
  const new({
    required this.scanned,
    required this.rows,
    required this.checked,
    required this.importing,
    required this.onToggle,
    required this.onImport,
  });

  final ScannedStatement? scanned;
  final List<PreviewRow> rows;
  final Set<int> checked;
  final bool importing;
  final ValueChanged<int> onToggle;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: ZadSpacing.sm,
        ),
        child: Text(
          context.l10n.statementRowsSummary(rows.length, checked.length),
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        ),
      ),
      if (scanned case final s?) _CheckBanner(scanned: s),
      Expanded(
        child: rows.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xxl),
                child: ZadEmptyState(
                  icon: Icons.description,
                  title: context.l10n.statementEmptyTitle,
                  message: context.l10n.statementEmptyMessage,
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  ZadSpacing.lg,
                  0,
                  ZadSpacing.lg,
                  ZadSpacing.sm,
                ),
                itemCount: rows.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: ZadSpacing.sm),
                itemBuilder: (context, i) => _RowCard(
                  row: rows[i],
                  checked: checked.contains(rows[i].rowIndex),
                  onToggle: onToggle,
                ),
              ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            onPressed: checked.isNotEmpty && !importing ? onImport : null,
            child: Text(context.l10n.statementImportCount(checked.length)),
          ),
        ),
      ),
    ],
  );
}

class _RowCard extends StatelessWidget {
  const new({required this.row, required this.checked, required this.onToggle});

  final PreviewRow row;
  final bool checked;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final amount = row.amount;
    final date = row.date;
    final tone = row.isExpense ? ZadColors.terracottaRust : ZadColors.green600;
    return ZadCard(
      color: row.hasError
          ? ZadColors.terracottaRust.withValues(alpha: 0.06)
          : ZadColors.surface,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: <Widget>[
          Checkbox(
            value: checked,
            onChanged: row.hasError ? null : (_) => onToggle(row.rowIndex),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  row.hasError || date == null
                      ? context.l10n.statementRowError
                      : '${DateFormat('yyyy-MM-dd', 'en').format(date)} · '
                            '${row.category}',
                  style: ZadType.labelSmall.copyWith(
                    color: row.hasError
                        ? ZadColors.terracottaRust
                        : ZadColors.inkMuted,
                  ),
                ),
                if (row.balanceOk == false)
                  Text(
                    context.l10n.statementRowMismatch,
                    style: ZadType.labelSmall.copyWith(
                      color: ZadColors.terracottaRust,
                    ),
                  ),
              ],
            ),
          ),
          if (amount != null)
            Text(
              '${row.isExpense ? '-' : '+'}${_money(amount)}',
              style: ZadType.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
        ],
      ),
    );
  }
}

/// What the statement's own balance said, in one line above the rows.
class _CheckBanner extends StatelessWidget {
  const new({required this.scanned});

  final ScannedStatement scanned;

  @override
  Widget build(BuildContext context) {
    final (icon, tone, text) = switch (scanned.check) {
      StatementCheck.balanced => (
        Icons.verified_outlined,
        ZadColors.green600,
        context.l10n.statementBalanced,
      ),
      StatementCheck.mismatch => (
        Icons.error_outline,
        ZadColors.terracottaRust,
        context.l10n.statementMismatch,
      ),
      StatementCheck.unknown => (
        Icons.info_outline,
        ZadColors.inkMuted,
        context.l10n.statementUnknown,
      ),
    };
    final dropped = scanned.dropped;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZadSpacing.lg,
        0,
        ZadSpacing.lg,
        ZadSpacing.sm,
      ),
      child: ZadCard(
        color: tone.withValues(alpha: 0.08),
        padding: const EdgeInsets.all(ZadSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(icon, color: tone),
            const SizedBox(width: ZadSpacing.sm),
            Expanded(
              child: Text(
                dropped > 0
                    ? context.l10n.statementDropped(text, dropped)
                    : text,
                style: ZadType.bodySmall.copyWith(color: tone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
