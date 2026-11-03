/// رفيق زاد's little stories (ZAD_PLAN ٥.٣): «حلمت بالليل…» in the morning,
/// a weekly word about the week, and both growing up with it — a young pet
/// talks small, a grown one talks wise. Each is a template over real data
/// (yesterday's biggest expense, the days logged this week); none calls a
/// model, none scolds about money, and the dream is told as the pet's dream,
/// a character's fiction, never as Zad claiming to be a person.
library;

import 'dart:math' as math;

import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// Mornings, on the account's clock, when the pet tells its dream.
bool isDreamHour(int hour) => hour >= 5 && hour < 12;

/// A pet from this stage on talks like a grown one.
bool isGrown(CompanionStage stage) => stage.index >= 2;

/// What the pet says, in [ZadL10n]'s language (Arabic by default).
abstract final class PetStories {
  /// Last night's dream, from [yesterday]'s biggest expense; null without
  /// one — no dream is made up about a day with nothing logged.
  static String? dream({
    required List<ZadTransaction> yesterday,
    required CompanionStage stage,
    math.Random? rng,
    ZadL10n? l10n,
  }) {
    final spent = yesterday
        .where((t) => t.kind == TxnKind.expense && t.isExpense && t.amount > 0)
        .toList();
    if (spent.isEmpty) return null;
    spent.sort((a, b) => b.amount.compareTo(a.amount));
    final top = spent.first;
    final what = (top.merchantName?.trim().isNotEmpty ?? false)
        ? top.merchantName!.trim()
        : top.title.trim();
    if (what.isEmpty) return null;
    final l = l10n ?? zadL10nArabic;
    final first = (rng ?? math.Random()).nextInt(2) == 0;
    if (isGrown(stage)) {
      return first ? l.petDreamTalked(what) : l.petDreamMarket(what);
    }
    return first ? l.petDreamChased(what) : l.petDreamPlayed(what);
  }

  /// The weekly word: [days] of [goal] days logged this week.
  static String weekly({
    required int days,
    required int goal,
    required CompanionStage stage,
    math.Random? rng,
    ZadL10n? l10n,
  }) {
    final l = l10n ?? zadL10nArabic;
    final grown = isGrown(stage);
    if (days >= goal) {
      return grown ? l.petWeekGoalGrown(days) : l.petWeekGoalYoung(days);
    }
    if (days > 0) {
      return grown ? l.petWeekSomeGrown(days) : l.petWeekSomeYoung(days);
    }
    return grown ? l.petWeekNoneGrown : l.petWeekNoneYoung;
  }
}
