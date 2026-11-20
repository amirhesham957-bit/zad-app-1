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
import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/statement/data/statement_reader.dart';
import 'package:zad/features/statement/domain/statement_import.dart';
import 'package:zad/features/statement/domain/statement_months.dart';
import 'package:zad/features/statement/presentation/statement_breakdown.dart';
import 'package:zad/features/statement/presentation/statement_preview.dart';
import 'package:zad/features/statement/presentation/statement_steps.dart';
import 'package:zad/features/statement/presentation/statement_world_scene.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/quota/domain/server_refusal.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/data/merchant_categories.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the import.
Future<void> showStatementImportScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const StatementImportScreen()),
    );

/// A statement file the screen opens on, instead of asking for one.
typedef StatementFile = ({String name, Uint8List bytes});

/// Larger than this is not a statement a phone should upload in one go.
const int _maxScanBytes = 10 * 1024 * 1024;

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

class _StatementImportScreenState extends ConsumerState<StatementImportScreen>
    with SingleTickerProviderStateMixin {
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
  // Counts statements the AI read, so each scan gets a fresh ad.
  int _scans = 0;

  /// The scene's curve draws itself once, on arriving.
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _drawStarted = false;

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

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

  static const String _unreadableFile =
      'تعذّرت قراءة الملف — ابعت ملف CSV أو PDF أو صورة للكشف';

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
      setState(
        () => _error =
            'الملف أكبر من ١٠ ميجا — ابعت الكشف شهر شهر أو صوّر الصفحات',
      );
      return;
    }
    final userId = ref.read(signedInUserIdProvider)() ?? '';
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
        error =
            'ما لقيتش حركات أقدر أقراها في الكشف ده — جرّب صورة أوضح أو '
            'ملف PDF من تطبيق البنك';
      }
    } on Object catch (e) {
      error =
          serverRefusal(e)?.message ??
          'مقدرتش أوصل للسيرفر — اتأكد من النت وجرّب تاني';
    }
    if (!mounted) return;
    setState(() {
      _reading = false;
      _error = error;
      if (scanned != null) {
        _scanned = scanned;
        _scans++;
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
        content: Text('تم استيراد $imported معاملة، تجاهل $skipped مكررة'),
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
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (!_drawStarted) {
      _drawStarted = true;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _draw.value = 1;
      } else {
        _draw.forward();
      }
    }
    // The curve, the state line and the breakdown are read from the rows the
    // controller holds, so they redraw when an import lands.
    final all = ref.watch(transactionsControllerProvider).rows;
    final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    final now = ref.read(nowProvider)();
    final months = monthlyTotals(all, zone, now);
    final peak = months.fold<double>(0, (m, t) => t.spent > m ? t.spent : m);
    final series = <double>[
      if (peak > 0)
        for (final m in months) m.spent / peak,
    ];
    final pace = spendingPaceChange(all, zone, now);
    final pct = pace == null ? 0 : (pace.abs() * 100).round();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ZadWorldScaffold(
        world: ZadWorld.stmt,
        eyebrow: DateFormat.MMMM(l.localeName).format(now),
        title: l.worldLabelStmt,
        stateLine: switch (pace) {
          null => l.statementWorldStateNone,
          _ when pct == 0 => l.statementWorldStateSame,
          final p when p < 0 => l.statementWorldStateLess(pct),
          _ => l.statementWorldStateMore(pct),
        },
        scene: (loop) => StatementWorldScene(loop, _draw, series),
        zado: ZadWorldZado(
          left: 24,
          top: 56,
          size: 130,
          state: _reading ? CompanionState.focused : CompanionState.happy,
        ),
        // The import button docks under the review, in the thumb zone, so it
        // never covers a row.
        dockHeight: _step == 2 ? 88 : 0,
        overlay: _step == 2
            ? Positioned(
                left: ZadSpacing.gutter,
                right: ZadSpacing.gutter,
                bottom: ZadSpacing.md,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: ZadWorldColors.statement,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _checked.isNotEmpty && !_importing
                      ? () => unawaited(_import())
                      : null,
                  child: Text('استيراد ${_checked.length} معاملة'),
                ),
              )
            : null,
        slivers: switch (_step) {
          0 => <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.gutter,
                ZadSpacing.md,
                ZadSpacing.gutter,
                0,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  StatementPickCard(
                    error: _error,
                    reading: _reading,
                    onPick: _pick,
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  StatementBreakdown(month: monthBreakdown(all, zone, now)),
                ],
              ),
            ),
          ],
          1 => <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.gutter,
                ZadSpacing.md,
                ZadSpacing.gutter,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: StatementMappingCard(
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
              ),
            ),
          ],
          _ => statementPreviewSlivers(
            context,
            scanned: _scanned,
            scans: _scans,
            rows: _rows,
            checked: _checked,
            onToggle: (i) => setState(
              () => _checked.contains(i) ? _checked.remove(i) : _checked.add(i),
            ),
          ),
        },
      ),
    );
  }
}
