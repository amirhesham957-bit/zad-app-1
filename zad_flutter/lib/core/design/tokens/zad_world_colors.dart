/// One colour per «عالم» (the owner-approved all-pages preview, 15/11).
/// A world is that colour, a painted scene and calm white cards.
library;

import 'package:flutter/painting.dart';

/// The world colours.
abstract final class ZadWorldColors {
  /// عقل زاد.
  static const Color brain = Color(0xFF0F9B76);

  /// شيف زاد.
  static const Color chef = Color(0xFFD95726);

  /// المخزون.
  static const Color inventory = Color(0xFF37C98E);

  /// التسوق.
  static const Color shopping = Color(0xFF2F7BD8);

  /// المعاملات.
  static const Color transactions = Color(0xFF0B6B4E);

  /// الميزانية.
  static const Color budget = Color(0xFFC68216);

  /// كشف الحساب.
  static const Color statement = Color(0xFF7A4E06);

  /// الاشتراكات.
  static const Color subscriptions = Color(0xFFE08A1E);

  /// الصيدلية.
  static const Color pharmacy = Color(0xFF4A3F94);

  /// المواعيد.
  static const Color appointments = Color(0xFFC2416B);

  /// الصيانة.
  static const Color maintenance = Color(0xFF5F6B7A);

  /// المستندات.
  static const Color documents = Color(0xFF3B6EA8);

  /// أماكني.
  static const Color places = Color(0xFF2F7BD8);

  /// رفيق زاد.
  static const Color companion = Color(0xFF45BF68);

  /// الشات.
  static const Color chat = Color(0xFF064E3B);

  /// الإشعارات.
  static const Color notifications = Color(0xFFD95726);

  /// حسابي.
  static const Color profile = Color(0xFF374151);

  /// بريميوم.
  static const Color premium = Color(0xFFE08A1E);

  /// بستان التسبيح.
  static const Color tasbih = Color(0xFF45BF68);

  /// ألعاب زادو.
  static const Color games = Color(0xFF8B5CF6);

  /// أسعار النهارده.
  static const Color prices = Color(0xFFC68216);

  /// عروضي.
  static const Color offers = Color(0xFF8B5CF6);

  /// إنجازاتي.
  static const Color achievements = Color(0xFFF5B93A);

  /// A world's backdrop top: its colour at a tenth over white.
  static Color tint(Color world) =>
      Color.lerp(const Color(0xFFFFFFFF), world, 0.10)!;
}
