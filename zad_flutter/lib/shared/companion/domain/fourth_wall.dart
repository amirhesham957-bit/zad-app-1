/// رفيق زاد breaks the fourth wall (ZAD_PLAN ٥.٢): it notices you were
/// away, what time it is, that you are looking at the prices, and that you
/// keep poking it. Every line is built from something real on the phone —
/// the last time it saw you, the account's clock, the tap count — and none
/// calls a model, so it can speak the moment the app opens.
///
/// The weather the plan also names needs a location and a network call on
/// open; it is left for the server (zad-brain's weather.ts) to bring.
library;

import 'dart:math' as math;

/// A pause this long ends a burst of taps.
const Duration tapBurstWindow = Duration(seconds: 4);

/// A burst this long gets a line instead of the care sheet.
const int tapBurstMin = 5;

/// Away less than this is just a moment; the two-day sleep
/// (`companion_moments.dart`) takes over from 48 hours.
const Duration awayMin = Duration(hours: 6);

/// What the pet says to each of these, or null when nothing applies.
abstract final class FourthWall {
  /// [count] taps in a row: from [tapBurstMin] on, it says so, with the
  /// number.
  static String? poked(int count, {required String name, math.Random? rng}) {
    if (count < tapBurstMin) return null;
    if (count >= 12) return 'خلاص! $count مرة؟ هشتكيك لزاد 😂';
    final lines = count >= 8
        ? <String>[
            'إنت بتعدّ ولا إيه؟ دي $count مرة 😵‍💫',
            'الشاشة هتتعب مني ومنك 😅 $count دوسة!',
          ]
        : <String>[
            'بتدغدغني! 🤭 كفاية…',
            'أنا مش زرار على فكرة 😤',
            '$name اتزغلل من كتر الدوس 😵',
          ];
    return lines[(rng ?? math.Random()).nextInt(lines.length)];
  }

  /// Back after [away] (the phone's last sight of the pet): six hours to two
  /// days. Shorter is nothing; longer is the sleep moment's.
  static String? back(Duration away, {math.Random? rng}) {
    if (away < awayMin || away >= const Duration(hours: 48)) return null;
    final hours = away.inHours;
    final lines = hours >= 24
        ? <String>[
            'بقالك يوم كامل مش هنا! فكرتك نسيتني 🥺',
            'يوم بحاله؟ كنت قاعد أعدّ البلاط 🥲',
          ]
        : <String>[
            'غبت $hours ساعة… مش إنك وحشتني ولا حاجة 😌',
            'رجعت! $hours ساعة وأنا باصص على الباب 👀',
          ];
    return lines[(rng ?? math.Random()).nextInt(lines.length)];
  }

  /// The account's [hour] (0–23): the small hours and the early morning.
  static String? clock(int hour, {math.Random? rng}) {
    final lines = switch (hour) {
      >= 0 && < 4 => <String>[
        'الساعة $hour بالليل! بتعمل إيه صاحي؟ 👀',
        'إحنا الاتنين صاحيين الساعة $hour… سرّنا 🤫',
      ],
      >= 4 && < 7 => <String>[
        'صاحي بدري… ولا لسه مانمتش؟ 🌅',
        'الفجر لسه طالع وإنت هنا؟ برافو 🌄',
      ],
      _ => null,
    };
    if (lines == null) return null;
    return lines[(rng ?? math.Random()).nextInt(lines.length)];
  }

  /// On the subscription screen.
  static String paywall({required String name, math.Random? rng}) {
    final lines = <String>[
      'أنا شايفك بتبص على الأسعار 👀 خد وقتك',
      'مش هضغط عليك… بس $name هيفرح أوي 🥹',
      'متقلقش، أنا معاك في الحالتين 💚',
    ];
    return lines[(rng ?? math.Random()).nextInt(lines.length)];
  }
}
