/// Kotlin's `SubscriptionBrandIcons.kt`: a Material icon in the service's
/// known colour — not its logo — for the well-known services.
///
/// The keys are **match data** (CLAUDE.md i18n rule): the alternative
/// spellings are compared against the subscription's title and provider, so
/// they stay exactly as Kotlin has them.
library;

import 'package:flutter/material.dart';

/// A service's icon and colour.
typedef SubscriptionBrand = ({IconData icon, Color color});

const List<(List<String>, SubscriptionBrand)> _brands =
    <(List<String>, SubscriptionBrand)>[
      (
        <String>['netflix', 'نتفلكس', 'نتفليكس'],
        (icon: Icons.movie, color: Color(0xFFE50914)),
      ),
      (
        <String>['shahid', 'شاهد', 'شاهد vip', 'shahid vip'],
        (icon: Icons.live_tv, color: Color(0xFF00A651)),
      ),
      (
        <String>['tabby', 'تابي'],
        (icon: Icons.shopping_bag, color: Color(0xFF29E7CD)),
      ),
      (
        <String>['tamara', 'تمارا'],
        (icon: Icons.shopping_bag, color: Color(0xFFFF7043)),
      ),
      (
        <String>['spotify', 'سبوتيفاي', 'سبوتيفي'],
        (icon: Icons.music_note, color: Color(0xFF1DB954)),
      ),
      (
        <String>['anghami', 'أنغامي', 'انغامي'],
        (icon: Icons.music_note, color: Color(0xFF8B5CF6)),
      ),
      (
        <String>['youtube', 'يوتيوب', 'youtube premium'],
        (icon: Icons.smart_display, color: Color(0xFFFF0000)),
      ),
      (
        <String>['osn', 'أو إس إن', 'او اس ان', 'osn+'],
        (icon: Icons.live_tv, color: Color(0xFFE11D48)),
      ),
      (
        <String>['tod', 'تود', 'tod tv'],
        (icon: Icons.live_tv, color: Color(0xFF10B981)),
      ),
      (
        <String>['chatgpt', 'openai', 'شات جي بي تي', 'أوبن إيه آي'],
        (icon: Icons.auto_awesome, color: Color(0xFF10A37F)),
      ),
      (
        <String>['amazon prime', 'أمازون برايم', 'prime video', 'برايم'],
        (icon: Icons.shopping_bag, color: Color(0xFFFF9900)),
      ),
      (
        <String>['disney', 'ديزني', 'disney+'],
        (icon: Icons.theaters, color: Color(0xFF113CCF)),
      ),
      (
        <String>['apple music', 'آبل ميوزك', 'icloud', 'آيكلاود', 'apple'],
        (icon: Icons.cloud, color: Color(0xFF555555)),
      ),
      (
        <String>[
          'playstation',
          'بلايستيشن',
          'ps plus',
          'xbox',
          'إكس بوكس',
          'game pass',
        ],
        (icon: Icons.smart_display, color: Color(0xFF0070D1)),
      ),
      (
        <String>[
          'stc',
          'موبايلي',
          'زين',
          'vodafone',
          'فودافون',
          'orange',
          'اورانج',
          'we',
          'وي',
          'إنترنت',
          'انترنت',
        ],
        (icon: Icons.wifi, color: Color(0xFF3B82F6)),
      ),
      (
        <String>['جيم', 'gym', 'fitness', 'وقت اللياقة'],
        (icon: Icons.fitness_center, color: Color(0xFFF97316)),
      ),
      (
        <String>['مياه', 'المياه', 'water'],
        (icon: Icons.water_drop, color: Color(0xFF0EA5E9)),
      ),
      (
        <String>['كهرباء', 'الكهرباء', 'كهربا', 'electricity'],
        (icon: Icons.bolt, color: Color(0xFFF59E0B)),
      ),
    ];

/// Kotlin's `subscriptionBrandFor`: searches the title and the provider
/// together, since "Netflix" may arrive in either.
SubscriptionBrand? subscriptionBrandFor(String title, String? provider) {
  final haystack = '$title ${provider ?? ''}'.toLowerCase();
  for (final (keys, brand) in _brands) {
    if (keys.any((k) => haystack.contains(k.toLowerCase()))) return brand;
  }
  return null;
}
