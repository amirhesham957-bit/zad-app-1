/// Kotlin's `StatementImportScreen`: three steps — pick a CSV, map its columns
/// by hand, then tick the rows to import. Nothing is written before the
/// review, and a row already recorded (same amount, direction, day and a
/// fitting description) is skipped and counted.
library;

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/statement/domain/statement_import.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// Opens the import.
Future<void> showStatementImportScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const StatementImportScreen()),
    );

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// The import.
class StatementImportScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

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
  bool _readFailed = false;

  Future<void> _pick() async {
    setState(() => _readFailed = false);
    final file = await FilePicker.pickFile();
    if (file == null || !mounted) return;
    CsvTable? table;
    try {
      final bytes = await file.xFile.readAsBytes();
      table = readCsv(utf8.decode(bytes, allowMalformed: true));
    } on Object {
      table = null;
    }
    if (!mounted) return;
    if (table != null && table.headers.isNotEmpty) {
      setState(() {
        _table = table;
        _date = _title = _amount = _category = null;
        _step = 1;
      });
    } else {
      setState(() => _readFailed = true);
    }
  }

  void _preview() {
    final rows = buildPreview(_table!, (
      date: _date!,
      title: _title!,
      amount: _amount!,
      category: _category,
      invertSign: _invert,
    ));
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
                sourceType: 'csv_import',
              )
            : ZadTransaction.income(
                id: id,
                userId: userId,
                amount: amount,
                title: row.title,
                createdAt: at,
                wallet: Wallet.card,
                category: row.category,
                sourceType: 'csv_import',
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
        content: Text('تم استيراد $imported معاملة، تجاهل $skipped مكررة'),
      ),
    );
    setState(() {
      _importing = false;
      _step = 0;
      _table = null;
      _rows = const <PreviewRow>[];
    });
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: ZadColors.canvas),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('استيراد كشف حساب')),
      body: switch (_step) {
        0 => _PickStep(readFailed: _readFailed, onPick: _pick),
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
  const new({required this.readFailed, required this.onPick});

  final bool readFailed;
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
            'اختر ملف CSV من كشف حسابك — هتحدد بنفسك أي عمود هو التاريخ '
            'والمبلغ قبل الاستيراد، ومفيش حاجة بتتسجل غير بعد ما تراجعها.',
            textAlign: TextAlign.center,
            style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: 20),
          if (readFailed) ...<Widget>[
            Text(
              'تعذّرت قراءة الملف — تأكد إنه ملف CSV صحيح',
              style: ZadType.bodySmall.copyWith(
                color: ZadColors.terracottaRust,
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
          ],
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: const StadiumBorder(),
            ),
            onPressed: () => unawaited(onPick()),
            child: const Text('اختيار ملف CSV'),
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
          'حدد أي عمود من الملف يمثل كل بيانة — الملف مختلف من بنك لبنك',
          style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.lg),
        _ColumnPicker('عمود التاريخ', headers, date, onDate),
        const SizedBox(height: ZadSpacing.md),
        _ColumnPicker('عمود الوصف/العنوان', headers, title, onTitle),
        const SizedBox(height: ZadSpacing.md),
        _ColumnPicker('عمود المبلغ', headers, amount, onAmount),
        const SizedBox(height: ZadSpacing.md),
        _ColumnPicker(
          'عمود التصنيف (اختياري)',
          headers,
          category,
          onCategory,
          optional: true,
        ),
        const SizedBox(height: ZadSpacing.md),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'اعكس إشارة المبلغ (لو السالب هنا معناه دخل مش مصروف)',
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
          child: const Text('متابعة للمراجعة'),
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
    hintText: optional ? 'بدون' : null,
    onSelected: (v) => v == null ? null : onSelect(v),
    dropdownMenuEntries: <DropdownMenuEntry<int>>[
      for (final (i, h) in headers.indexed)
        DropdownMenuEntry<int>(
          value: i,
          label: h.trim().isEmpty ? 'عمود ${i + 1}' : h,
        ),
    ],
  );
}

class _PreviewStep extends StatelessWidget {
  const new({
    required this.rows,
    required this.checked,
    required this.importing,
    required this.onToggle,
    required this.onImport,
  });

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
          '${rows.length} صف — ${checked.length} محدد للاستيراد',
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        ),
      ),
      Expanded(
        child: rows.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: ZadSpacing.xxl),
                child: ZadEmptyState(
                  icon: Icons.description,
                  title: 'ما لقيتش أي معاملة في الملف',
                  message:
                      'الملف اتقرا لكن مفيهوش صفوف أقدر أستوردها — اتأكد إنه '
                      'كشف حساب وإن صيغته CSV أو PDF مقروء.',
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
            child: Text('استيراد ${checked.length} معاملة'),
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
                      ? 'تعذّرت قراءة التاريخ أو المبلغ في هذا الصف'
                      : '${DateFormat('yyyy-MM-dd', 'en').format(date)} · '
                            '${row.category}',
                  style: ZadType.labelSmall.copyWith(
                    color: row.hasError
                        ? ZadColors.terracottaRust
                        : ZadColors.inkMuted,
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
