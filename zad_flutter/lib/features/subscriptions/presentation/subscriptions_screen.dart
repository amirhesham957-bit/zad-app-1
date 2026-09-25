/// Subscriptions, bills, instalments and the rent — the charges the budget
/// reserves money for before they arrive.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:zad/core/money/money.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/features/subscriptions/data/subscriptions_repository.dart';
import 'package:zad/features/subscriptions/domain/renewal.dart';
import 'package:zad/features/subscriptions/domain/subscription.dart';

/// Opens the screen.
Future<void> showSubscriptionsScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SubscriptionsScreen()),
    );

/// The kinds a customer picks from, and what each writes.
///
/// `type` and `category` are **stored values** (CLAUDE.md i18n rule): the
/// Kotlin screen filters on exactly these strings, so they stay Arabic and
/// unchanged whatever the interface language.
const List<({String label, String type, String category, IconData icon})>
kSubscriptionKinds =
    <({String label, String type, String category, IconData icon})>[
      (
        label: 'اشتراك',
        type: SubscriptionType.subscription,
        category: 'اشتراك',
        icon: ZadIcons.recurring,
      ),
      (
        label: 'فاتورة',
        type: SubscriptionType.utility,
        category: 'فواتير',
        icon: ZadIcons.bill,
      ),
      (
        label: 'قسط',
        type: SubscriptionType.installment,
        category: 'أقساط',
        icon: ZadIcons.card,
      ),
      (
        label: 'إيجار',
        type: SubscriptionType.rent,
        category: 'سكن',
        icon: ZadIcons.home,
      ),
    ];

IconData _iconOf(String type) => switch (type) {
  SubscriptionType.utility || SubscriptionType.bill => ZadIcons.bill,
  SubscriptionType.installment => ZadIcons.card,
  SubscriptionType.rent => ZadIcons.home,
  _ => ZadIcons.recurring,
};

String _cycleLabel(BillingCycle cycle) => switch (cycle) {
  BillingCycle.monthly => 'شهري',
  BillingCycle.yearly => 'سنوي',
  BillingCycle.weekly => 'أسبوعي',
};

String _money(double amount) => NumberFormat('#,##0.##', 'en').format(amount);

String _date(DateTime date) => DateFormat('d MMMM', 'ar').format(date);

/// "النهارده", "بكرة", "بعد ٥ أيام", or the date.
String _whenLabel(DateTime next, DateTime today) {
  final days = next.difference(today).inDays;
  return switch (days) {
    0 => 'النهارده',
    1 => 'بكرة',
    < 8 => 'بعد $days أيام',
    _ => _date(next),
  };
}

/// The screen.
class SubscriptionsScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(subscriptionsControllerProvider);
    final controller = ref.read(subscriptionsControllerProvider.notifier);
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('الاشتراكات والفواتير')),
        // The thumb zone: the one action that adds, bottom corner.
        floatingActionButton: view.items.isEmpty
            ? null
            : FloatingActionButton(
                onPressed: () => showSubscriptionSheet(context),
                tooltip: 'ضيف',
                child: const Icon(ZadIcons.add),
              ),
        body: RefreshIndicator(
          onRefresh: () => controller.refresh(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              if (view.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ZadEmptyState(
                    icon: view.error != null
                        ? ZadIcons.failed
                        : ZadIcons.obligation,
                    title: view.error != null
                        ? 'مقدرتش أجيب الاشتراكات'
                        : 'مفيش اشتراكات ولا فواتير لسه',
                    message: view.error != null
                        ? 'اسحب لتحت نجرب تاني.'
                        : 'ضيف نتفليكس، الكهربا، أو القسط — وزاد هيحجز '
                              'فلوسهم من ميزانيتك قبل ما ييجوا.',
                    tone: view.error != null
                        ? ZadEmptyTone.problem
                        : ZadEmptyTone.calm,
                    action: FilledButton.icon(
                      onPressed: () => showSubscriptionSheet(context),
                      icon: const Icon(ZadIcons.add),
                      label: const Text('ضيف أول واحد'),
                    ),
                  ),
                )
              else ...<Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    ZadSpacing.gutter,
                    ZadSpacing.md,
                    ZadSpacing.gutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _Summary(view: view, currency: currency),
                  ),
                ),
                SliverPadding(
                  // Room under the last row for the button that floats over
                  // it, so the bottom row is never under a thumb-sized circle.
                  padding: const EdgeInsets.fromLTRB(
                    ZadSpacing.gutter,
                    ZadSpacing.lg,
                    ZadSpacing.gutter,
                    ZadSpacing.xxl * 2,
                  ),
                  sliver: SliverList.separated(
                    itemCount: view.items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: ZadSpacing.sm),
                    itemBuilder: (context, i) => _Row(
                      sub: view.items[i],
                      today: view.today,
                      currency: currency,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What the running charges cost a month.
class _Summary extends StatelessWidget {
  const new({required this.view, required this.currency});

  final SubscriptionsView view;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final running = view.active.length;
    return ZadCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'في الشهر',
                  style: ZadType.labelMedium.copyWith(
                    color: ZadColors.inkMuted,
                  ),
                ),
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  '${_money(view.monthlyTotal)} $currency'.trim(),
                  style: ZadType.headlineMedium,
                ),
              ],
            ),
          ),
          Text(
            running == 1 ? 'واحد شغّال' : '$running شغّالين',
            style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// One charge.
class _Row extends ConsumerWidget {
  const new({required this.sub, required this.today, required this.currency});

  final Subscription sub;
  final DateTime today;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = sub.isActive ? sub.nextRenewalFrom(today) : null;
    final when = !sub.isActive
        ? 'متوقف'
        : next == null
        ? 'ميعاده مش محدد'
        : _whenLabel(next, today);
    final soon = next != null && next.difference(today).inDays <= 3;

    return Opacity(
      // Stopped rows stay readable but step back: the eye goes to what is
      // going to take money, not to what no longer will.
      opacity: sub.isActive ? 1 : 0.55,
      child: ZadCard(
        onTap: () => _showActions(context, ref, sub, today),
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.lg,
          vertical: ZadSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: kZadMinTapTarget,
              height: kZadMinTapTarget,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: ZadColors.mint50,
                shape: zadSquircle(ZadRadii.chip),
              ),
              child: Icon(
                _iconOf(sub.type),
                size: 20,
                color: ZadColors.green700,
              ),
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    sub.title.isEmpty ? 'من غير اسم' : sub.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZadType.titleSmall,
                  ),
                  const SizedBox(height: ZadSpacing.xs),
                  Text(
                    when,
                    style: ZadType.labelSmall.copyWith(
                      color: soon ? ZadColors.mustardOchre : ZadColors.inkMuted,
                      fontWeight: soon ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ZadSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${_money(sub.amount)} $currency'.trim(),
                  style: ZadType.titleSmall,
                ),
                const SizedBox(height: ZadSpacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (sub.isPending) ...<Widget>[
                      // Saved here, not yet on the server — said, not hidden.
                      const Icon(
                        ZadIcons.pending,
                        size: 12,
                        color: ZadColors.inkMuted,
                        semanticLabel: 'لسه ما اتبعتش',
                      ),
                      const SizedBox(width: ZadSpacing.xs),
                    ],
                    Text(
                      _cycleLabel(sub.cycle),
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showActions(
  BuildContext context,
  WidgetRef ref,
  Subscription sub,
  DateTime today,
) async {
  final controller = ref.read(subscriptionsControllerProvider.notifier);
  final due = sub.isActive ? sub.nextRenewalFrom(today) : null;

  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: ZadColors.surface,
    shape: zadSquircle(ZadRadii.sheet),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: ZadSpacing.sm),
          if (sub.isActive)
            ListTile(
              leading: const Icon(ZadIcons.paid, color: ZadColors.green700),
              // Names the renewal it pays, so "paid" is never a guess about
              // which month the customer meant.
              title: Text(due == null ? 'دفعت' : 'دفعت — ${_date(due)}'),
              subtitle: const Text('بيتسجل مصروف، والتجديد بيتنقل للي بعده'),
              onTap: () => Navigator.of(sheet).pop('paid'),
            ),
          ListTile(
            leading: const Icon(ZadIcons.edit),
            title: const Text('عدّل'),
            onTap: () => Navigator.of(sheet).pop('edit'),
          ),
          ListTile(
            leading: Icon(sub.isActive ? ZadIcons.pause : ZadIcons.resume),
            title: Text(sub.isActive ? 'وقّفه' : 'شغّله تاني'),
            subtitle: sub.isActive
                ? const Text('مش هيتحجزله فلوس لحد ما تشغّله')
                : null,
            onTap: () => Navigator.of(sheet).pop('toggle'),
          ),
          ListTile(
            leading: const Icon(
              ZadIcons.delete,
              color: ZadColors.terracottaRust,
            ),
            title: const Text(
              'امسحه',
              style: TextStyle(color: ZadColors.terracottaRust),
            ),
            onTap: () => Navigator.of(sheet).pop('delete'),
          ),
          const SizedBox(height: ZadSpacing.sm),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;

  switch (action) {
    case 'paid':
      final paid = await controller.markPaid(sub);
      if (!context.mounted || paid == null) return;
      final next = paid.subscription.nextRenewalFrom(today);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next == null || !paid.subscription.isActive
                ? 'اتسجل مصروف ${_money(sub.amount)}.'
                : 'اتسجل مصروف ${_money(sub.amount)} — التجديد الجاي '
                      '${_date(next)}.',
          ),
        ),
      );
    case 'edit':
      await showSubscriptionSheet(context, editing: sub);
    case 'toggle':
      await controller.setActive(sub, active: !sub.isActive);
    case 'delete':
      final sure = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('تمسح «${sub.title}»؟'),
          content: const Text(
            'هيتشال من الميزانية ومن القايمة. لو عايزه يرجع بعدين، وقّفه بدل '
            'ما تمسحه.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('لأ'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text(
                'امسح',
                style: TextStyle(color: ZadColors.terracottaRust),
              ),
            ),
          ],
        ),
      );
      if (sure ?? false) await controller.remove(sub);
  }
}

/// Opens the add sheet, or the edit sheet for [editing].
Future<void> showSubscriptionSheet(
  BuildContext context, {
  Subscription? editing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: ZadColors.surface,
  shape: zadSquircle(ZadRadii.sheet),
  builder: (_) => SubscriptionSheet(editing: editing),
);

/// Adds a charge, or edits one.
class SubscriptionSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const new({this.editing, super.key});

  /// The row being edited, or null to add one.
  final Subscription? editing;

  @override
  ConsumerState<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<SubscriptionSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.editing?.title ?? '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: switch (widget.editing?.amount) {
      final double a => NumberFormat('0.##', 'en').format(a),
      null => '',
    },
  );
  late String _type = widget.editing?.type ?? SubscriptionType.subscription;
  late BillingCycle _cycle = widget.editing?.cycle ?? BillingCycle.monthly;

  /// A date the customer picked in this sheet. Null means "leave the stored
  /// one alone" when editing — an old row's `'30 مارس'` is not rewritten just
  /// because the sheet was opened.
  DateTime? _renewsOn;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? get _parsedAmount => parseMoneyInput(_amount.text);

  bool get _canSave =>
      !_saving && _title.text.trim().isNotEmpty && (_parsedAmount ?? 0) > 0;

  Future<void> _pickDate() async {
    final today = ref.read(subscriptionsControllerProvider).today;
    final current =
        _renewsOn ?? widget.editing?.nextRenewalFrom(today) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365 * 2)),
      helpText: 'بيتجدد إمتى؟',
    );
    if (picked != null && mounted) {
      setState(
        () => _renewsOn = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _save() async {
    final amount = _parsedAmount;
    if (!_canSave || amount == null) return;
    setState(() => _saving = true);

    final controller = ref.read(subscriptionsControllerProvider.notifier);
    final kind = kSubscriptionKinds.firstWhere(
      (k) => k.type == _type,
      orElse: () => kSubscriptionKinds.first,
    );
    final editing = widget.editing;
    final picked = _renewsOn;

    if (editing == null) {
      await controller.add(
        title: _title.text,
        amount: amount,
        cycle: _cycle,
        renewsOn: picked,
        category: kind.category,
        type: _type,
      );
    } else {
      await controller.save(
        editing.copyWith(
          title: _title.text.trim(),
          amount: amount,
          type: _type,
          // The category follows the kind only when the kind changed; a
          // customer's own category on an unchanged row is theirs.
          category: _type == editing.type ? null : kind.category,
          // Only rewritten when changed: `copyWith` keeps what it is not
          // given, so a row written as `ANNUAL` stays `ANNUAL`.
          billingCycle: _cycle == editing.cycle ? null : _cycle.wireName,
          renewalDate: picked == null ? null : isoDate(picked),
          dueDay: picked?.day,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(
      subscriptionsControllerProvider.select((v) => v.today),
    );
    final shownDate = _renewsOn ?? widget.editing?.nextRenewalFrom(today);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.editing == null ? 'ضيف اشتراك أو فاتورة' : 'تعديل',
              style: ZadType.titleMedium,
            ),
            const SizedBox(height: ZadSpacing.lg),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.sm,
              children: <Widget>[
                for (final kind in kSubscriptionKinds)
                  ChoiceChip(
                    avatar: Icon(kind.icon, size: 16),
                    label: Text(kind.label),
                    selected: kind.type == _type,
                    onSelected: (_) => setState(() => _type = kind.type),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.lg),
            TextField(
              controller: _title,
              autofocus: widget.editing == null,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                hintText: 'نتفليكس، الكهربا، قسط الموبايل…',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'المبلغ كل مرة'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.lg),
            SegmentedButton<BillingCycle>(
              segments: <ButtonSegment<BillingCycle>>[
                for (final cycle in BillingCycle.values)
                  ButtonSegment<BillingCycle>(
                    value: cycle,
                    label: Text(_cycleLabel(cycle)),
                  ),
              ],
              selected: <BillingCycle>{_cycle},
              onSelectionChanged: (s) => setState(() => _cycle = s.first),
            ),
            const SizedBox(height: ZadSpacing.md),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(ZadIcons.obligation),
              label: Text(
                shownDate == null
                    ? 'بيتجدد إمتى؟ (اختياري)'
                    : 'بيتجدد ${_date(shownDate)}',
              ),
            ),
            if (shownDate == null) ...<Widget>[
              const SizedBox(height: ZadSpacing.xs),
              Text(
                // Said here because it is the one consequence of skipping the
                // field that the customer would not guess.
                'من غير ميعاد، زاد مش هيعرف يحجزله فلوس من الميزانية.',
                style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
              ),
            ],
            const SizedBox(height: ZadSpacing.xl),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: const Text('احفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
