/// Kotlin's `SubscriptionsScreen` (`ui/screens/SubscriptionsScreen.kt`): the
/// «أقساط واشتراكات وفواتير» tab — the active/all chips, «إجمالي الاشتراكات
/// الشهرية» banner, the four segmented tabs, the brand-coloured rows with
/// «تم الدفع ✓» and the four quiet icons, and `AddEditSubscriptionDialog`.
///
/// Not here, by the owner's standing decision on automatic model calls:
/// Kotlin's `detectSubscriptions()` on open (and the «زاد يبحث عن اشتراكاتك»
/// banner and pending-confirmation section that belong to it), and
/// `classifyBill` while the name is typed. The category still follows the
/// preset or the kind, as Kotlin's save does.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/foundation/compose_shadow.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_palette.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/subscriptions/presentation/subscription_brands.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/shared/subscriptions/domain/bnpl.dart';
import 'package:zad/shared/subscriptions/domain/renewal.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';

/// Opens the screen.
Future<void> showSubscriptionsScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SubscriptionsScreen()),
    );

String _money(double amount, String symbol) {
  final pattern = amount % 1 == 0 ? '#,##0' : '#,##0.##';
  return '${NumberFormat(pattern, 'en').format(amount)} $symbol'.trim();
}

/// Kotlin's `billingCycleLabel`.
String _cycleLabel(BillingCycle cycle) => switch (cycle) {
  BillingCycle.yearly => 'سنوي',
  BillingCycle.weekly => 'أسبوعي',
  BillingCycle.monthly => 'شهري',
};

/// Kotlin's tab filters. `type` and `category` are stored values.
bool _inTab(Subscription s, int tab) => switch (tab) {
  1 => s.type == 'subscription' || s.category == 'اشتراك',
  2 => s.category == 'فواتير' || s.type == 'bill' || s.type == 'utility',
  3 =>
    s.category == 'الأقساط' ||
        s.category == 'أقساط' ||
        s.category == 'التزامات' ||
        s.type == 'installment' ||
        s.type == 'rent',
  _ => true,
};

/// Rows an old AI detector wrote, which no customer would have: Kotlin's
/// «مسح الكل» targets.
bool _isAutoDetected(Subscription s) =>
    s.category == 'Auto-detected' ||
    s.category == 'ai_detected' ||
    ((s.category == 'اشتراك' || s.category == 'فواتير') &&
        s.title.trim().isEmpty);

DateTime? _storedRenewal(Subscription s) {
  final raw = s.renewalDate;
  if (raw == null || raw.length < 10) return null;
  final d = DateTime.tryParse(raw.substring(0, 10));
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

/// The screen.
class SubscriptionsScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [embedded] drops the app bar inside the finances
  /// screen's «الاشتراكات والأقساط» tab.
  const new({this.embedded = false, super.key});

  /// Whether a host screen already shows the title.
  final bool embedded;

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubsState();
}

class _SubsState extends ConsumerState<SubscriptionsScreen> {
  int _tab = 0;
  bool _showInactive = false;

  static const List<String> _tabs = <String>[
    'الكل',
    'اشتراكات',
    'فواتير',
    'أقساط',
  ];

  Future<void> _clearDetected(List<Subscription> targets) async {
    final controller = ref.read(subscriptionsControllerProvider.notifier);
    for (final s in targets) {
      await controller.remove(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    final view = ref.watch(subscriptionsControllerProvider);
    final controller = ref.read(subscriptionsControllerProvider.notifier);
    final symbol = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final today = view.today;
    final active = view.items.where((s) => s.isActive).toList();
    final totalMonthly = active.fold<double>(0, (sum, s) => sum + s.amount);
    final pool = _showInactive ? view.items : active;
    final filtered = pool.where((s) => _inTab(s, _tab)).toList()
      ..sort((a, b) {
        final byActive = (a.isActive ? 0 : 1).compareTo(b.isActive ? 0 : 1);
        if (byActive != 0) return byActive;
        // On the instalments tab, BNPL plans first, under their own header:
        // they end in weeks and are the ones people forget they took.
        if (_tab == 3) {
          final byBnpl = (isBnpl(a) ? 0 : 1).compareTo(isBnpl(b) ? 0 : 1);
          if (byBnpl != 0) return byBnpl;
        }
        int days(Subscription s) =>
            s.nextRenewalFrom(today)?.difference(today).inDays ?? 999;
        return days(a).compareTo(days(b));
      });
    final detected = view.items.where(_isAutoDetected).toList();

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            _Chip(
              label: 'النشطة',
              selected: !_showInactive,
              selectedColor: scheme.primaryContainer,
              onTap: () => setState(() => _showInactive = false),
            ),
            const SizedBox(width: 6),
            _Chip(
              label: 'الكل',
              selected: _showInactive,
              selectedColor: ext.surfaceContainerHigh,
              onTap: () => setState(() => _showInactive = true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: HeroGradientCard.banner(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.credit_card,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'إجمالي الاشتراكات الشهرية',
                            style: ZadType.labelMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              _money(totalMonthly, symbol),
                              style: ZadType.displayMedium.copyWith(
                                fontSize: 36,
                                height: 44 / 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          'اشتراكات نشطة',
                          style: ZadType.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        Text(
                          '${active.length}',
                          style: ZadType.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ZadSegmentedTabs(
          tabs: _tabs,
          selectedIndex: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
        if (detected.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '${detected.length} اشتراك مكتشف تلقائياً',
                  style: ZadType.labelMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => unawaited(_clearDetected(detected)),
                  icon: Icon(Icons.auto_delete, size: 16, color: scheme.error),
                  label: Text(
                    'مسح الكل',
                    style: ZadType.labelLarge.copyWith(color: scheme.error),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: KtEmptyState(
              icon: Icons.credit_card,
              title: _tab == 0
                  ? 'لا توجد اشتراكات'
                  : 'لا توجد عناصر في هذا التصنيف',
            ),
          )
        else
          for (final (i, sub) in filtered.indexed) ...<Widget>[
            if (_tab == 3 &&
                (i == 0 || isBnpl(filtered[i - 1]) != isBnpl(sub))) ...<Widget>[
              if (i > 0) const SizedBox(height: 16),
              Text(
                isBnpl(sub) ? 'اشتري دلوقتي وادفع بعدين' : 'أقساط وقروض وإيجار',
                style: ZadType.titleSmall,
              ),
              const SizedBox(height: 8),
            ] else if (i > 0)
              const SizedBox(height: 12),
            _ListItemEnter(
              key: ValueKey<String>(sub.id),
              index: i,
              child: SubscriptionCardFull(
                sub: sub,
                today: today,
                symbol: symbol,
                onToggleActive: () =>
                    unawaited(controller.setActive(sub, active: !sub.isActive)),
                onToggleAutoDeduct: () => unawaited(
                  controller.save(sub.copyWith(autoDeduct: !sub.autoDeduct)),
                ),
                onEdit: () => unawaited(
                  showAddEditSubscriptionDialog(context, subscription: sub),
                ),
                onDelete: () => unawaited(controller.remove(sub)),
                onMarkAsPaid: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await controller.markPaid(sub);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم تسجيل سداد ${sub.title} وترحيل الموعد للشهر '
                        'القادم بنجاح',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
      ],
    );

    final body = Stack(
      children: <Widget>[
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: () => controller.refresh(force: true),
            child: list,
          ),
        ),
        PositionedDirectional(
          end: 24,
          bottom: 16,
          child: SafeArea(
            child: FloatingActionButton(
              heroTag: null,
              onPressed: () =>
                  unawaited(showAddEditSubscriptionDialog(context)),
              backgroundColor: scheme.primary,
              foregroundColor: Colors.white,
              tooltip: 'إضافة',
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('الاشتراكات والفواتير')),
      backgroundColor: widget.embedded ? Colors.transparent : null,
      body: body,
    );
  }
}

class _Chip extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: FilterChip(
      label: Text(label, style: ZadType.labelSmall),
      selected: selected,
      showCheckmark: true,
      selectedColor: selectedColor,
      onSelected: (_) => onTap(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

/// Kotlin's `ZadTransitions.listItemEnter`: a third-height slide up and a
/// fade, 300ms, 40ms later per row (at most 400ms).
class _ListItemEnter extends StatefulWidget {
  const new({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  @override
  State<_ListItemEnter> createState() => _ListItemEnterState();
}

class _ListItemEnterState extends State<_ListItemEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(
      Duration(milliseconds: math.min(widget.index * 40, 400)),
      () {
        if (mounted) _t.forward();
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (_, child) => FractionalTranslation(
      translation: Offset(0, (1 - _t.value) / 3),
      child: Opacity(opacity: _t.value, child: child),
    ),
    child: widget.child,
  );
}

/// Kotlin's `SubScreenSubscriptionCardFull`: a 4dp urgency stripe, the
/// brand's tile when the service is known, the name over the renewal line,
/// and the amount over the yearly cost, «تم الدفع ✓» and four quiet icons.
class SubscriptionCardFull extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.sub,
    required this.today,
    required this.symbol,
    required this.onToggleActive,
    required this.onToggleAutoDeduct,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkAsPaid,
    super.key,
  });

  /// The row.
  final Subscription sub;

  /// Today, in the account's zone.
  final DateTime today;

  /// The currency symbol.
  final String symbol;

  /// Pause or resume.
  final VoidCallback onToggleActive;

  /// Auto-deduct on or off.
  final VoidCallback onToggleAutoDeduct;

  /// Edit.
  final VoidCallback onEdit;

  /// Delete.
  final VoidCallback onDelete;

  /// «تم الدفع ✓».
  final VoidCallback onMarkAsPaid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    final next = sub.nextRenewalFrom(today) ?? _storedRenewal(sub);
    final daysLeft = next?.difference(today).inDays;
    final brand = subscriptionBrandFor(sub.title, sub.provider);
    final accent = !sub.isActive
        ? scheme.outlineVariant
        : daysLeft != null && daysLeft <= 3
        ? scheme.error
        : daysLeft != null && daysLeft <= 7
        ? scheme.secondary
        : scheme.primary;
    final shape = BorderRadius.circular(20);

    Widget quiet(IconData icon, String label, Color tint, VoidCallback onTap) =>
        Tooltip(
          message: label,
          child: InkResponse(
            onTap: onTap,
            radius: 14,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(icon, size: 18, color: tint, semanticLabel: label),
            ),
          ),
        );

    final yearly = switch (sub.billingCycle?.toUpperCase()) {
      'YEARLY' => sub.amount,
      'WEEKLY' => sub.amount * 52,
      _ => sub.amount * 12,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: composeShadow(
          elevation: 2,
          ambient: Colors.black,
          spot: Colors.black,
        ),
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Container(
          decoration: BoxDecoration(
            color: sub.isActive ? scheme.surface : ext.surfaceContainerLow,
            borderRadius: shape,
            border: Border.all(
              color: sub.isActive
                  ? scheme.outlineVariant.withValues(alpha: 0.5)
                  : scheme.outlineVariant,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: <Widget>[
                        if (brand != null) ...<Widget>[
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: brand.color.withValues(
                                alpha: sub.isActive ? 0.14 : 0.06,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: composeShadow(
                                elevation: 2,
                                ambient: Colors.black,
                                spot: brand.color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              brand.icon,
                              size: 22,
                              color: brand.color.withValues(
                                alpha: sub.isActive ? 1 : 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                sub.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: sub.isActive
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 3),
                              if (bnplProviderOf(sub.title, sub.provider)
                                  case final bnpl?) ...<Widget>[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    'اشتري وادفع بعدين · ${bnpl.name}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                              Text(
                                switch (daysLeft) {
                                  null => sub.provider ?? '',
                                  0 => 'يُجدد اليوم',
                                  < 0 => 'منتهي منذ ${-daysLeft} يوم',
                                  _ => 'يُجدد بعد $daysLeft يوم',
                                },
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      daysLeft != null &&
                                          daysLeft <= 3 &&
                                          sub.isActive
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              _money(sub.amount, symbol),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: sub.isActive
                                    ? scheme.onSurface
                                    : scheme.outlineVariant,
                              ),
                            ),
                            if (sub.isActive) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                '≈ ${_money(yearly, symbol)}/سنة',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Material(
                                color: scheme.primary.withValues(alpha: 0.12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: scheme.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: onMarkAsPaid,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Icon(
                                          Icons.check_circle,
                                          size: 12,
                                          color: scheme.primary,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'تم الدفع ✓',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: scheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                quiet(
                                  Icons.bolt,
                                  'تفعيل/إيقاف الخصم التلقائي',
                                  sub.autoDeduct
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                  onToggleAutoDeduct,
                                ),
                                const SizedBox(width: 4),
                                quiet(
                                  sub.isActive
                                      ? Icons.pause_circle
                                      : Icons.play_circle,
                                  sub.isActive ? 'تعطيل' : 'تفعيل',
                                  scheme.onSurfaceVariant,
                                  onToggleActive,
                                ),
                                const SizedBox(width: 4),
                                quiet(
                                  Icons.edit_note,
                                  'تعديل الاشتراك',
                                  scheme.onSurfaceVariant,
                                  onEdit,
                                ),
                                const SizedBox(width: 4),
                                quiet(
                                  Icons.delete_outline,
                                  'حذف',
                                  scheme.onSurfaceVariant,
                                  onDelete,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `SubscriptionPresetItem`s. Names, providers, categories and types
/// are stored values.
typedef _Preset = ({
  String name,
  String provider,
  String category,
  IconData icon,
  Color color,
  String type,
});

/// The streaming services at the head of [_presets]; the market's BNPL
/// companies are shown after them, then the bills.
const int _subscriptionPresetCount = 6;

final List<_Preset> _presets = <_Preset>[
  (
    name: 'Netflix',
    provider: 'Netflix',
    category: 'ترفيه',
    icon: Icons.movie,
    color: ZadPalette.brandNetflix,
    type: 'subscription',
  ),
  (
    name: 'Shahid',
    provider: 'MBC Shahid',
    category: 'ترفيه',
    icon: Icons.live_tv,
    color: ZadPalette.brandShahid,
    type: 'subscription',
  ),
  (
    name: 'Spotify',
    provider: 'Spotify',
    category: 'موسيقى',
    icon: Icons.music_note,
    color: ZadPalette.brandSpotify,
    type: 'subscription',
  ),
  (
    name: 'YouTube Premium',
    provider: 'Google',
    category: 'ترفيه',
    icon: Icons.smart_display,
    color: ZadPalette.brandYouTube,
    type: 'subscription',
  ),
  (
    name: 'TOD',
    provider: 'TOD TV',
    category: 'رياضة وترفيه',
    icon: Icons.live_tv,
    color: ZadPalette.brandTod,
    type: 'subscription',
  ),
  (
    name: 'Watch IT',
    provider: 'Watch IT',
    category: 'ترفيه',
    icon: Icons.movie,
    color: ZadPalette.brandWatchIt,
    type: 'subscription',
  ),
  (
    name: 'فاتورة كهرباء',
    provider: 'شركة الكهرباء',
    category: 'فواتير',
    icon: Icons.bolt,
    color: ZadPalette.brandElectricity,
    type: 'utility',
  ),
  (
    name: 'فاتورة مياه',
    provider: 'شركة المياه',
    category: 'فواتير',
    icon: Icons.water_drop,
    color: ZadPalette.brandWater,
    type: 'utility',
  ),
  (
    name: 'فاتورة إنترنت',
    provider: 'شركة الاتصالات',
    category: 'اتصالات',
    icon: Icons.wifi,
    color: ZadPalette.brandInternet,
    type: 'utility',
  ),
  (
    name: 'إيجار البيت',
    provider: 'إيجار المنزل',
    category: 'سكن',
    icon: Icons.home,
    color: ZadPalette.brandRent,
    type: 'rent',
  ),
];

/// Kotlin's `parseFlexibleRenewalDate`: Arabic and Persian digits, the
/// standard patterns, then any three (or two) numbers in a sensible order.
DateTime? parseFlexibleRenewalDate(String input, {required DateTime today}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final normalized = String.fromCharCodes(
    trimmed.runes.map((c) {
      if (c >= 0x0660 && c <= 0x0669) return 0x30 + c - 0x0660;
      if (c >= 0x06F0 && c <= 0x06F9) return 0x30 + c - 0x06F0;
      return c;
    }),
  );
  final parts = normalized
      .split(RegExp('[^0-9]+'))
      .where((p) => p.isNotEmpty)
      .map(int.parse)
      .toList();

  DateTime? build(int year, int month, int day) {
    final y = year.clamp(2000, 2100);
    final m = month.clamp(1, 12);
    final maxDay = DateTime.utc(y, m + 1, 0).day;
    return DateTime.utc(y, m, day.clamp(1, maxDay));
  }

  // The standard patterns (yyyy-MM-dd, dd/MM/yyyy and their one-digit forms)
  // are the strict cases of the rules below, when every number is in range.
  bool real(int y, int m, int d) =>
      m >= 1 && m <= 12 && d >= 1 && d <= DateTime.utc(y, m + 1, 0).day;
  final standard = RegExp(r'^\d{1,4}[-/]\d{1,2}[-/]\d{1,4}$');
  if (standard.hasMatch(normalized) && parts.length == 3) {
    final (a, b, c) = (parts[0], parts[1], parts[2]);
    if (a >= 1000 && real(a, b, c)) return DateTime.utc(a, b, c);
    if (c >= 1000 && real(c, b, a)) return DateTime.utc(c, b, a);
  }

  if (parts.length == 3) {
    final (p0, p1, p2) = (parts[0], parts[1], parts[2]);
    if (p0 >= 1000) {
      return p1 > 12 ? build(p0, p2, p1) : build(p0, p1, p2);
    }
    if (p2 >= 1000) {
      if (p0 > 12) return build(p2, p1, p0);
      if (p1 > 12) return build(p2, p0, p1);
      return build(p2, p1, p0);
    }
    final y = p0 >= 20 && p0 <= 99
        ? p0 + 2000
        : p2 >= 20 && p2 <= 99
        ? p2 + 2000
        : today.year;
    if (p0 >= 20 && p0 <= 99 && y == p0 + 2000) return build(y, p1, p2);
    return build(y, p1, p0);
  }
  if (parts.length == 2) {
    final (p0, p1) = (parts[0], parts[1]);
    final (day, month) = p0 > 12 ? (p0, p1) : (p1, p0);
    return build(today.year, month, day);
  }
  return null;
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Opens Kotlin's `AddEditSubscriptionDialog`.
Future<void> showAddEditSubscriptionDialog(
  BuildContext context, {
  Subscription? subscription,
}) => showDialog<void>(
  context: context,
  builder: (_) => AddEditSubscriptionDialog(subscription: subscription),
);

/// Kotlin's `AddEditSubscriptionDialog`: one form for adding and editing.
class AddEditSubscriptionDialog extends ConsumerStatefulWidget {
  /// Creates the dialog.
  const new({this.subscription, super.key});

  /// The row being edited, or null to add one.
  final Subscription? subscription;

  @override
  ConsumerState<AddEditSubscriptionDialog> createState() => _DialogState();
}

class _DialogState extends ConsumerState<AddEditSubscriptionDialog> {
  late final Subscription? _sub = widget.subscription;
  late final TextEditingController _title = TextEditingController(
    text: _sub?.title ?? '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: switch (_sub?.amount) {
      final double a => NumberFormat('0.##', 'en').format(a),
      null => '',
    },
  );
  final TextEditingController _total = TextEditingController();
  final TextEditingController _remaining = TextEditingController();
  late final TextEditingController _provider = TextEditingController(
    text: _sub?.provider ?? '',
  );
  late final TextEditingController _date = TextEditingController(
    text: switch (_sub?.renewalDate) {
      final String d when d.length >= 10 => d.substring(0, 10),
      final String d => d,
      null => _iso(ref.read(subscriptionsControllerProvider).today),
    },
  );
  late String _type = _sub?.type ?? 'subscription';
  late String _category = _sub?.category ?? 'اشتراك';
  late BillingCycle _cycle = _sub?.cycle ?? BillingCycle.monthly;

  @override
  void initState() {
    super.initState();
    for (final c in <TextEditingController>[
      _title,
      _amount,
      _provider,
      _date,
    ]) {
      c.addListener(_changed);
    }
    _total.addListener(_installments);
    _remaining.addListener(_installments);
  }

  void _changed() => setState(() {});

  /// Kotlin: the monthly amount from the total and the count, while the
  /// amount is still empty.
  void _installments() {
    final total = double.tryParse(_total.text);
    final count = int.tryParse(_remaining.text);
    if (total != null &&
        total > 0 &&
        count != null &&
        count > 0 &&
        _amount.text.trim().isEmpty) {
      final monthly = total / count;
      _amount.text = monthly == monthly.truncateToDouble()
          ? monthly.toInt().toString()
          : monthly.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _title,
      _amount,
      _total,
      _remaining,
      _provider,
      _date,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = ref.read(subscriptionsControllerProvider).today;
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.utc(2100),
      confirmText: 'تأكيد',
      cancelText: 'إلغاء',
    );
    if (picked != null && mounted) {
      _date.text = _iso(DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save(DateTime? parsed) async {
    unawaited(HapticFeedback.heavyImpact());
    final today = ref.read(subscriptionsControllerProvider).today;
    final amount = double.tryParse(_amount.text) ?? 0;
    final date = parsed ?? today;
    final category = switch (_type) {
      'installment' =>
        _category == 'اشتراك' || _category.isEmpty ? 'أقساط' : _category,
      'utility' =>
        _category == 'اشتراك' || _category.isEmpty ? 'فواتير' : _category,
      'rent' =>
        _category == 'اشتراك' || _category.isEmpty ? 'التزامات' : _category,
      _ => _category.isEmpty ? 'اشتراك' : _category,
    };
    final remaining = _remaining.text.trim();
    final title =
        _type == 'installment' &&
            remaining.isNotEmpty &&
            !_title.text.contains('قسط')
        ? '${_title.text.trim()} ($remaining أقساط)'
        : _title.text.trim();
    final provider = _provider.text.trim();
    final controller = ref.read(subscriptionsControllerProvider.notifier);
    final navigator = Navigator.of(context);
    final existing = _sub;
    if (existing == null) {
      await controller.add(
        title: title,
        amount: amount,
        cycle: _cycle,
        renewsOn: date,
        category: category,
        type: _type,
        provider: provider,
      );
    } else {
      await controller.save(
        existing.copyWith(
          title: title,
          amount: amount,
          renewalDate: _iso(date),
          dueDay: date.day,
          provider: provider,
          category: category,
          billingCycle: _cycle.wireName,
          type: _type,
        ),
      );
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = ref.watch(
      subscriptionsControllerProvider.select((v) => v.today),
    );
    final symbol = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final amount = double.tryParse(_amount.text);
    final parsed = parseFlexibleRenewalDate(_date.text, today: today);
    final canSave =
        _title.text.trim().isNotEmpty &&
        amount != null &&
        amount > 0 &&
        parsed != null;
    final sectionLabel = ZadType.labelSmall.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    // The account's own BNPL companies — valU in Egypt, Tabby and Tamara in
    // the Gulf — instead of Tabby and Tamara for everybody.
    final country = ref.watch(accountCountryProvider);
    final presets = <_Preset>[
      ..._presets.take(_subscriptionPresetCount),
      for (final b in bnplProvidersFor(country))
        (
          name: b.name,
          provider: b.provider,
          category: 'أقساط',
          icon: Icons.shopping_bag,
          color: scheme.secondary,
          type: 'installment',
        ),
      ..._presets.skip(_subscriptionPresetCount),
    ];

    return AlertDialog(
      title: Text(
        _sub == null ? 'إضافة اشتراك جديد' : 'تعديل الاشتراك',
        style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.bold),
      ),
      // A horizontal ListView inside AlertDialog needs a bounded width, or
      // the dialog's IntrinsicWidth throws on layout.
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('الخدمات والاشتراكات المقترحة:', style: sectionLabel),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: presets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final p = presets[i];
                    final on = _title.text == p.name;
                    return Material(
                      color: on
                          ? p.color.withValues(alpha: 0.18)
                          : scheme.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: on
                              ? p.color
                              : scheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          setState(() {
                            _title.text = p.name;
                            _provider.text = p.provider;
                            _category = p.category;
                            _type = p.type;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: p.color.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(p.icon, size: 14, color: p.color),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                p.name,
                                style: ZadType.labelSmall.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Text('تصنيف الالتزام:', style: sectionLabel),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final (key, label) in const <(String, String)>[
                    ('subscription', 'اشتراك شهري'),
                    ('installment', 'قسط'),
                    ('utility', 'فاتورة'),
                    ('rent', 'التزام'),
                  ])
                    FilterChip(
                      selected: _type == key,
                      onSelected: (_) => setState(() => _type = key),
                      label: Text(label, style: ZadType.labelSmall),
                    ),
                ],
              ),
              if (_type == 'installment') ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _total,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'إجمالي المبلغ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _remaining,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الأقساط المتبقية',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'اسم الاشتراك (مثال: Netflix)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'المبلغ ($symbol)',
                  border: const OutlineInputBorder(),
                  errorText:
                      _amount.text.trim().isNotEmpty &&
                          (amount == null || amount <= 0)
                      ? ''
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _provider,
                decoration: const InputDecoration(
                  labelText: 'مزود الخدمة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _date,
                decoration: InputDecoration(
                  labelText: 'تاريخ التجديد (YYYY-MM-DD)',
                  hintText: 'YYYY-MM-DD',
                  border: const OutlineInputBorder(),
                  errorText: _date.text.trim().isNotEmpty && parsed == null
                      ? ''
                      : null,
                  suffixIcon: IconButton(
                    tooltip: 'اختر التاريخ',
                    onPressed: () => unawaited(_pickDate()),
                    icon: Icon(Icons.calendar_month, color: scheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'دورة الفوترة',
                style: ZadType.labelMedium.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final cycle in const <BillingCycle>[
                    BillingCycle.monthly,
                    BillingCycle.yearly,
                    BillingCycle.weekly,
                  ])
                    FilterChip(
                      selected: _cycle == cycle,
                      onSelected: (_) => setState(() => _cycle = cycle),
                      label: Text(
                        _cycleLabel(cycle),
                        style: ZadType.labelSmall,
                      ),
                    ),
                ],
              ),
              if (_title.text.length >= 3) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'الفئة المقترحة: $_category',
                  style: ZadType.labelSmall.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: canSave ? () => unawaited(_save(parsed)) : null,
          style: FilledButton.styleFrom(shape: const StadiumBorder()),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
