/// The lines of «موجز زاد النهارده» (daily_brief.dart): what needs the
/// customer now, each opening where it is handled. Home shows the first few;
/// «نصايح زاد» shows them all.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/app_language.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/brain/data/home_signals_controller.dart';
import 'package:zad/shared/brain/domain/daily_brief.dart';
import 'package:zad/shared/brain/domain/home_signals.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/insights/application/insights_controller.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/data/consumption_rates.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/subscriptions/application/subscriptions_controller.dart';

/// The brief as it stands, from what is on the device — no model call.
List<BriefItem> watchDailyBrief(WidgetRef ref, {int max = 5}) =>
    ref.watch(dailyBriefProvider).take(max).toList();

/// Every line of the brief, most urgent first, for a screen or the
/// home-screen widget to take what it shows.
final Provider<List<BriefItem>> dailyBriefProvider = Provider<List<BriefItem>>((
  ref,
) {
  final pantry = ref.watch(pantryControllerProvider).items;
  final doses = ref.watch(pharmacyControllerProvider).today;
  final subs = ref.watch(subscriptionsControllerProvider);
  final budget = ref.watch(budgetControllerProvider);
  final needs = ref.watch(familyNeedsProvider);
  final rates = ref.watch(consumptionRatesProvider).value;
  final local = dailyBrief(
    pantry: pantry,
    doses: doses,
    subscriptions: subs.items,
    today: subs.today,
    now: ref.read(nowProvider)(),
    spendable: budget.snapshot == null ? null : budget.spendable,
    currency: budget.snapshot?.currency ?? '',
    familyNeeds: needs,
    rates: rates ?? const {},
    max: 1 << 20,
  );
  HomeSignals? signals;
  try {
    signals = ref.watch(homeSignalsControllerProvider);
  } on Object {
    // The brief never fails because one of its sources did.
    signals = null;
  }
  return withHomeSignals(local, signals, ref.watch(zadL10nProvider));
});

String _amount(double v) =>
    NumberFormat(v % 1 == 0 ? '#,##0' : '#,##0.##', 'en').format(v);

/// The phone's brief with what only the server's «حالة البيت» knows
/// (ZAD_PLAN ٦.٤), each line beside the phone's own of the same weight:
/// a medicine running out after the doses, the budget in danger where
/// «صرفت أكتر» would be — never both — and the season ahead last.
List<BriefItem> withHomeSignals(
  List<BriefItem> local,
  HomeSignals? s,
  ZadL10n l10n,
) {
  if (s == null) return local;
  final extra = <BriefItem>[];
  if (s.medicinesLow.isNotEmpty) {
    final first = s.medicinesLow.first;
    extra.add(
      BriefItem(
        kind: BriefKind.medicineLow,
        title: l10n.briefMedicineLow(first.name, '${first.days}'),
        detail: l10n.briefMedicineLowDetail,
        why: BriefWhy(
          BriefWhyKind.medicineLow,
          name: first.name,
          count: first.days,
        ),
      ),
    );
  }
  final overspent = local.any((b) => b.kind == BriefKind.overspent);
  final available = s.available;
  final daily = s.dailyLeft;
  final days = s.daysLeft;
  if (s.threat == 'DANGER' &&
      !overspent &&
      available != null &&
      available >= 0 &&
      daily != null &&
      days != null) {
    final cur = s.currency;
    extra.add(
      BriefItem(
        kind: BriefKind.budgetDanger,
        title: l10n.briefBudgetDanger('${_amount(daily)} $cur'.trim(), '$days'),
        detail: l10n.briefBudgetDangerDetail,
        why: BriefWhy(
          BriefWhyKind.budgetDanger,
          name: cur,
          left: available,
          perDay: daily,
          count: days,
        ),
      ),
    );
  }
  final ahead = s.seasonAhead;
  if (s.seasonNow == null &&
      ahead != null &&
      ahead.inDays >= 0 &&
      ahead.inDays <= 21) {
    final title = switch (ahead.kind) {
      'ramadan' => l10n.briefSeasonRamadan('${ahead.inDays}'),
      'dhul_hijjah' => l10n.briefSeasonHijjah('${ahead.inDays}'),
      _ => null,
    };
    if (title != null) {
      extra.add(
        BriefItem(
          kind: BriefKind.seasonAhead,
          title: title,
          detail: l10n.briefSeasonDetail,
          why: BriefWhy(BriefWhyKind.season, name: ahead.kind),
        ),
      );
    }
  }
  if (extra.isEmpty) return local;
  final all = <BriefItem>[...local, ...extra];
  final indexed =
      <(int, BriefItem)>[for (var i = 0; i < all.length; i++) (i, all[i])]
        ..sort((a, b) {
          final r = briefRank(a.$2.kind).compareTo(briefRank(b.$2.kind));
          return r != 0 ? r : a.$1.compareTo(b.$1);
        });
  return <BriefItem>[for (final (_, item) in indexed) item];
}

/// The family-chat needs the nightly review left as suggestions. Empty when
/// the insights cannot be read: the brief is read on every open of Home and
/// must never fail because one of its sources did.
final familyNeedsProvider = Provider<List<FamilyNeed>>((ref) {
  try {
    return <FamilyNeed>[
      for (final i in ref.watch(insightsControllerProvider).pending)
        if (i.isShoppingSuggestion)
          (id: i.id, item: i.aboutItem ?? i.title, who: _whoOf(i.body)),
    ];
  } on Object {
    return const <FamilyNeed>[];
  }
});

/// «ماما قال في شات العيلة…» → «ماما», as zad-brain wrote it.
String? _whoOf(String body) {
  final at = body.indexOf(' قال في شات العيلة');
  return at > 0 ? body.substring(0, at).trim() : null;
}

/// «ضيفهم»: each need onto the shopping list, then its suggestion is done.
Future<void> addFamilyNeeds(WidgetRef ref, List<FamilyNeed> needs) async {
  final shopping = ref.read(shoppingControllerProvider.notifier);
  final insights = ref.read(insightsControllerProvider.notifier);
  final pending = ref.read(insightsControllerProvider).pending;
  for (final need in needs) {
    await shopping.add(need.item);
    for (final i in pending) {
      if (i.id == need.id) await insights.markActed(i);
    }
  }
}

/// The brief's lines, or [empty] when nothing needs the customer.
class DailyBriefLines extends ConsumerWidget {
  /// Creates the lines.
  const new({required this.empty, this.max = 5, super.key});

  /// At most this many lines.
  final int max;

  /// Shown when there is nothing.
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = watchDailyBrief(ref, max: max);
    if (items.isEmpty) return empty;

    // A tab lies under whatever was pushed over the shell («نصايح زاد»):
    // back to the shell first, or the tab changes out of sight.
    void open(ShellTab tab) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      ref.read(shellNavigationProvider.notifier).open(tab);
    }

    void tap(BriefItem item) => switch (item.kind) {
      BriefKind.doseDue ||
      BriefKind.dosesMissed ||
      BriefKind.medicineLow => unawaited(
        ZadScreens.showHouseholdSection(context, HouseholdSection.pharmacy),
      ),
      BriefKind.overspent ||
      BriefKind.budgetDanger ||
      BriefKind.renewal => open(ShellTab.money),
      BriefKind.shortage ||
      BriefKind.familyNeed ||
      BriefKind.runningOut ||
      BriefKind.seasonAhead => open(ShellTab.household),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final item in items)
          _Line(
            item: item,
            onTap: () => tap(item),
            onTake: item.dose == null
                ? null
                : () => unawaited(
                    ref
                        .read(pharmacyControllerProvider.notifier)
                        .take(item.dose!),
                  ),
            onAdd: item.needs.isEmpty
                ? null
                : () => unawaited(addFamilyNeeds(ref, item.needs)),
          ),
      ],
    );
  }
}

/// «ليه؟» in words, from the figures the line was decided on.
String briefWhyText(ZadL10n l10n, BriefWhy why) {
  String n(double v) =>
      NumberFormat(v % 1 == 0 ? '#,##0' : '#,##0.##', 'en').format(v);
  return switch (why.kind) {
    BriefWhyKind.dose => l10n.briefWhyDose(why.name, why.time),
    BriefWhyKind.missed => l10n.briefWhyMissed('${why.count}'),
    BriefWhyKind.overspent => l10n.briefWhyOverspent,
    BriefWhyKind.renewal => l10n.briefWhyRenewal(why.name),
    BriefWhyKind.shortage => l10n.briefWhyShortage(
      why.name,
      n(why.left),
      n(why.threshold),
    ),
    BriefWhyKind.runningOut => l10n.briefWhyRunningOut(
      why.name,
      n(why.left),
      n(why.perDay),
    ),
    BriefWhyKind.runningOutApprox => l10n.briefWhyRunningOutApprox(
      why.name,
      n(why.left),
      n(why.perDay),
    ),
    BriefWhyKind.family => l10n.briefWhyFamily,
    BriefWhyKind.medicineLow => l10n.briefWhyMedicineLow(
      why.name,
      '${why.count}',
    ),
    BriefWhyKind.budgetDanger => l10n.briefWhyBudgetDanger(
      '${n(why.left)} ${why.name}'.trim(),
      '${why.count}',
      '${n(why.perDay)} ${why.name}'.trim(),
    ),
    BriefWhyKind.season => l10n.briefWhySeason,
  };
}

class _Line extends StatefulWidget {
  const new({required this.item, required this.onTap, this.onTake, this.onAdd});

  final BriefItem item;
  final VoidCallback onTap;
  final VoidCallback? onTake;
  final VoidCallback? onAdd;

  @override
  State<_Line> createState() => _LineState();
}

class _LineState extends State<_Line> {
  bool _why = false;

  BriefItem get item => widget.item;
  VoidCallback get onTap => widget.onTap;
  VoidCallback? get onTake => widget.onTake;
  VoidCallback? get onAdd => widget.onAdd;

  (IconData, Color) get _look => switch (item.kind) {
    BriefKind.doseDue => (ZadIcons.pharmacy, ZadColors.terracottaRust),
    BriefKind.dosesMissed => (ZadIcons.pharmacy, ZadColors.mustardOchre),
    BriefKind.overspent => (ZadIcons.budget, ZadColors.terracottaRust),
    BriefKind.renewal => (ZadIcons.card, ZadColors.info),
    BriefKind.shortage => (ZadIcons.shopping, ZadColors.forestEmerald),
    BriefKind.familyNeed => (ZadIcons.family, ZadColors.forestEmerald),
    BriefKind.runningOut => (ZadIcons.shopping, ZadColors.mustardOchre),
    BriefKind.medicineLow => (ZadIcons.pharmacy, ZadColors.mustardOchre),
    BriefKind.budgetDanger => (ZadIcons.budget, ZadColors.mustardOchre),
    BriefKind.seasonAhead => (ZadIcons.timetable, ZadColors.info),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _look;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZadRadii.card),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
          child: Row(
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: ZadType.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      item.detail,
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                    if (item.why case final why? when _why)
                      Padding(
                        padding: const EdgeInsets.only(top: ZadSpacing.xs),
                        child: Text(
                          briefWhyText(context.l10n, why),
                          style: ZadType.bodySmall.copyWith(
                            color: ZadColors.ink,
                          ),
                        ),
                      )
                    else if (item.why != null)
                      TextButton(
                        onPressed: () => setState(() => _why = true),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: ZadSpacing.xs,
                          ),
                          alignment: AlignmentDirectional.centerStart,
                        ),
                        child: Text(context.l10n.briefWhy),
                      ),
                  ],
                ),
              ),
              if (onTake != null)
                FilledButton(
                  onPressed: onTake,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('خدتها'),
                ),
              if (onAdd != null)
                FilledButton(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('ضيفهم'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
