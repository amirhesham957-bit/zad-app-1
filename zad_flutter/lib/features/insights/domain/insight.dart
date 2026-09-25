/// One row of `zad_insights`: something the brain noticed and wants the
/// customer to see — an insight, a question it needs answered, an alert.
///
/// `emit_insight` in zad-brain writes them with a surface (`home_card`,
/// `bell`, `voice`) and a priority (`normal`, `critical`). Kotlin shows the
/// home_card ones on Home and speaks the voice ones; this client has no voice,
/// so a voice insight is shown as a card rather than lost.
library;

import 'package:flutter/foundation.dart';

/// An insight.
@immutable
class ZadInsight {
  /// Creates an insight.
  const new({
    required this.id,
    required this.title,
    required this.body,
    this.kind = 'insight',
    this.surface = 'home_card',
    this.priority = 'normal',
    this.aboutItem,
    this.createdAt,
  });

  /// Reads a row.
  factory fromJson(Map<String, dynamic> json) => ZadInsight(
    id: json['id'] as String,
    title: ((json['title'] as String?) ?? '').trim(),
    body: ((json['body'] as String?) ?? '').trim(),
    kind: (json['kind'] as String?) ?? 'insight',
    surface: (json['surface'] as String?) ?? 'home_card',
    priority: (json['priority'] as String?) ?? 'normal',
    aboutItem: json['about_item'] as String?,
    createdAt: switch (json['created_at']) {
      final String s => DateTime.parse(s).toUtc(),
      _ => null,
    },
  );

  /// The row id.
  final String id;

  /// The headline.
  final String title;

  /// The text.
  final String body;

  /// `insight`, `question` or `alert`.
  final String kind;

  /// Where the brain meant it to appear.
  final String surface;

  /// `normal` or `critical`.
  final String priority;

  /// What it is about — a medicine, a subscription — when the brain said.
  final String? aboutItem;

  /// When it was written.
  final DateTime? createdAt;

  /// A question the brain needs answered.
  bool get isQuestion => kind == 'question';

  /// Critical.
  bool get isCritical => priority == 'critical';

  /// The tag on its card.
  String get kindLabel => switch (kind) {
    'question' => 'سؤال',
    'alert' => 'تنبيه',
    _ => 'معلومة',
  };

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'body': body,
    'kind': kind,
    'surface': surface,
    'priority': priority,
    'about_item': aboutItem,
    'created_at': createdAt?.toIso8601String(),
  };
}

/// How many cards Home shows — Kotlin's three.
const int kHomeInsightLimit = 3;

/// The insights Home shows: any surface (this client has no bell list of its
/// own for them and no voice), critical first, then newest.
List<ZadInsight> homeInsights(List<ZadInsight> pending) {
  final sorted = [...pending]
    ..sort((a, b) {
      if (a.isCritical != b.isCritical) return a.isCritical ? -1 : 1;
      final at = a.createdAt;
      final bt = b.createdAt;
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });
  return sorted.take(kHomeInsightLimit).toList();
}

/// Why the customer dismissed an insight (Task 28). The wire values are what
/// zad-brain's snapshot reads: `not_relevant` and `wrong_data` join its
/// permanent dismissed keys; `timing` is left out on purpose, so the same
/// insight may come back later.
enum DismissReason {
  /// Not interested in this kind of thing.
  notRelevant('not_relevant', 'مش مهم ليا'),

  /// The figure in it is wrong.
  wrongData('wrong_data', 'الرقم غلط'),

  /// Already knew.
  timing('timing', 'عرفت خلاص');

  new(this.wire, this.label);

  /// What `dismiss_reason` stores.
  final String wire;

  /// What the customer taps.
  final String label;
}

/// The memory note a dismissal leaves for the brain — copied word for word
/// from Kotlin's `DismissalMemory`, because the brain reads these notes back
/// and the two clients must teach it the same thing.
({String scope, String note, double confidence}) dismissalNote(
  DismissReason reason,
  ZadInsight insight,
) {
  final subject = insight.aboutItem ?? insight.title;
  return switch (reason) {
    DismissReason.notRelevant => (
      scope: 'dismissal',
      note: 'مش مهتم بتنبيهات زي "$subject"',
      confidence: 0.5,
    ),
    DismissReason.wrongData => (
      scope: 'data_quality',
      note: 'العميل قال إن "$subject" غلط — البيانات المصدر محتاجة مراجعة',
      confidence: 0.7,
    ),
    DismissReason.timing => (
      scope: 'dismissal',
      note: 'عرف بالفعل عن "$subject" وقت الرفض ده',
      confidence: 0.3,
    ),
  };
}

/// The chat message an answer to a brain question becomes. It goes through
/// the agent like anything the customer types, so the brain acts on it with
/// its own tools and the reply is on screen.
String answerMessage(ZadInsight question, String answer) =>
    'ردًا على سؤالك «${question.title}»: ${answer.trim()}';
