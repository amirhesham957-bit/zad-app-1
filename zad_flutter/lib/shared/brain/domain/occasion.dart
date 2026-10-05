/// The day's occasion — New Year, Ramadan, the two Eids, the Hijri new year,
/// Mother's Day — and the one thing زاد offers to do about it
/// (docs/agent/ZAD_LIVING_BRAIN.md slice 22, owner 2026-10-04: «سنة جديدة
/// سعيدة! حابب زاد يجهزلك خطة الأهداف المالية لسنة 2027 بنقرة واحدة؟»).
///
/// Pure and offline: the card shows on the first open of the day with no
/// network and no model call (CLAUDE.md). The Hijri days are Umm al-Qura, the
/// same calendar as the server's `_shared/season.ts`, generated from it for
/// 2026–2031; moon sighting can shift a day, as the server says too.
library;

import 'package:flutter/foundation.dart';
import 'package:zad/shared/brain/domain/memory_occasion.dart';

/// Which occasion.
enum OccasionKind {
  /// January 1st.
  newYear,

  /// 1 Ramadan.
  ramadan,

  /// 1 Shawwal.
  eidFitr,

  /// 10 Dhul Hijjah.
  eidAdha,

  /// 1 Muharram.
  hijriNewYear,

  /// March 21st, Mother's Day across the Arab markets.
  mothersDay,

  /// Someone's birthday زاد remembers (`personalOccasionOn`).
  birthday,

  /// A wedding anniversary زاد remembers.
  anniversary,
}

/// The occasion, as the card says it.
@immutable
class Occasion {
  /// Creates an occasion.
  const new({
    required this.kind,
    required this.id,
    required this.title,
    required this.question,
    required this.actionLabel,
    required this.prompt,
  });

  /// Which.
  final OccasionKind kind;

  /// Once per occasion and year: `new_year:2027-01-01`.
  final String id;

  /// The greeting.
  final String title;

  /// The offer.
  final String question;

  /// The button that does it.
  final String actionLabel;

  /// What is sent to زاد on that tap — data for the brain, in the
  /// customer's words.
  final String prompt;
}

/// Umm al-Qura days, from `_shared/season.ts` (generated 2026-10-04).
const Map<OccasionKind, List<String>> kHijriOccasionDays =
    <OccasionKind, List<String>>{
      OccasionKind.ramadan: <String>[
        '2026-02-18', '2027-02-08', '2028-01-28', '2029-01-16', //
        '2030-01-05', '2030-12-26', '2031-12-16',
      ],
      OccasionKind.eidFitr: <String>[
        '2026-03-20', '2027-03-09', '2028-02-26', '2029-02-14', //
        '2030-02-04', '2031-01-24',
      ],
      OccasionKind.eidAdha: <String>[
        '2026-05-27', '2027-05-16', '2028-05-05', '2029-04-24', //
        '2030-04-13', '2031-04-02',
      ],
      OccasionKind.hijriNewYear: <String>[
        '2026-06-16', '2027-06-06', '2028-05-25', '2029-05-14', //
        '2030-05-04', '2031-04-23',
      ],
    };

const Set<String> _gulf = <String>{'SA', 'AE', 'KW', 'QA', 'BH', 'OM'};

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The occasion on [day] (the account's local calendar day), in the
/// market's dialect, or null.
Occasion? occasionOn(DateTime day, {String? country}) {
  final date = _iso(day);
  final gulf = _gulf.contains(country?.toUpperCase());
  final kind = switch ((day.month, day.day)) {
    (1, 1) => OccasionKind.newYear,
    (3, 21) => OccasionKind.mothersDay,
    _ => <OccasionKind>[
      OccasionKind.ramadan,
      OccasionKind.eidFitr,
      OccasionKind.eidAdha,
      OccasionKind.hijriNewYear,
    ].where((k) => kHijriOccasionDays[k]!.contains(date)).firstOrNull,
  };
  if (kind == null) return null;
  final id = '${kind.name}:$date';
  final year = day.year;
  return switch (kind) {
    OccasionKind.newYear => Occasion(
      kind: kind,
      id: id,
      title: 'سنة جديدة سعيدة! 🎉',
      question: gulf
          ? 'تبي زاد يجهّز لك خطة أهدافك المالية لسنة $year بضغطة وحدة؟'
          : 'حابب زاد يجهّزلك خطة أهدافك المالية لسنة $year بنقرة واحدة؟',
      actionLabel: 'جهّزها',
      prompt:
          'جهّزلي خطة أهداف مالية لسنة $year من أرقامي ومصاريفي الفعلية، '
          'واقترح عليا الأهداف أأكدها أنا.',
    ),
    OccasionKind.ramadan => Occasion(
      kind: kind,
      id: id,
      title: 'رمضان كريم 🌙',
      question: gulf
          ? 'أجهّز لك قائمة مقاضي رمضان من الناقص في البيت؟'
          : 'أجهّزلك قايمة مشتريات رمضان من اللي ناقص في البيت؟',
      actionLabel: 'جهّز القايمة',
      prompt:
          'جهّزلي قايمة مشتريات رمضان من اللي ناقص في البيت فعلاً، وضيفها '
          'لقايمة التسوق في حدود الميزانية.',
    ),
    OccasionKind.eidFitr => Occasion(
      kind: kind,
      id: id,
      title: 'عيد فطر سعيد! 🎈',
      question: gulf
          ? 'أسوي لك ميزانية العيد (عيدية ولبس وعزايم) من المتاح؟'
          : 'أعملك ميزانية للعيد (عيدية ولبس وعزومات) من المتاح؟',
      actionLabel: 'اعملها',
      prompt:
          'اعملي ميزانية لعيد الفطر: عيدية ولبس وعزومات، من المتاح عندي '
          'من غير ما تعدّي الميزانية.',
    ),
    OccasionKind.eidAdha => Occasion(
      kind: kind,
      id: id,
      title: 'عيد أضحى مبارك! 🐑',
      question: gulf
          ? 'أسوي لك ميزانية العيد من المتاح؟'
          : 'أعملك ميزانية للعيد من المتاح؟',
      actionLabel: 'اعملها',
      prompt:
          'اعملي ميزانية لعيد الأضحى من المتاح عندي — العيدية والعزومات، '
          'والأضحية لو بنضحّي.',
    ),
    OccasionKind.hijriNewYear => Occasion(
      kind: kind,
      id: id,
      title: 'سنة هجرية سعيدة 🌙',
      question: gulf
          ? 'نراجع أهدافك ونشوف وين وصلت؟'
          : 'نراجع أهدافك ونشوف ماشية إزاي؟',
      actionLabel: 'راجعها',
      prompt: 'راجع أهدافي وقولّي كل هدف ماشي إزاي، واقترح خطوة صغيرة للمتأخر.',
    ),
    OccasionKind.mothersDay => Occasion(
      kind: kind,
      id: id,
      title: 'كل سنة وكل أم بخير 💐',
      question: gulf
          ? 'تبي أقترح لك هدية لعيد الأم في حدود الميزانية؟'
          : 'تحب أقترح عليك هدية لعيد الأم جوه الميزانية؟',
      actionLabel: 'اقترح',
      prompt: 'اقترح عليا هدية لعيد الأم جوه الميزانية.',
    ),
    OccasionKind.birthday || OccasionKind.anniversary => null,
  };
}

/// A remembered birthday or anniversary on [day] or three days before it —
/// the same days the morning greeting speaks of (`zad-brain/occasions.ts`).
/// The customer's own birthday is not a card: it opens with the cake
/// (`BirthdayCelebration`). Today before three days ahead; null when none.
Occasion? personalOccasionOn(
  DateTime day,
  List<MemoryOccasion> remembered, {
  String? country,
}) {
  final gulf = _gulf.contains(country?.toUpperCase());
  MemoryOccasion? pick(int inDays) => remembered
      .where(
        (o) =>
            !(o.isOwn && o.kind == MemoryOccasionKind.birthday) &&
            o.daysFrom(day) == inDays,
      )
      .firstOrNull;
  final today = pick(0);
  final soon = today == null ? pick(3) : null;
  final o = today ?? soon;
  if (o == null) return null;
  final on = o.nextFrom(day);
  final label = occasionDateLabel(on);
  final when = today != null ? 'day' : 'before';
  final id = '${o.kind.name}:${o.forName ?? 'self'}:${_iso(on)}:$when';
  final ownAnniversary = o.isOwn && o.kind == MemoryOccasionKind.anniversary;
  if (ownAnniversary) {
    return today != null
        ? Occasion(
            kind: OccasionKind.anniversary,
            id: id,
            title: 'كل سنة وإنتو طيبين 💍',
            question: gulf
                ? 'تبي أقترح لكم طلعة الليلة في حدود الميزانية؟'
                : 'أقترحلكم خروجة الليلة في حدود الميزانية؟',
            actionLabel: 'اقترح',
            prompt:
                'النهارده ذكرى جوازنا — اقترحلي خروجة الليلة في حدود ميزانيتي.',
          )
        : Occasion(
            kind: OccasionKind.anniversary,
            id: id,
            title: 'ذكرى جوازكم بعد ٣ أيام 💍',
            question: gulf
                ? 'تبي أقترح لك هدية أو طلعة في حدود الميزانية؟'
                : 'أقترحلك هدية أو خروجة في حدود الميزانية؟',
            actionLabel: 'اقترح',
            prompt:
                'ذكرى جوازنا يوم $label. اقترحلي هدية أو خروجة في حدود '
                'ميزانيتي.',
          );
  }
  final kind = o.kind == MemoryOccasionKind.birthday
      ? OccasionKind.birthday
      : OccasionKind.anniversary;
  final what = o.kind == MemoryOccasionKind.birthday
      ? 'عيد ميلاد ${o.forName}'
      : 'ذكرى جواز ${o.forName}';
  return today != null
      ? Occasion(
          kind: kind,
          id: id,
          title: 'النهارده $what 🎂',
          question: gulf
              ? 'أكتب لك رسالة تهنئة ترسلها؟'
              : 'أكتبلك رسالة تهنئة حلوة تبعتها؟',
          actionLabel: 'اكتبها',
          prompt: 'النهارده $what — اكتبلي رسالة تهنئة قصيرة ودافية أبعتها.',
        )
      : Occasion(
          kind: kind,
          id: id,
          title: '$what بعد ٣ أيام 🎁',
          question: gulf
              ? 'تبي أقترح لك هدية في حدود الميزانية وأحجز مبلغها؟'
              : 'أقترحلك هدية في حدود الميزانية وأحجز مبلغها؟',
          actionLabel: 'اقترح هدية',
          prompt:
              '$what يوم $label. اقترحلي فكرتين هدية في حدود ميزانيتي، ولو '
              'وافقت احجز مبلغها كهدف لحد يومها.',
        );
}
