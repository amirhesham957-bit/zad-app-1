/// Home's three glance cards, after Kotlin's `ZadHomeGlanceCards.kt`: the
/// pantry's health, the pharmacy and its next dose, and the month's
/// subscriptions. Each is a window onto a screen that already exists, and
/// each reads the same controller that screen does — nothing here fetches on
/// its own.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/application/shopping_controller.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/shortage.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/features/pharmacy/domain/dose_slot.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';
import 'package:zad/features/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/features/subscriptions/domain/subscription.dart';
import 'package:zad/features/subscriptions/presentation/subscriptions_screen.dart';

// ── The shared shell ────────────────────────────────────────────────────────

/// Kotlin's glance card surface: white, 22 corners, a hairline, 16 inside.
class _GlanceShell extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(ZadSpacing.lg),
    decoration: BoxDecoration(
      color: ZadColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: ZadColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: ZadSpacing.md),
          children[i],
        ],
      ],
    ),
  );
}

/// The row every glance card opens with: a tinted round icon, a title and a
/// line under it on one side, a trailing control on the other.
class _GlanceHeader extends StatelessWidget {
  const new({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.trailing,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      DecoratedBox(
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: 32,
          child: Icon(icon, size: 16, color: tint),
        ),
      ),
      const SizedBox(width: ZadSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: ZadType.titleSmall.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              subtitle,
              style: ZadType.labelMedium.copyWith(
                color: subtitleColor ?? ZadColors.slate,
                fontWeight: subtitleColor == null ? null : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

/// "فتح المخزون ←" and its siblings.
class _OpenLink extends StatelessWidget {
  const new({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.sm),
    ),
    child: Text(
      label,
      style: ZadType.labelLarge.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// A thin rounded bar filled to [value] with [gradient].
class _Bar extends StatelessWidget {
  const new({
    required this.value,
    required this.gradient,
    this.height = 6,
    this.track = ZadColors.outlineVariant,
  });

  final double value;
  final List<Color> gradient;
  final double height;
  final Color track;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(ZadRadii.pill),
    child: SizedBox(
      height: height,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: ColoredBox(color: track)),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: value.clamp(0, 1),
            // Without it a childless box in a Stack is zero tall, and the
            // fill never shows.
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(ZadRadii.pill),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

// ── 1. The pantry ───────────────────────────────────────────────────────────

/// "صحة المخزون والنواقص".
///
/// What counts as low is the pantry's own shortage rule (out, expired, at the
/// threshold, expiring within three days), not Kotlin's "two or fewer" — the
/// same rule the pantry screen and the shopping list already use, so the
/// three cannot disagree.
class PantryGlanceCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(pantryControllerProvider);
    final items = view.items;
    final short = <String, Shortage>{
      for (final s in view.shortages) s.item.id: s,
    };
    final total = items.length;
    final health = total == 0 ? 1.0 : (total - short.length) / total;
    final healthColor = health < 0.6
        ? ZadColors.terracottaRust
        : health < 0.85
        ? ZadColors.mustardOchre
        : ZadColors.forestEmerald;
    // Short ones first: the rail is for what needs looking at.
    final ordered = <InventoryItem>[
      for (final s in view.shortages) s.item,
      for (final i in items)
        if (!short.containsKey(i.id)) i,
    ];

    void open() => showHouseholdSection(context, HouseholdSection.pantry);

    return _GlanceShell(
      children: <Widget>[
        _GlanceHeader(
          icon: ZadIcons.inventory,
          tint: ZadColors.forestEmerald,
          title: 'صحة المخزون والنواقص',
          subtitle: 'مراقبة التلف والاحتياج الفعلي',
          trailing: short.isNotEmpty
              ? _LowPill(count: short.length)
              : _OpenLink(
                  label: 'فتح المخزون ←',
                  color: ZadColors.forestEmerald,
                  onTap: open,
                ),
        ),
        if (total > 0)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'مؤشر سلامة المؤونة',
                      style: ZadType.labelMedium.copyWith(
                        color: ZadColors.slate,
                      ),
                    ),
                  ),
                  Text(
                    '${(health * 100).toInt()}% مكتمل',
                    style: ZadType.labelMedium.copyWith(
                      color: healthColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _Bar(
                value: health,
                gradient: <Color>[
                  if (health < 0.6)
                    ZadColors.terracottaRust
                  else
                    ZadColors.mustardOchre,
                  ZadColors.forestEmerald,
                ],
              ),
            ],
          ),
        if (items.isEmpty)
          const ZadEmptyState(
            icon: ZadIcons.inventory,
            title: 'المخزن لسه فاضي',
            message:
                'صوّر فاتورة السوبرماركت أو ضيف أصنافك، وزاد يقولك إيه قرب '
                'يخلص قبل ما تحتاجه',
          )
        else
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ordered.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final item = ordered[i];
                return _FoodTile(
                  item: item,
                  shortage: short[item.id],
                  today: ref.read(nowProvider)(),
                  onOpen: open,
                  onAddToList: () => unawaited(
                    ref
                        .read(shoppingControllerProvider.notifier)
                        .add(item.itemName),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _LowPill extends StatelessWidget {
  const new({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.sm, vertical: 4),
    decoration: BoxDecoration(
      color: ZadColors.terracottaRust.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(ZadRadii.pill),
      border: Border.all(
        color: ZadColors.terracottaRust.withValues(alpha: 0.45),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            color: ZadColors.terracottaRust,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(dimension: 7),
        ),
        const SizedBox(width: 6),
        Text(
          '$count قارب النفاد',
          style: ZadType.labelSmall.copyWith(
            color: ZadColors.terracottaRust,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _FoodTile extends StatelessWidget {
  const new({
    required this.item,
    required this.shortage,
    required this.today,
    required this.onOpen,
    required this.onAddToList,
  });

  final InventoryItem item;
  final Shortage? shortage;
  final DateTime today;
  final VoidCallback onOpen;
  final VoidCallback onAddToList;

  @override
  Widget build(BuildContext context) {
    final isLow = shortage != null;
    final days = item.daysUntilExpiry(today);
    final soon = days != null && days <= 4;
    final gradient = isLow
        ? const <Color>[ZadColors.terracottaRust, ZadColors.terracottaRust]
        : soon
        ? const <Color>[ZadColors.mustardOchre, ZadColors.mustardLight]
        : const <Color>[ZadColors.forestEmerald, ZadColors.forestLight];
    // Kotlin printed the quantity as a number of days ("متبقي 3 أيام" for
    // three cartons). The expiry, when known, is the days; otherwise the
    // line says what is actually left.
    final left = switch (days) {
      final int d when d < 0 => 'انتهت صلاحيته',
      final int d => 'متبقي $d ${d <= 10 ? 'أيام' : 'يوم'}',
      null => 'متبقي ${item.quantity} ${item.unit ?? ''}'.trim(),
    };

    return ZadPressable(
      onPressed: onOpen,
      semanticLabel: item.itemName,
      child: Container(
        width: 155,
        padding: const EdgeInsets.all(ZadSpacing.md),
        decoration: BoxDecoration(
          color: ZadColors.surfaceLow,
          borderRadius: BorderRadius.circular(ZadRadii.card),
          border: Border.all(color: ZadColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _categoryTint(item.category),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    foodEmoji(item.itemName),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: ZadSpacing.xs),
                const Spacer(),
                if (isLow)
                  Flexible(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ZadColors.terracottaRust.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(ZadRadii.pill),
                      ),
                      child: Text(
                        'قارب ينتهي',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.terracottaRust,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              item.itemName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZadType.bodyMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: ZadSpacing.sm),
            _Bar(
              value: (item.quantity / 10).clamp(0.1, 1),
              gradient: gradient,
              height: 5,
              track: ZadColors.outline,
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZadType.labelSmall.copyWith(color: ZadColors.slate),
            ),
            const Spacer(),
            if (isLow)
              Material(
                color: ZadColors.forestEmerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onAddToList,
                  child: SizedBox(
                    height: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          ZadIcons.shopping,
                          size: 14,
                          color: ZadColors.forestEmerald,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'أضف للسلة',
                          style: ZadType.labelMedium.copyWith(
                            color: ZadColors.forestEmerald,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Kotlin tints four category groups from its chart palette; everything
  /// else sits on the neutral tile. The names are the stored Arabic
  /// categories, matched as data.
  static Color _categoryTint(String? category) => switch (category) {
    'خضار' => ZadColors.forestEmerald.withValues(alpha: 0.14),
    'ألبان' || 'مشروبات' => ZadColors.info.withValues(alpha: 0.14),
    'مخبوزات' => ZadColors.mustardOchre.withValues(alpha: 0.14),
    'فاكهة' || 'لحوم' => ZadColors.terracottaRust.withValues(alpha: 0.14),
    _ => ZadColors.outlineVariant,
  };
}

/// A picture for a pantry line, from words in its name — Kotlin's
/// `resolveFoodEmoji`, rule for rule. The Arabic words are matched against
/// what the customer typed, so they are data and stay as they are.
String foodEmoji(String name) {
  final n = name.trim().toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  const rules = <(List<String>, String)>[
    (<String>['موز', 'banana'], '🍌'),
    (<String>['تفاح', 'apple'], '🍎'),
    (<String>['برتقال', 'يوسفي', 'orange'], '🍊'),
    (<String>['فراول', 'strawberr'], '🍓'),
    (<String>['عنب', 'grape'], '🍇'),
    (<String>['بطيخ', 'شمام', 'melon'], '🍉'),
    (<String>['تمر', 'بلح', 'رطب', 'date'], '🌴'),
    (<String>['ليمون', 'lemon'], '🍋'),
    (<String>['طماطم', 'بندورة', 'tomato'], '🍅'),
    (<String>['بطاطس', 'بطاطا', 'potato'], '🥔'),
    (<String>['بصل', 'onion'], '🧅'),
    (<String>['ثوم', 'garlic'], '🧄'),
    (<String>['خيار', 'cucumber'], '🥒'),
    (<String>['جزر', 'carrot'], '🥕'),
    (<String>['خس', 'سلطة', 'جرجير', 'salad'], '🥬'),
    (<String>['فلفل', 'شطة', 'pepper'], '🫑'),
    (<String>['أرز', 'رز', 'عيش', 'rice'], '🍚'),
    (<String>['دجاج', 'فراخ', 'شاورما', 'chicken'], '🍗'),
    (<String>['لحم', 'كفتة', 'برجر', 'ستيك', 'meat', 'beef'], '🥩'),
    (<String>['سمك', 'تونة', 'جمبري', 'سالمون', 'fish', 'tuna'], '🐟'),
    (<String>['بيض', 'egg'], '🥚'),
    (<String>['حليب', 'لبن', 'milk'], '🥛'),
    (<String>['زبادي', 'لبنة', 'روب', 'yogurt'], '🥣'),
    (<String>['جبن', 'جبنة', 'قشطة', 'cheese'], '🧀'),
    (<String>['زبدة', 'سمن', 'butter'], '🧈'),
    (<String>['خبز', 'توست', 'صامولي', 'فينو', 'فطير', 'bread'], '🍞'),
    (
      <String>[
        'مكرونة',
        'معكرونة',
        'باستا',
        'نودلز',
        'اندومي',
        'pasta',
        'noodle',
      ],
      '🍝',
    ),
    (<String>['زيت', 'زيتون', 'oil', 'olive'], '🫒'),
    (<String>['سكر', 'sugar'], '🧂'),
    (<String>['ملح', 'بهار', 'salt'], '🧂'),
    (<String>['شاي', 'كرك', 'tea'], '🫖'),
    (<String>['قهوة', 'بن', 'نسكافيه', 'اسبريسو', 'coffee'], '☕'),
    (<String>['عصير', 'juice'], '🧃'),
    (<String>['ماء', 'مياه', 'water'], '💧'),
    (<String>['مايونيز', 'mayo'], '🥫'),
    (<String>['كاتشب', 'صلصة', 'طحينة', 'sauce'], '🥫'),
    (<String>['شيبس', 'شيبسي', 'chips'], '🍟'),
    (<String>['شوكولات', 'نوتيلا', 'كيك', 'chocolate'], '🍫'),
    (<String>['بسكويت', 'كوكيز', 'cookie'], '🍪'),
    (<String>['صابون', 'مسحوق', 'شامبو', 'كلور', 'تايد', 'soap'], '🧼'),
    (<String>['مناديل', 'فاين', 'tissue'], '🧻'),
    (<String>['بنزين', 'وقود', 'fuel'], '⛽'),
    (<String>['دواء', 'علاج', 'مسكن', 'بنادول', 'panadol'], '💊'),
  ];
  for (final (words, emoji) in rules) {
    if (has(words)) return emoji;
  }
  return '🍽️';
}

// ── 2. The pharmacy ─────────────────────────────────────────────────────────

/// The dose Home offers: the earliest one that can be answered now, else the
/// next one coming. A dose already past its window is the pharmacy screen's
/// to show as missed, not Home's to offer.
DoseSlot? nextDoseOf(List<DoseSlot> slots, DateTime now) {
  DoseSlot? upcoming;
  for (final slot in slots) {
    switch (slot.stateAt(now)) {
      case DoseState.due:
        return slot;
      case DoseState.upcoming:
        upcoming ??= slot;
      case DoseState.taken || DoseState.missed:
        break;
    }
  }
  return upcoming;
}

/// Whether [slot] can be recorded at [now]: due, or coming inside the window
/// the server already counts a record against — the same rule as the
/// pharmacy screen's button.
bool canTakeAt(DoseSlot slot, DateTime now) => switch (slot.stateAt(now)) {
  DoseState.due => true,
  DoseState.upcoming =>
    slot.scheduledAt.difference(now.toUtc()) <= DoseSlot.takenWindow,
  DoseState.taken || DoseState.missed => false,
};

/// "صيدلية العائلة والجرعات".
class PharmacyGlanceCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(pharmacyControllerProvider);
    final now = ref.read(nowProvider)();
    final medicines = view.medicines;
    final adherence = view.adherence;
    final next = nextDoseOf(view.today, now);

    final label = medicines.isEmpty
        ? 'مفيش أدوية مسجّلة'
        : adherence != null
        ? 'الالتزام بالجرعات: $adherence% • '
              '${adherence >= 80 ? 'منتظم' : 'محتاج انتباه'}'
        : '${medicines.length} دواء نشط • لسه بنجمّع بيانات الالتزام';
    final labelColor = medicines.isEmpty || adherence == null
        ? null
        : adherence < 80
        ? ZadColors.mustardOchre
        : ZadColors.forestEmerald;

    void open() => showHouseholdSection(context, HouseholdSection.pharmacy);

    return _GlanceShell(
      children: <Widget>[
        _GlanceHeader(
          icon: ZadIcons.pharmacy,
          tint: ZadColors.terracottaRust,
          title: 'صيدلية العائلة والجرعات',
          subtitle: label,
          subtitleColor: labelColor,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (medicines.isNotEmpty) _AdherenceRing(percent: adherence),
              _OpenLink(
                label: 'فتح الصيدلية ←',
                color: ZadColors.terracottaRust,
                onTap: open,
              ),
            ],
          ),
        ),
        if (next != null)
          _NextDose(
            slot: next,
            canTake: canTakeAt(next, now),
            onTake: () => unawaited(
              ref.read(pharmacyControllerProvider.notifier).take(next),
            ),
          ),
        if (medicines.isEmpty)
          const ZadEmptyState(
            icon: ZadIcons.pharmacy,
            title: 'الصيدلية فاضية',
            message:
                'صوّر شريط الدواء أو ضيفه يدوي، وزاد هيفكّرك بمواعيد الجرعات '
                'وينبّهك قبل ما يخلص',
          )
        else
          for (final m in medicines.take(3)) _MedicineRow(medicine: m),
      ],
    );
  }
}

class _AdherenceRing extends StatelessWidget {
  const new({required this.percent});

  final int? percent;

  @override
  Widget build(BuildContext context) {
    final shown = (percent ?? 100).clamp(0, 100);
    final color = percent == null
        ? ZadColors.outlineVariant
        : shown >= 80
        ? ZadColors.forestEmerald
        : ZadColors.mustardOchre;
    return SizedBox.square(
      dimension: 46,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(5),
            child: CircularProgressIndicator(
              value: shown / 100,
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: color.withValues(alpha: 0.16),
            ),
          ),
          Text(
            percent == null ? '--' : '$percent%',
            style: ZadType.labelSmall.copyWith(
              color: percent == null ? ZadColors.slate : color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextDose extends StatelessWidget {
  const new({required this.slot, required this.canTake, required this.onTake});

  final DoseSlot slot;
  final bool canTake;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    final t = slot.time;
    final at =
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: ZadColors.terracottaRust.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ZadColors.terracottaRust.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: ZadColors.terracottaRust.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(
              dimension: 28,
              child: Icon(
                ZadIcons.pharmacy,
                size: 16,
                color: ZadColors.terracottaRust,
              ),
            ),
          ),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'الجرعة التالية',
                  style: ZadType.labelSmall.copyWith(
                    color: ZadColors.terracottaRust,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${slot.medicine.name} • $at',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (canTake)
            FilledButton.icon(
              onPressed: onTake,
              style: FilledButton.styleFrom(
                backgroundColor: ZadColors.terracottaRust,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(ZadIcons.selected, size: 14),
              label: const Text('خدت الجرعة'),
            ),
        ],
      ),
    );
  }
}

class _MedicineRow extends StatelessWidget {
  const new({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    // The row's own dose, never an invented "جرعة منتظمة" — Kotlin's fix,
    // kept.
    final dosage = medicine.dosage;
    final note = dosage != null && dosage.trim().isNotEmpty
        ? dosage
        : '${medicine.dailyDoseCount ?? 1} جرعة يومياً';
    final low = medicine.isOutOfStock || medicine.isRunningOut;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: ZadColors.surfaceLow,
        borderRadius: BorderRadius.circular(ZadRadii.chip),
      ),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: low ? ZadColors.mustardOchre : ZadColors.forestEmerald,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 8),
          ),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: Text(
              medicine.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZadType.bodyMedium.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            note,
            style: ZadType.labelMedium.copyWith(color: ZadColors.slate),
          ),
        ],
      ),
    );
  }
}

// ── 3. Subscriptions ────────────────────────────────────────────────────────

/// "الاشتراكات الشهرية": the monthly total, the next renewal, a proportional
/// bar and the three largest-first rows.
class SubscriptionsGlanceCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  static const List<Color> _accents = <Color>[
    ZadColors.info,
    ZadColors.forestEmerald,
    ZadColors.mustardOchre,
    ZadColors.outline,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(subscriptionsControllerProvider);
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final active = view.active.toList();
    final total = view.monthlyTotal;
    // `items` is sorted soonest first, so the first running row is the next
    // charge.
    final next = active.isEmpty ? null : active.first;
    final nextDate = next?.nextRenewalFrom(view.today);

    void open() => showSubscriptionsScreen(context);

    return _GlanceShell(
      children: <Widget>[
        _GlanceHeader(
          icon: ZadIcons.card,
          tint: ZadColors.info,
          title: 'الاشتراكات الشهرية',
          subtitle: active.isEmpty
              ? 'مفيش اشتراكات مسجّلة'
              : 'إجمالي شهري: ${_money(total)} $currency'.trim(),
          trailing: _OpenLink(
            label: 'عرض الكل ←',
            color: ZadColors.info,
            onTap: open,
          ),
        ),
        if (active.isEmpty)
          const ZadEmptyState(
            icon: ZadIcons.card,
            title: 'مفيش اشتراكات لسه',
            message:
                'ضيف اشتراكاتك الشهرية عشان زاد يحسبها في المتاح ويفكّرك '
                'بمواعيد التجديد',
          )
        else ...<Widget>[
          if (next != null && nextDate != null)
            _NextRenewal(
              title: next.title,
              when: DateFormat.MMMMd('ar').format(nextDate),
              amount: '${_money(next.amount)} $currency'.trim(),
            ),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(ZadRadii.pill),
              child: SizedBox(
                height: 6,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (var i = 0; i < active.length && i < 4; i++)
                      Expanded(
                        flex:
                            (1000 *
                                    (active[i].monthlyCost / total).clamp(
                                      0.06,
                                      1,
                                    ))
                                .round(),
                        child: ColoredBox(color: _accents[i]),
                      ),
                  ],
                ),
              ),
            ),
          for (var i = 0; i < active.length && i < 3; i++)
            _SubscriptionRow(
              sub: active[i],
              accent: _accents[i],
              share: total > 0 ? active[i].monthlyCost / total : null,
              currency: currency,
            ),
        ],
      ],
    );
  }
}

class _NextRenewal extends StatelessWidget {
  const new({required this.title, required this.when, required this.amount});

  final String title;
  final String when;
  final String amount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md, vertical: 9),
    decoration: BoxDecoration(
      color: ZadColors.info.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ZadColors.info.withValues(alpha: 0.22)),
    ),
    child: Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: ZadColors.info.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const SizedBox.square(
            dimension: 26,
            child: Icon(ZadIcons.duration, size: 14, color: ZadColors.info),
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'التجديد القادم: $title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZadType.labelLarge.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                when,
                style: ZadType.labelSmall.copyWith(color: ZadColors.slate),
              ),
            ],
          ),
        ),
        Text(
          'القسط: $amount',
          style: ZadType.labelLarge.copyWith(
            color: ZadColors.info,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _SubscriptionRow extends StatelessWidget {
  const new({
    required this.sub,
    required this.accent,
    required this.share,
    required this.currency,
  });

  final Subscription sub;
  final Color accent;
  final double? share;
  final String currency;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: ZadSpacing.md,
      vertical: 10,
    ),
    decoration: BoxDecoration(
      color: ZadColors.surfaceLow,
      borderRadius: BorderRadius.circular(ZadRadii.chip),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            sub.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ZadType.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (share case final double s) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${(s * 100).toInt()}%',
              style: ZadType.labelSmall.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          '${_money(sub.amount)} $currency'.trim(),
          style: ZadType.bodyMedium.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
