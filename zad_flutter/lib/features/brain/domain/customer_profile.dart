/// `zad_customer_profile`: who the customer is to زاد — how to address them,
/// their role at home, when they are paid.
///
/// The brain fills it from conversation (`update_customer_profile`) and reads
/// it into every turn. The customer sees it and corrects it here. The fixed
/// values are the table's own check constraints, so they are data, never
/// display text; the labels below are the display text.
library;

import 'package:flutter/foundation.dart';

/// Allowed values, copied from the table's check constraints (read off the
/// live project 2026-09-21).
abstract final class ProfileOptions {
  /// `gender`.
  static const List<String> genders = <String>['male', 'female'];

  /// `household_role`.
  static const List<String> roles = <String>[
    'father',
    'mother',
    'husband',
    'wife',
    'son',
    'daughter',
    'single',
    'student',
    'grandparent',
    'other',
  ];

  /// `age_range`.
  static const List<String> ageRanges = <String>[
    'under_18',
    '18_24',
    '25_34',
    '35_44',
    '45_54',
    '55_plus',
  ];

  /// `pay_frequency`.
  static const List<String> payFrequencies = <String>[
    'monthly',
    'biweekly',
    'weekly',
    'daily',
    'irregular',
  ];

  /// `dialect`.
  static const List<String> dialects = <String>[
    'EG',
    'SA',
    'GULF',
    'LEVANT',
    'IQ',
    'MA',
    'TN',
    'DZ',
    'LY',
    'SD',
    'YE',
    'TR',
    'EN',
  ];
}

/// The profile. Every field is optional; null is "not known yet".
@immutable
class CustomerProfile {
  /// Creates a profile.
  const new({
    this.preferredName,
    this.gender,
    this.householdRole,
    this.ageRange,
    this.occupation,
    this.payDay,
    this.payFrequency,
    this.householdSize,
    this.kidsCount,
    this.city,
    this.dialect,
  });

  /// Reads a row.
  factory fromJson(Map<String, dynamic> json) => CustomerProfile(
    preferredName: json['preferred_name'] as String?,
    gender: json['gender'] as String?,
    householdRole: json['household_role'] as String?,
    ageRange: json['age_range'] as String?,
    occupation: json['occupation'] as String?,
    payDay: (json['pay_day'] as num?)?.toInt(),
    payFrequency: json['pay_frequency'] as String?,
    householdSize: (json['household_size'] as num?)?.toInt(),
    kidsCount: (json['kids_count'] as num?)?.toInt(),
    city: json['city'] as String?,
    dialect: json['dialect'] as String?,
  );

  /// How زاد addresses them.
  final String? preferredName;

  /// `male` / `female` — Arabic addresses the two differently.
  final String? gender;

  /// Their role at home.
  final String? householdRole;

  /// An age band.
  final String? ageRange;

  /// What they do.
  final String? occupation;

  /// The day of the month they are paid.
  final int? payDay;

  /// How often.
  final String? payFrequency;

  /// How many live at home.
  final int? householdSize;

  /// How many children.
  final int? kidsCount;

  /// Where.
  final String? city;

  /// Which Arabic to answer in; null follows the market.
  final String? dialect;

  /// The same profile cut to what the table accepts: text trimmed and capped,
  /// a value outside a check constraint dropped to "not known", an empty
  /// string to null. The save would otherwise be refused whole.
  CustomerProfile normalized() {
    String? text(String? v, int max) {
      final t = v?.trim() ?? '';
      if (t.isEmpty) return null;
      return t.length > max ? t.substring(0, max) : t;
    }

    String? oneOf(String? v, List<String> allowed) =>
        allowed.contains(v) ? v : null;
    int? within(int? v, int min, int max) =>
        v != null && v >= min && v <= max ? v : null;

    return CustomerProfile(
      preferredName: text(preferredName, 40),
      gender: oneOf(gender, ProfileOptions.genders),
      householdRole: oneOf(householdRole, ProfileOptions.roles),
      ageRange: oneOf(ageRange, ProfileOptions.ageRanges),
      occupation: text(occupation, 80),
      payDay: within(payDay, 1, 31),
      payFrequency: oneOf(payFrequency, ProfileOptions.payFrequencies),
      householdSize: within(householdSize, 1, 30),
      kidsCount: within(kidsCount, 0, 20),
      city: text(city, 60),
      dialect: oneOf(dialect, ProfileOptions.dialects),
    );
  }

  /// The columns this screen owns, for an upsert.
  ///
  /// Only these: `work_schedule`, `income_source`, `interests` and `notes` are
  /// filled by the brain and have no field here, and an upsert that left them
  /// out keeps them. A null here is sent as null on purpose — the customer
  /// cleared it.
  Map<String, dynamic> toFormJson() => <String, dynamic>{
    'preferred_name': preferredName,
    'gender': gender,
    'household_role': householdRole,
    'age_range': ageRange,
    'occupation': occupation,
    'pay_day': payDay,
    'pay_frequency': payFrequency,
    'household_size': householdSize,
    'kids_count': kidsCount,
    'city': city,
    'dialect': dialect,
  };

  /// Round-trips through the cache; the same columns.
  Map<String, dynamic> toJson() => toFormJson();

  @override
  bool operator ==(Object other) =>
      other is CustomerProfile &&
      other.preferredName == preferredName &&
      other.gender == gender &&
      other.householdRole == householdRole &&
      other.ageRange == ageRange &&
      other.occupation == occupation &&
      other.payDay == payDay &&
      other.payFrequency == payFrequency &&
      other.householdSize == householdSize &&
      other.kidsCount == kidsCount &&
      other.city == city &&
      other.dialect == dialect;

  @override
  int get hashCode => Object.hash(
    preferredName,
    gender,
    householdRole,
    ageRange,
    occupation,
    payDay,
    payFrequency,
    householdSize,
    kidsCount,
    city,
    dialect,
  );
}

/// Display text for the fixed values.
abstract final class ProfileLabels {
  /// `gender`.
  static String gender(String v) => v == 'female' ? 'أنثى' : 'ذكر';

  /// `household_role`.
  static String role(String v) => switch (v) {
    'father' => 'أب',
    'mother' => 'أم',
    'husband' => 'زوج',
    'wife' => 'زوجة',
    'son' => 'ابن',
    'daughter' => 'بنت',
    'single' => 'عايش لوحدي',
    'student' => 'طالب',
    'grandparent' => 'جد/جدة',
    _ => 'غير كده',
  };

  /// `age_range`.
  static String age(String v) => switch (v) {
    'under_18' => 'أقل من ١٨',
    '18_24' => '١٨–٢٤',
    '25_34' => '٢٥–٣٤',
    '35_44' => '٣٥–٤٤',
    '45_54' => '٤٥–٥٤',
    _ => '٥٥ وأكبر',
  };

  /// `pay_frequency`.
  static String frequency(String v) => switch (v) {
    'weekly' => 'أسبوعي',
    'biweekly' => 'كل أسبوعين',
    'daily' => 'يومي',
    'irregular' => 'مش ثابت',
    _ => 'شهري',
  };

  /// `dialect`.
  static String dialect(String v) => switch (v) {
    'SA' => 'سعودي',
    'GULF' => 'خليجي',
    'LEVANT' => 'شامي',
    'IQ' => 'عراقي',
    'MA' => 'مغربي',
    'TN' => 'تونسي',
    'DZ' => 'جزائري',
    'LY' => 'ليبي',
    'SD' => 'سوداني',
    'YE' => 'يمني',
    'TR' => 'Türkçe',
    'EN' => 'English',
    _ => 'مصري',
  };
}
