/// The line «اقفل يومك» opens with: what Zad saw today. The same words as the
/// server's template (`zad-brain/voiceMoments.ts`, `close_day`), so the
/// message at 9:30 and the card on home say one thing.
library;

/// One expense seen today.
typedef SeenExpense = ({String name, double amount});

/// «النهارده شفت ٣ حاجات: قهوة 50، … فيه حاجة كاش؟», newest first, three
/// named at most.
String closeDayLine(List<SeenExpense> seen, {String? currency}) {
  if (seen.isEmpty) return 'النهارده ماشفتش ولا مصروف. صرفت حاجة كاش؟';
  final cur = currency == null || currency.isEmpty ? '' : ' $currency';
  final listed = seen
      .take(3)
      .map(
        (s) => '${s.name.isEmpty ? 'مصروف' : s.name} ${s.amount.round()}$cur',
      )
      .join('، ');
  final count = seen.length;
  final more = count - 3;
  final things = switch (count) {
    1 => 'حاجة واحدة',
    2 => 'حاجتين',
    <= 10 => '$count حاجات',
    _ => '$count حاجة',
  };
  return 'النهارده شفت $things: $listed${more > 0 ? ' وكمان $more' : ''}. '
      'فيه حاجة كاش؟';
}

/// What the sheet says after a close. [xp] 0 = no points this time.
String closeDayThanks({
  required bool already,
  required int xp,
  required bool petAte,
}) {
  if (already) return 'يومك متقفل خلاص ✅';
  final points = xp > 0 ? ' +$xp نقطة لرفيقك' : '';
  final dinner = petAte ? '، واتعشى 🍽️' : '';
  return 'يومك اتقفل ✅$points$dinner';
}
