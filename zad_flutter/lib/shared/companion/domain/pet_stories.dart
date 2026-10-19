/// رفيق زاد's little stories (ZAD_PLAN ٥.٣): «حلمت بالليل…» in the morning,
/// a weekly word about the week, and both growing up with it — a young pet
/// talks small, a grown one talks wise. Each is a template over real data
/// (yesterday's biggest expense, the days logged this week); none calls a
/// model, none scolds about money, and the dream is told as the pet's dream,
/// a character's fiction, never as Zad claiming to be a person.
library;

import 'dart:math' as math;

import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// Mornings, on the account's clock, when the pet tells its dream.
bool isDreamHour(int hour) => hour >= 5 && hour < 12;

/// A pet from this stage on talks like a grown one.
bool isGrown(CompanionStage stage) => stage.index >= 2;

/// What the pet says.
abstract final class PetStories {
  /// Last night's dream, from [yesterday]'s biggest expense; null without
  /// one — no dream is made up about a day with nothing logged.
  static String? dream({
    required List<ZadTransaction> yesterday,
    required CompanionStage stage,
    math.Random? rng,
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
    const told = 'وفهمت إنك كنت محتاجه 🌙';
    final talked = 'حلمت بالليل إن «$what» قعد يحكيلي عن امبارح… $told';
    final market = 'حلمت إني ماشي في سوق كبير، وكل محل اسمه «$what» 😄';
    final lines = isGrown(stage)
        ? <String>[talked, '$market امبارح كان يومه']
        : <String>[
            'حلمت بالليل إن «$what» بيجري ورايا 😱🌙',
            'حلمت إني بلعب مع «$what» 🤭 هو كان أكبر حاجة امبارح',
          ];
    return lines[(rng ?? math.Random()).nextInt(lines.length)];
  }

  /// The weekly word: [days] of [goal] days logged this week.
  static String weekly({
    required int days,
    required int goal,
    required CompanionStage stage,
    math.Random? rng,
  }) {
    final grown = isGrown(stage);
    final List<String> lines;
    if (days >= goal) {
      lines = grown
          ? <String>['$days أيام من ٧ الأسبوع ده… ده بيت بيعرف طريقه 💚']
          : <String>['$days أيام الأسبوع ده! أنا كبرت من الفرحة 🎉'];
    } else if (days > 0) {
      lines = grown
          ? <String>['سجّلنا $days أيام الأسبوع ده. خطوة خطوة بنوصل 🌱']
          : <String>['$days أيام سجّلناهم سوا! نكمّل؟ 🥰'];
    } else {
      lines = grown
          ? <String>['أسبوع جديد، صفحة بيضا. أنا هنا لما تحب 💚']
          : <String>['أسبوع جديد! نلعب لعبة «سجّل مصروف»؟ 🌱'];
    }
    return lines[(rng ?? math.Random()).nextInt(lines.length)];
  }
}
