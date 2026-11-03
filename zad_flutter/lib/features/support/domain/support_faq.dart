/// Answers to the questions customers actually ask, for when the assistant
/// cannot be reached.
///
/// The support screen answered every question with «عذراً، لم أتمكن من
/// معالجة طلبك» whenever the model was down or out of quota — exactly when
/// people most need help. These are matched by keywords; the keyword lists
/// are matching data and stay Arabic (CLAUDE.md, i18n); the answers
/// are in the ARB files.
library;

import 'package:zad/core/l10n/l10n.dart';

typedef _Faq = ({List<String> keys, String Function(ZadL10n) answer});

// l10n: data-begin
final List<_Faq> _faqs = <_Faq>[
  (
    keys: <String>[
      'إشعار',
      'اشعار',
      'البنك',
      'بنك',
      'رسايل',
      'رسائل',
      'مقيد',
      'مقيّد',
      'رمادي',
    ],
    answer: (l) => l.supportFaqBank,
  ),
  (
    keys: <String>[
      'مصروف',
      'رصيد الطفل',
      'ابني',
      'بنتي',
      'الأطفال',
      'اطفال',
      'عيال',
    ],
    answer: (l) => l.supportFaqAllowance,
  ),
  (
    keys: <String>['فاتورة', 'فاتوره', 'كاميرا', 'مسح', 'صورة'],
    answer: (l) => l.supportFaqReceipt,
  ),
  (
    keys: <String>['بلد', 'دولة', 'عملة', 'السوق'],
    answer: (l) => l.supportFaqCountry,
  ),
  (
    keys: <String>['صوت', 'مايك', 'ميكروفون', 'بيرد', 'اتكلم', 'كلمته'],
    answer: (l) => l.supportFaqVoice,
  ),
  (
    keys: <String>['ميعاد', 'مواعيد', 'تذكير', 'دكتور', 'دوا', 'دواء', 'جرعة'],
    answer: (l) => l.supportFaqAppointments,
  ),
  (
    keys: <String>['العيلة', 'العائلة', 'انضم', 'كود', 'دعوة'],
    answer: (l) => l.supportFaqFamily,
  ),
  (
    keys: <String>['باسورد', 'كلمة السر', 'كلمة المرور', 'نسيت'],
    answer: (l) => l.supportFaqPassword,
  ),
  (
    keys: <String>['حذف الحساب', 'احذف حسابي', 'الغي الحساب', 'امسح حسابي'],
    answer: (l) => l.supportFaqDeleteAccount,
  ),
];
// l10n: data-end

/// The built-in answer to [question], or null when none fits. The entry
/// with the most keyword hits wins; a tie goes to the earlier entry.
String? faqAnswer(String question, {ZadL10n? l10n}) {
  final q = question.trim();
  if (q.isEmpty) return null;
  _Faq? best;
  var bestHits = 0;
  for (final faq in _faqs) {
    final hits = faq.keys.where(q.contains).length;
    if (hits > bestHits) {
      best = faq;
      bestHits = hits;
    }
  }
  return best?.answer(l10n ?? zadL10nArabic);
}
