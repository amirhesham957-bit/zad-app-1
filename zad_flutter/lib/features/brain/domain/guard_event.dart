/// One refusal: a write that زاد's door (or a validator in front of it) turned
/// down, and why.
///
/// The rows are written by `zad_commit_intent` and the guard in `zad-brain`
/// (`zad_guard_events`). The reason is either a snake code the door answered
/// with (`qty_too_large`), or — for a refusal from a validator or a tool — the
/// Arabic sentence itself. [guardReasonLabel] reads both into words.
library;

import 'package:flutter/foundation.dart';

/// Arabic for every door refusal code. Copied from `REASONS` in
/// `supabase/functions/zad-brain/commitIntent.ts`; a code missing here shows
/// as the plain "الكتابة اترفضت", never as the raw identifier.
const Map<String, String> _doorReasons = <String, String>{
  'item_not_found': 'السجل ده مش موجود عندك',
  'name_invalid': 'اسم الصنف لازم يكون من ٢ لـ١٢٠ حرف',
  'qty_not_positive': 'الكمية لازم تكون أكبر من صفر',
  'qty_too_large': 'الكمية كبيرة بشكل مش منطقي — اتأكد من العميل',
  'qty_negative': 'الكمية مينفعش تبقى بالسالب',
  'category_unknown': 'الفئة مش من الفئات المعروفة',
  'expiry_bad_format': 'الصلاحية لازم تكون YYYY-MM-DD',
  'expiry_before_purchase': 'تاريخ الصلاحية قبل النهارده — اتأكد من العميل',
  'amount_invalid': 'الكمية المستعملة لازم تكون أكبر من صفر',
  'amount_too_large': 'الكمية المستعملة كبيرة بشكل مش منطقي',
  'restock_mode_unknown': 'النوع يا staple يا occasional',
  'already_purchased': 'السطر ده اتشطب من القايمة قبل كده',
  'member_not_granted': 'الفرد ده مش في العيلة أو مش موافق إنك تتابع أدويته',
  'patch_empty': 'مفيش حاجة تتعدل',
  'patch_field_unknown': 'الحقل ده مايتعدلش من هنا',
  'dose_times_invalid': 'مواعيد الجرعات لازم تكون HH:MM مفصولة بفاصلة',
  'dose_count_invalid': 'عدد الجرعات في اليوم من ١ لـ٢٤',
  'qty_invalid': 'الكمية لازم تكون رقم صحيح من ٠ لـ١٠٠٠٠',
  'dosage_too_long': 'الجرعة مكتوبة طويلة أوي',
  'dose_already_logged': 'الجرعة دي متسجلة قبل كده — الكمية ماتخصمتش تاني',
  'amount_not_positive': 'المبلغ لازم يكون رقم موجب',
  'amount_over_cap': 'المبلغ ده كبير بشكل غير منطقي — تأكد منه',
  'title_invalid': 'اكتب وصف قصير للمعاملة (لحد ٨٠ حرف)',
  'title_guessed':
      'الوصف ده تخمين — اسأل العميل الفلوس دي راحت على إيه قبل ما تسجلها',
  'txn_kind_unknown': 'النوع يا expense يا income',
  'wallet_unknown': 'المحفظة يا cash يا card يا bank',
  'transfer_to_missing': 'التحويل لازم يقول رايح فين',
  'transfer_change_unsupported':
      'التحويل مايتعملش بالتعديل — سجّله معاملة جديدة',
  'text_too_long': 'الفئة أو اسم المحل طويل أوي',
  'for_person_invalid': '«لمين» لازم يكون من ١ لـ٤٠ حرف',
  'date_invalid': 'تاريخ العملية مش مفهوم أو في المستقبل أو أقدم من سنة',
  'category_invalid': 'اسم الفئة لازم يكون من ٢ لـ٤٠ حرف',
  'no_category_budget': 'مفيش سقف على الفئة دي أصلاً',
  'subscription_title_invalid': 'اسم الاشتراك لازم يكون من ٢ لـ١٢٠ حرف',
  'renewal_date_invalid':
      'تاريخ التجديد لازم يكون تاريخ حقيقي بصيغة YYYY-MM-DD',
  'billing_cycle_invalid': 'دورة الدفع يا MONTHLY يا YEARLY',
  'due_day_invalid': 'يوم الاستحقاق لازم يكون من ١ لـ٣١',
  'is_active_invalid': 'التفعيل لازم يكون true أو false',
  'debt_name_invalid': 'اسم الدين لازم يكون من ٢ لـ١٢٠ حرف',
  'minimum_invalid': 'الحد الأدنى الشهري لازم يكون رقم مش سالب',
  'interest_invalid': 'نسبة الفايدة لازم تكون من ٠ لـ١٠٠٠',
  'balance_negative': 'الرصيد المتبقي مينفعش يبقى بالسالب',
  'obligation_title_invalid': 'اسم الالتزام لازم يكون من ٢ لـ١٢٠ حرف',
  'obligation_kind_invalid':
      'نوع الالتزام يا rent يا installment يا tuition يا utility يا other',
  'recurrence_invalid': 'التكرار يا monthly يا quarterly يا yearly يا once',
  'installments_invalid': 'عدد الأقساط لازم يكون رقم صحيح من ١ لـ٦٠٠',
  'already_inactive': 'الالتزام ده اتلغى قبل كده',
  'device_name_invalid': 'اسم الجهاز لازم يكون من ٢ لـ١٢٠ حرف',
  'device_category_invalid': 'فئة الجهاز طويلة أوي (٦٠ حرف بالكتير)',
  'day_invalid': 'التاريخ لازم يوم حقيقي بصيغة YYYY-MM-DD',
  'interval_invalid': 'الفاصل بين الصيانات لازم عدد أيام صحيح موجب',
  'cost_invalid': 'التكلفة لازم رقم موجب في الحدود المنطقية',
  'kind_invalid': 'النوع مش من الأنواع المعروفة',
  'holder_invalid':
      'اسم صاحب المستند لازم يكون من غير مسافات زيادة ولحد ٤٠ حرف',
  'label_invalid': 'اسم المستند لازم يكون من غير مسافات زيادة ولحد ٤٠ حرف',
  'label_required': 'مستند «other» محتاج اسم',
  'date_out_of_range': 'تاريخ الانتهاء مش معقول (بين ٢٠٠٠ و٢١٠٠)',
  'appt_title_invalid': 'اسم الميعاد لازم من ٢ لـ١٦٠ حرف',
  'starts_at_invalid': 'وقت الميعاد مش مفهوم',
  'appt_recurrence_invalid':
      'التكرار لازم once أو hourly أو daily أو weekly أو monthly',
  'source_invalid': 'مصدر الميعاد مش معروف',
  'remind_invalid': 'التذكير قبلها لازم دقايق صحيحة من ٠ لـ١٠٠٨٠',
  'place_too_long': 'اسم المكان طويل أوي (١٢٠ حرف بالكتير)',
  'status_invalid': 'الحالة لازم upcoming أو done أو cancelled',
  'user_not_found': 'حساب العميل مش موجود',
  'cycle_day_invalid': 'يوم بداية الدورة رقم صحيح من ١ لـ٣١',
  'currency_invalid':
      'العملة كود ISO من ٣ حروف كابيتال (مثل EGP) — والتحدي عملته لحد ١٠ حروف',
  'country_invalid': 'البلد كود ISO من حرفين كابيتال (مثل EG)',
  'balance_invalid': 'الرصيد لازم يكون رقم غير سالب',
  'sleep_time_invalid': 'المواعيد بصيغة HH:MM (٢٤ ساعة)',
  'sleep_bed_out_of_range': 'النوم من ٢٠:٠٠ لـ٠٣:٠٠ — شغل ليلي؟ اسأله وماتحفظش',
  'sleep_wake_out_of_range': 'الصحيان من ٠٤:٠٠ لـ١٢:٠٠',
  'setting_unknown': 'الإعداد ده يا pet_calls يا food_pattern',
  'goal_title_invalid': 'عنوان الهدف من ٤ لـ٢٠٠ حرف',
  'metric_too_long': 'وصف المقياس طويل أوي',
  'target_invalid': 'المبلغ المستهدف لازم رقم موجب منطقي',
  'deadline_invalid': 'تاريخ الهدف مش مفهوم',
  'unit_invalid': 'unit يا money يا count',
  'goal_not_found': 'مفيش هدف بالاسم ده عند العميل',
  'goal_amount_invalid': 'المبلغ لازم رقم مش صفر وبحدود المنطق',
  'goal_not_amount': 'الهدف ده بيتعد بالمهام مش بالفلوس — تقدمه بيتحسب لوحده.',
  'challenge_already_active':
      'عنده تحدي شغال بالفعل — شجّعه يكمّله أو اسأله لو عايز يقفله الأول '
      '(stop_savings_challenge).',
  'no_active_challenge': 'مفيش تحدي شغال أصلاً',
  'challenge_cap_invalid': 'السقف اليومي لازم رقم موجب منطقي',
  'challenge_length_invalid': 'مدة التحدي من ٧ لـ٩٠ يوم',
  'challenge_date_invalid': 'تاريخ بداية التحدي مش مفهوم',
  'dose_slot_invalid': 'ميعاد الجرعة مش تاريخ مفهوم',
  'snooze_minutes_invalid': 'التأجيل من ٥ لـ٢٤٠ دقيقة',
};

/// The customer's words for a refusal.
///
/// A snake code is looked up; anything else is already Arabic (a validator's
/// sentence), so it is shown as it was written.
String guardReasonLabel(String reason) {
  final trimmed = reason.trim();
  if (trimmed.isEmpty) return 'الكتابة اترفضت';
  if (!_snakeCode.hasMatch(trimmed)) return trimmed;
  return _doorReasons[trimmed] ?? 'الكتابة اترفضت';
}

final RegExp _snakeCode = RegExp(r'^[a-z][a-z0-9_]*$');

/// One refusal row.
@immutable
class GuardEvent {
  /// Creates a refusal.
  const new({
    required this.id,
    required this.kind,
    required this.reason,
    required this.createdAt,
    this.tool,
  });

  /// Reads a row. `intent.tool` is there only for refusals from a validator or
  /// a tool; a door refusal carries the intent's kind, not a tool name.
  factory fromJson(Map<String, dynamic> json) {
    final intent = json['intent'];
    final tool = intent is Map ? intent['tool'] : null;
    return GuardEvent(
      id: '${json['id']}',
      kind: (json['kind'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      createdAt: switch (json['created_at']) {
        final String s => DateTime.parse(s).toUtc(),
        _ => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      },
      tool: tool is String && tool.isNotEmpty ? tool : null,
    );
  }

  /// The row id.
  final String id;

  /// The write kind the refusal was about.
  final String kind;

  /// The refusal as stored: a snake code or an Arabic sentence.
  final String reason;

  /// When it was refused.
  final DateTime createdAt;

  /// The tool that asked, when the row recorded one.
  final String? tool;
}

/// What the screen draws: the newest refusals, and how many of each code
/// landed in the last seven days.
@immutable
class GuardEventsSnapshot {
  /// Creates a snapshot.
  const new({required this.recent, required this.countsByReason});

  /// The newest refusals, newest first.
  final List<GuardEvent> recent;

  /// Refusal count per stored reason, over the last seven days.
  final Map<String, int> countsByReason;
}
