/// Kotlin's `UrgentRecipeCard` (`HomeScreen.kt`), «العقل → الوصفات»: items
/// that are about to run out or expire — or that sit untouched (Task 23) —
/// with a way into زاد's chat for recipes that use them.
///
/// The trigger items are Kotlin's `generateUrgentRecipes` selection, computed
/// on the phone: up to three stagnant items first, then items expiring within
/// five days or predicted to run out within two, five in all. Kotlin also
/// asks the model for recipes on every pantry change and prints the answer
/// in the card; under the owner's standing decision that call happens only
/// when the customer asks, so the tap puts the question in the chat composer
/// instead, and the card shows no model text.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/tokens/zad_extended_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/features/insights/application/local_insights.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/data/consumption_learner.dart';

/// What the card is about.
typedef UrgentItems = ({List<String> triggers, bool stagnantOnly});

/// Kotlin's trigger selection, or null when nothing is urgent.
final urgentRecipeItemsProvider = Provider<UrgentItems?>((ref) {
  final items = ref.watch(pantryControllerProvider.select((v) => v.items));
  ref.watch(checkInRevisionProvider);
  final learner = ref.read(consumptionLearnerProvider);
  final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
  final local = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);
  final today = DateTime.utc(local.year, local.month, local.day);

  final stagnant = <String>{
    for (final i in items)
      if (i.quantity > 0 && learner.isStagnant(i)) i.itemName,
  }.take(3).toList();

  bool urgentItem(int? expiryDays, int? daysLeft) =>
      (expiryDays != null && expiryDays >= 0 && expiryDays <= 5) ||
      (daysLeft != null && daysLeft >= 0 && daysLeft <= 2);

  final urgent = <String>{
    for (final i in items)
      if (i.quantity > 0 &&
          !stagnant.contains(i.itemName) &&
          urgentItem(
            i.daysUntilExpiry(today),
            learner.predictDaysLeft(i.itemName),
          ))
        i.itemName,
  }.take(5 - stagnant.length).toList();

  if (stagnant.isEmpty && urgent.isEmpty) return null;
  final triggers = <String>{...stagnant, ...urgent}.toList();
  return (
    triggers: triggers,
    stagnantOnly: stagnant.isNotEmpty && stagnant.length == triggers.length,
  );
});

/// The card, when there is something urgent (with Kotlin's 18dp under it).
class UrgentRecipeSlot extends ConsumerWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urgent = ref.watch(urgentRecipeItemsProvider);
    if (urgent == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: UrgentRecipeCard(
        triggerItems: urgent.triggers,
        isStagnantOnly: urgent.stagnantOnly,
        onOpenChat: () {
          ref
              .read(chatPrefillProvider.notifier)
              .offer(
                'اقترح وصفات بـ ${urgent.triggers.join('، ')} '
                'قبل ما ${urgent.stagnantOnly ? 'تتلف' : 'تخلص'}',
              );
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
          );
        },
      ),
    );
  }
}

/// Kotlin's `UrgentRecipeCard`.
class UrgentRecipeCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.triggerItems,
    required this.onOpenChat,
    this.isStagnantOnly = false,
    super.key,
  });

  /// The items.
  final List<String> triggerItems;

  /// All of them stagnant — the headline changes (Task 23).
  final bool isStagnantOnly;

  /// Into the chat.
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final names = triggerItems.take(2).join('، ');
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenChat,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.tertiary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.hourglass_top,
                      size: 18,
                      color: scheme.tertiary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isStagnantOnly
                              ? 'عندك $names من فترة وماستخدمتهاش 🤔'
                              : 'عندك $names هيخلص قريب 👀',
                          style: ZadType.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                        Text(
                          isStagnantOnly
                              ? 'وصفات تساعدك تستخدمها قبل ما تتلف'
                              : 'وصفات مقترحة بيه قبل ما يضيع',
                          style: ZadType.labelSmall.copyWith(
                            color: scheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'اضغط للمزيد في شات زاد ←',
                style: ZadType.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.tertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `AiAlertBanner`: the first local Alert/Warning insight, on the
/// theme's alert pair, with Kotlin's 18dp under it.
class AiAlertBannerSlot extends ConsumerWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertInsightsProvider);
    if (alerts.isEmpty) return const SizedBox.shrink();
    final first = alerts.first;
    final ext = context.zadExt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: ZadListCard(
        color: ext.alertBannerContainer,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Icon(Icons.warning, size: 32, color: ext.onAlertBanner),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      first.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ext.onAlertBanner,
                      ),
                    ),
                    Text(
                      first.description,
                      style: ZadType.labelMedium.copyWith(
                        color: ext.onAlertBanner,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
