/// `zad_customer_profile`: who the customer is to زاد — how to address them,
/// their role at home, when they are paid.
///
/// The brain fills it from conversation (`update_customer_profile`) and reads
/// it into every turn. The customer sees it and corrects it here. The fixed
/// values are the table's own check constraints, so they are data, never
/// display text; the labels below are the display text.
library;

import 'package:flutter/foundation.dart';
import 'package:zad/core/l10n/l10n.dart';

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

  /// `cares_for`: who the customer looks after. A son responsible for his
  /// parents is not a father responsible for children, and the brain treats
  /// them differently.
  static const List<String> caresFor = <String>[
    'children',
    'parents',
    'spouse',
    'siblings',
    'grandparents',
  ];

  /// `zad_voice`: زاد's own voice, the customer's explicit choice
  /// (20261004090000). Null is a girl's voice; it is never read from
  /// [CustomerProfile.gender].
  static const List<String> zadVoices = <String>['female', 'male'];

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
    this.caresFor,
    this.zadVoice,
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
    caresFor: switch (json['cares_for']) {
      final List<dynamic> list => list.whereType<String>().toList(),
      _ => null,
    },
    zadVoice: json['zad_voice'] as String?,
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

  /// Who the customer looks after (`cares_for`): null when never asked, empty
  /// when no one but themselves.
  final List<String>? caresFor;

  /// The voice زاد speaks in, chosen by the customer: `female` or `male`;
  /// null has never been chosen and sounds like `female`.
  final String? zadVoice;

  /// Whether the three things Zad needs from the first day are known: what to
  /// call the customer, how to address them, and their place in the home —
  /// including who they look after.
  bool get isIntroduced =>
      (preferredName?.trim().isNotEmpty ?? false) &&
      gender != null &&
      householdRole != null &&
      caresFor != null;

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
      caresFor: caresFor
          ?.where(ProfileOptions.caresFor.contains)
          .toSet()
          .toList(),
      zadVoice: oneOf(zadVoice, ProfileOptions.zadVoices),
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
    // Only when known: the older forms build a profile without it, and their
    // save must not wipe what the introduction recorded.
    'cares_for': ?caresFor,
    // Only when chosen, for the same reason — and so a save before the column
    // reaches the project still goes through when the voice was not touched.
    'zad_voice': ?zadVoice,
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
      other.dialect == dialect &&
      listEquals(other.caresFor, caresFor) &&
      other.zadVoice == zadVoice;

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
    caresFor == null ? null : Object.hashAll(caresFor!),
    zadVoice,
  );
}

/// Display text for the fixed values.
abstract final class ProfileLabels {
  /// `gender`.
  static String gender(String v, [ZadL10n? l10n]) =>
      _gender(v, l10n ?? zadL10nArabic);

  static String _gender(String v, ZadL10n l) =>
      v == 'female' ? l.profileLabelGenderFemale : l.profileLabelGenderMale;

  /// `zad_voice`.
  static String zadVoice(String v, [ZadL10n? l10n]) =>
      _zadVoice(v, l10n ?? zadL10nArabic);

  static String _zadVoice(String v, ZadL10n l) =>
      v == 'male' ? l.profileLabelZadvoiceBoy : l.profileLabelZadvoiceGirl;

  /// `household_role`.
  static String role(String v, [ZadL10n? l10n]) =>
      _role(v, l10n ?? zadL10nArabic);

  static String _role(String v, ZadL10n l) => switch (v) {
    'father' => l.profileLabelRoleFather,
    'mother' => l.profileLabelRoleMother,
    'husband' => l.profileLabelRoleHusband,
    'wife' => l.profileLabelRoleWife,
    'son' => l.profileLabelRoleSon,
    'daughter' => l.profileLabelRoleDaughter,
    'single' => l.profileLabelRoleSingle,
    'student' => l.profileLabelRoleStudent,
    'grandparent' => l.profileLabelRoleGrandparent,
    _ => l.profileLabelRoleDefault,
  };

  /// `age_range`.
  static String age(String v, [ZadL10n? l10n]) =>
      _age(v, l10n ?? zadL10nArabic);

  static String _age(String v, ZadL10n l) => switch (v) {
    'under_18' => l.profileLabelAgeUnder18,
    '18_24' => l.profileLabelAge1824,
    '25_34' => l.profileLabelAge2534,
    '35_44' => l.profileLabelAge3544,
    '45_54' => l.profileLabelAge4554,
    _ => l.profileLabelAgeDefault,
  };

  /// `pay_frequency`.
  static String frequency(String v, [ZadL10n? l10n]) =>
      _frequency(v, l10n ?? zadL10nArabic);

  static String _frequency(String v, ZadL10n l) => switch (v) {
    'weekly' => l.profileLabelFrequencyWeekly,
    'biweekly' => l.profileLabelFrequencyBiweekly,
    'daily' => l.profileLabelFrequencyDaily,
    'irregular' => l.profileLabelFrequencyIrregular,
    _ => l.profileLabelFrequencyDefault,
  };

  /// `cares_for`.
  static String caresFor(String v, [ZadL10n? l10n]) =>
      _caresFor(v, l10n ?? zadL10nArabic);

  static String _caresFor(String v, ZadL10n l) => switch (v) {
    'children' => l.profileLabelCaresforChildren,
    'parents' => l.profileLabelCaresforParents,
    'spouse' => l.profileLabelCaresforSpouse,
    'siblings' => l.profileLabelCaresforSiblings,
    'grandparents' => l.profileLabelCaresforGrandparents,
    _ => v,
  };

  /// `dialect`.
  static String dialect(String v, [ZadL10n? l10n]) =>
      _dialect(v, l10n ?? zadL10nArabic);

  static String _dialect(String v, ZadL10n l) => switch (v) {
    'SA' => l.profileLabelDialectSa,
    'GULF' => l.profileLabelDialectGulf,
    'LEVANT' => l.profileLabelDialectLevant,
    'IQ' => l.profileLabelDialectIq,
    'MA' => l.profileLabelDialectMa,
    'TN' => l.profileLabelDialectTn,
    'DZ' => l.profileLabelDialectDz,
    'LY' => l.profileLabelDialectLy,
    'SD' => l.profileLabelDialectSd,
    'YE' => l.profileLabelDialectYe,
    'TR' => 'Türkçe',
    'EN' => 'English',
    _ => l.profileLabelDialectDefault,
  };
}
