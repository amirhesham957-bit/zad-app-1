/// Kotlin's `PriceReportingRoute` (`ui/screens/PriceReportingScreen.kt`):
/// «لوحة الأسعار» — your contributions, «سجّل سعر جديد», «أرخص سعر حواليك»
/// with its city filter, «أكثر المشاركين 🏆» — and, as a sub-view in the
/// same place, the «سجّل السعر» form.
///
/// Same backend as before, not Kotlin's direct `price_index` insert: the
/// table takes no client writes since
/// `20260921160000_price_reports_through_the_server`, so a report is queued
/// for `zad_report_price` (which also takes Kotlin's category), and the board
/// reads `zad_price_leaderboard` — a rank and a count, named «المساهم N» as
/// Kotlin names them.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `hide TextDirection`: the price field needs dart:ui's, digits left to right.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/prices/application/prices_controller.dart';
import 'package:zad/shared/prices/domain/prices.dart';

/// Opens the prices screen.
Future<void> showPricesScreen(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PricesScreen()));

/// Kotlin's slate text, fixed in both themes as Kotlin has it.
const Color _ink = Color(0xFF0F172A);
const Color _slate = Color(0xFF475569);

/// Kotlin's `ZadHubListBottomPadding`.
const double _hubBottom = 110;

/// The board, or the form over it.
class PricesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends ConsumerState<PricesScreen> {
  bool _showForm = false;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_showForm,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) setState(() => _showForm = false);
    },
    child: Scaffold(
      body: SafeArea(
        child: _showForm
            ? PriceReportForm(
                onBack: () => setState(() => _showForm = false),
                onSubmitted: () => setState(() => _showForm = false),
              )
            : CrowdsourceDashboard(
                onReportPrice: () => setState(() => _showForm = true),
                onBack: () => Navigator.of(context).maybePop(),
              ),
      ),
    ),
  );
}

/// Kotlin's `PriceReportingScreen`: the report form.
class PriceReportForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const new({required this.onBack, required this.onSubmitted, super.key});

  /// Back to the board.
  final VoidCallback onBack;

  /// After a report was queued.
  final VoidCallback onSubmitted;

  @override
  ConsumerState<PriceReportForm> createState() => _PriceReportFormState();
}

class _PriceReportFormState extends ConsumerState<PriceReportForm> {
  static const List<String> _categories = <String>[
    'bread',
    'milk',
    'eggs',
    'oil',
    'vegetables',
    'fruits',
    'general',
  ];

  final TextEditingController _item = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _store = TextEditingController();
  String _category = 'bread';
  bool _submitting = false;
  ReportProblem? _problem;

  @override
  void initState() {
    super.initState();
    _item.addListener(_changed);
    _price.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _item.dispose();
    _price.dispose();
    _location.dispose();
    _store.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_item.text.isEmpty || _price.text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final problem = await ref
        .read(pricesControllerProvider.notifier)
        .report(
          item: _item.text,
          priceText: _price.text,
          store: _store.text,
          city: _location.text,
          category: _category,
        );
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _problem = problem;
        _submitting = false;
      });
      return;
    }
    final city = tidyReportText(_location.text);
    if (city.isNotEmpty) {
      unawaited(ref.read(pricesControllerProvider.notifier).setCity(city));
    }
    messenger?.showSnackBar(
      const SnackBar(content: Text('تم تسجيل السعر بنجاح! شكراً على مساهمتك.')),
    );
    widget.onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final symbol =
        ref
            .watch(pricesControllerProvider.select((v) => v.market))
            ?.currencySymbol ??
        '';
    const labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _slate,
    );
    final fieldShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    );

    Widget field(
      String label,
      TextEditingController controller,
      String hint, {
      String? error,
      bool number = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: labelStyle),
        TextField(
          controller: controller,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          textDirection: number ? TextDirection.ltr : null,
          onChanged: number
              ? (v) {
                  // Kotlin: only a number (or nothing) is taken.
                  if (v.isNotEmpty && double.tryParse(v) == null) {
                    final cut = v.substring(0, v.length - 1);
                    controller.value = TextEditingValue(
                      text: cut,
                      selection: TextSelection.collapsed(offset: cut.length),
                    );
                  }
                }
              : null,
          decoration: InputDecoration(
            hintText: hint,
            border: fieldShape,
            enabledBorder: fieldShape,
            isDense: true,
            errorText: error,
            prefixIcon: number
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(symbol, style: const TextStyle(fontSize: 12)),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(),
          ),
        ),
      ],
    );

    final canSend =
        _item.text.isNotEmpty && _price.text.isNotEmpty && !_submitting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + _hubBottom),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              SizedBox.square(
                dimension: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: widget.onBack,
                  tooltip: 'Back',
                  icon: Icon(Icons.arrow_back, color: scheme.primary),
                ),
              ),
              const Text(
                'سجّل السعر',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const Spacer(),
              Icon(Icons.trending_up, color: scheme.primary, size: 24),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outline, width: 0.5),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.info, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ساهم في تحديث أسعار السوق الحية. بيانات العائلة تساعد '
                  'تنبؤات أفضل.',
                  style: TextStyle(fontSize: 12, color: _slate),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        field(
          'اسم السلعة',
          _item,
          'مثل: خبز، لبن، بيض',
          error: switch (_problem) {
            ReportProblem.itemTooShort => 'اكتب اسم الصنف',
            ReportProblem.itemTooLong => 'الاسم طويل أوي',
            _ => null,
          },
        ),
        const SizedBox(height: 16),
        const Text('الفئة', style: labelStyle),
        DropdownMenu<String>(
          initialSelection: _category,
          expandedInsets: EdgeInsets.zero,
          inputDecorationTheme: InputDecorationTheme(
            border: fieldShape,
            isDense: true,
          ),
          onSelected: (v) {
            if (v != null) setState(() => _category = v);
          },
          dropdownMenuEntries: <DropdownMenuEntry<String>>[
            for (final c in _categories)
              DropdownMenuEntry<String>(value: c, label: c),
          ],
        ),
        const SizedBox(height: 16),
        field(
          'السعر',
          _price,
          'مثل: 15.50',
          number: true,
          error: switch (_problem) {
            ReportProblem.noPrice => 'اكتب السعر',
            ReportProblem.priceTooHigh => 'الرقم ده كبير أوي',
            _ => null,
          },
        ),
        const SizedBox(height: 16),
        field(
          'المنطقة',
          _location,
          'مثل: القاهرة، الجيزة',
          error: _problem == ReportProblem.cityTooLong
              ? 'الاسم طويل أوي'
              : null,
        ),
        const SizedBox(height: 16),
        field(
          'اسم المتجر (اختياري)',
          _store,
          'مثل: كارفور، سبينيز',
          error: _problem == ReportProblem.storeTooLong
              ? 'الاسم طويل أوي'
              : null,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: canSend ? () => unawaited(_submit()) : null,
            style: FilledButton.styleFrom(backgroundColor: scheme.primary),
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.check, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'أرسل السعر',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Kotlin's `CrowdsourceDashboard`.
class CrowdsourceDashboard extends ConsumerStatefulWidget {
  /// Creates the board.
  const new({required this.onReportPrice, required this.onBack, super.key});

  /// Opens the form.
  final VoidCallback onReportPrice;

  /// Leaves the screen.
  final VoidCallback onBack;

  @override
  ConsumerState<CrowdsourceDashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<CrowdsourceDashboard> {
  late final TextEditingController _location = TextEditingController(
    text: ref.read(pricesControllerProvider).city ?? '',
  );

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final view = ref.watch(pricesControllerProvider);
    final controller = ref.read(pricesControllerProvider.notifier);
    final mine = view.leaderboard.where((r) => r.isMe).firstOrNull;
    final contributions =
        (mine?.reports ?? 0) + view.queued.where((q) => !q.refused).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + _hubBottom),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              SizedBox.square(
                dimension: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: widget.onBack,
                  tooltip: 'Back',
                  icon: Icon(Icons.arrow_back, color: scheme.primary),
                ),
              ),
              Text(
                'لوحة الأسعار',
                style: ZadType.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _StatCard(
            title: 'مساهماتك',
            value: '$contributions',
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: widget.onReportPrice,
            style: FilledButton.styleFrom(backgroundColor: scheme.primary),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'سجّل سعر جديد',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _CheapestNearYou(
          view: view,
          location: _location,
          onSearch: () => unawaited(controller.setCity(_location.text)),
          onReportPrice: widget.onReportPrice,
        ),
        const SizedBox(height: 24),
        AreaTrendsSection(trends: view.trends),
        const SizedBox(height: 24),
        Text(
          'أكثر المشاركين 🏆',
          style: ZadType.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        for (final (i, entry) in view.leaderboard.indexed) ...<Widget>[
          const SizedBox(height: 16),
          _LeaderboardCard(entry: entry, rank: i + 1),
        ],
        if (view.leaderboard.isEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: KtEmptyState(
              icon: Icons.emoji_events,
              title: 'لسه مفيش مساهمات',
              subtitle:
                  'سجّل أول سعر شفته في السوق — مساهمتك بتظهر هنا وبتساعد '
                  'جيرانك يلاقوا أرخص مكان.',
              action: _FirstReportButton(
                onPressed: widget.onReportPrice,
                withIcon: true,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FirstReportButton extends StatelessWidget {
  const new({required this.onPressed, this.withIcon = false});

  final VoidCallback onPressed;
  final bool withIcon;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 44),
    child: OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (withIcon) ...<Widget>[
            const Icon(Icons.add, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            'سجّل أول سعر',
            style: TextStyle(fontWeight: withIcon ? FontWeight.bold : null),
          ),
        ],
      ),
    ),
  );
}

/// Kotlin's `StatCard`.
class _StatCard extends StatelessWidget {
  const new({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: ZadType.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: ZadType.labelLarge.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Kotlin's `LeaderboardCard`: gold, silver, bronze, then grey.
class _LeaderboardCard extends StatelessWidget {
  const new({required this.entry, required this.rank});

  final LeaderboardRow entry;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline, width: 0.5),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: switch (rank) {
                1 => const Color(0xFFFFD700),
                2 => const Color(0xFFC0C0C0),
                3 => const Color(0xFFCD7F32),
                _ => const Color(0xFFE0E0E0),
              },
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'المساهم $rank',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
                Text(
                  '${entry.reports} مساهمات',
                  style: const TextStyle(fontSize: 12, color: _slate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotlin's `CheapestNearYouSection`: the community's reports of the last
/// 14 days, in the account's currency, for a city or the whole country.
class _CheapestNearYou extends StatelessWidget {
  const new({
    required this.view,
    required this.location,
    required this.onSearch,
    required this.onReportPrice,
  });

  final PricesView view;
  final TextEditingController location;
  final VoidCallback onSearch;
  final VoidCallback onReportPrice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = view.rows;
    final symbol = view.market?.currencySymbol ?? '';
    final hasRows = view.snapshot != null && rows.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'أرخص سعر حواليك',
          style: ZadType.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'من بلاغات مجتمع زاد آخر ١٤ يوم — مش أسعار رسمية',
          style: ZadType.bodySmall.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: location,
                maxLength: ReportBounds.textMax,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                onSubmitted: (_) => onSearch(),
                decoration: const InputDecoration(
                  labelText: 'المدينة أو المنطقة (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: FilledButton.tonal(
                onPressed: onSearch,
                style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Icon(
                  Icons.search,
                  size: 18,
                  semanticLabel: 'دوّر',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (view.isRefreshing && !hasRows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: scheme.primary),
            ),
          )
        else if (view.error != null && !hasRows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: KtEmptyState(
              icon: Icons.cloud_off,
              title: 'مقدرناش نجيب الأسعار دلوقتي',
              action: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: OutlinedButton(
                  onPressed: onSearch,
                  child: const Text('جرّب تاني'),
                ),
              ),
            ),
          )
        else if (!hasRows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: KtEmptyState(
              icon: Icons.storefront,
              title: 'لسه مفيش بلاغات هنا',
              subtitle: 'كن أول واحد يبلّغ عن سعر — جيرانك هيشكروك',
              action: _FirstReportButton(onPressed: onReportPrice),
            ),
          )
        else
          for (final row in rows) ...<Widget>[
            ZadListCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          row.itemName,
                          style: ZadType.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_where(row)} · ${row.reports} بلاغ',
                          style: ZadType.bodySmall.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${formatPrice(row.minPrice)} $symbol'.trim(),
                    style: ZadType.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  static String _where(CheapestPrice row) {
    final where = <String>[?row.store, ?row.location].join('، ');
    return where.isEmpty ? '—' : where;
  }
}

/// A price without grouping noise: `12.5`, `1,250`.
String formatPrice(double value) =>
    NumberFormat('#,##0.##', 'en').format(value);

/// «ترندات سوقك»: what enough homes in the market bought or listed lately.
///
/// Only what the server let through — an item at five homes or more, a
/// family counting once — so there are no stores, prices or people here,
/// and an empty list is the honest answer while the market is small.
class AreaTrendsSection extends StatelessWidget {
  /// Creates the section.
  const new({required this.trends, super.key});

  /// The last answer, or null before the first.
  final AreaTrends? trends;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = trends;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'ترندات سوقك',
          style: ZadType.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'اللي بيوت كتير في بلدك اشترته أو حطّته في قايمة التسوق آخر '
          '${t?.days ?? 14} يوم — من غير أسماء ولا محلات',
          style: ZadType.bodySmall.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (t == null || t.items.isEmpty)
          KtEmptyState(
            icon: Icons.groups_outlined,
            title: t?.noMarket ?? false
                ? 'اختار بلدك الأول'
                : 'لسه مفيش ترند في سوقك',
            subtitle: t?.noMarket ?? false
                ? 'الترندات بتتحسب لكل بلد لوحده.'
                : 'الصنف بيظهر هنا لما ${t?.minHouseholds ?? 5} بيوت مختلفة '
                      'على الأقل يشتروه أو يحطّوه في قايمتهم — عشان محدش '
                      'يتعرف من مشترياته. كل فاتورة بتصوّرها بتقرّب اليوم ده.',
          )
        else
          for (final trend in t.items) _TrendRow(trend: trend),
      ],
    );
  }
}

class _TrendRow extends StatelessWidget {
  const new({required this.trend});

  final AreaTrend trend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (
      IconData icon,
      Color color,
      String label,
    ) = switch (trend.direction) {
      TrendDirection.up => (Icons.trending_up, ZadColors.green700, 'بيزيد'),
      TrendDirection.down => (
        Icons.trending_down,
        ZadColors.terracottaRust,
        'بيقل',
      ),
      TrendDirection.flat => (Icons.trending_flat, scheme.outline, 'ثابت'),
      TrendDirection.fresh => (Icons.fiber_new, scheme.primary, 'جديد'),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 20, semanticLabel: label),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trend.item,
              style: ZadType.bodyLarge.copyWith(color: scheme.onSurface),
            ),
          ),
          Text(
            '${trend.households} بيوت',
            style: ZadType.labelMedium.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
