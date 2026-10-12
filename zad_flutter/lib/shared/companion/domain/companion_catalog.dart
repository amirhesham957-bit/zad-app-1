/// رفيق زاد's wardrobe as the app draws it: the eight characters, the five
/// stages, the outfits and the backgrounds. The ids are the server's
/// (`zad_companion_items.id`, migration 20261012030000) — what is owned, worn
/// and sold is decided there; this file only knows how each one looks.
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';

/// What sits on a character's head (or at its side) and makes it itself.
enum PersonaCrest {
  /// Two leaves — زادو.
  sprout,

  /// Pistachio crumbs on a syrup top — بسبوس.
  syrup,

  /// A jasmine flower — فلة.
  jasmine,

  /// A curled green stem — فلفول.
  pepper,

  /// One leaf, and a fuzzy rim — مشمش.
  leaf,

  /// An artist's beret — توتة.
  beret,

  /// A gold crescent above, and a glow inside — فانوس.
  crescent,

  /// A cap of powdered sugar — معمول.
  sugar,
}

/// One character.
enum CompanionPersona {
  /// The one everyone starts with.
  zado(
    'zado',
    'زادو',
    'Zado',
    Color(0xFF37C98E),
    Color(0xFF0B6B4E),
    PersonaCrest.sprout,
    'هادي وبيحب البيت المترتب',
    'أهلاً! أنا زادو، معاك في أي حاجة تخص البيت.',
  ),

  /// Round and kind.
  basbous(
    'basbous',
    'بسبوس',
    'Basbous',
    Color(0xFFF2B23E),
    Color(0xFFB7791F),
    PersonaCrest.syrup,
    'حنين وبيحب الحلو والتوفير',
    'وفّرنا النهارده؟ يبقى نستاهل حتة بسبوسة.',
    width: 1.1,
    height: 0.92,
  ),

  /// Gentle, smells of jasmine.
  fella(
    'fella',
    'فلة',
    'Fella',
    Color(0xFFFFC2D6),
    Color(0xFFD9467E),
    PersonaCrest.jasmine,
    'رقيقة وبتهدّي البيت',
    'البيت ريحته فل لما كل حاجة متسجلة في مكانها.',
  ),

  /// Lively, loves a challenge.
  felfool(
    'felfool',
    'فلفول',
    'Felfool',
    Color(0xFFEE4634),
    Color(0xFF9F1D12),
    PersonaCrest.pepper,
    'نشيط وبيحب التحديات',
    'يلا يا بطل! تحدي الأسبوع: نوفّر ١٠٠ ونكسب.',
    width: 0.92,
    height: 1.1,
  ),

  /// Fluffy and warm.
  mishmish(
    'mishmish',
    'مشمش',
    'Mishmish',
    Color(0xFFFF9B52),
    Color(0xFFC2541B),
    PersonaCrest.leaf,
    'منفوش ودافي، بيحب القعدة في البيت',
    'التلاجة مليانة والبيت دافي؟ يبقى أنا مبسوط.',
  ),

  /// Cheeky, draws the plans.
  toota(
    'toota',
    'توتة',
    'Toota',
    Color(0xFF9A6BFF),
    Color(0xFF4C2A9E),
    PersonaCrest.beret,
    'شقية وفنانة، بترسم الخطط',
    'تعالى نرسم خطة الشهر سوا.',
  ),

  /// Ramadan's.
  fanoos(
    'fanoos',
    'فانوس',
    'Fanoos',
    Color(0xFF6E56E8),
    Color(0xFF2B1C7A),
    PersonaCrest.crescent,
    'بيظهر في رمضان',
    'رمضان كريم! جهزت لك قائمة السحور.',
    season: 'ramadan',
    glows: true,
  ),

  /// The Eid's.
  maamoul(
    'maamoul',
    'معمول',
    'Maamoul',
    Color(0xFFE9C28E),
    Color(0xFFA77B3F),
    PersonaCrest.sugar,
    'بيظهر في العيد',
    'عيدكم مبارك! العيدية اتسجلت؟',
    season: 'eid',
    width: 1.12,
    height: 0.88,
  );

  new(
    this.id,
    this.name,
    this.latin,
    this.body,
    this.deep,
    this.crest,
    this.trait,
    this.line, {
    this.width = 1,
    this.height = 1,
    this.season,
    this.glows = false,
  });

  /// The server's id.
  final String id;

  /// Its Arabic pet name.
  final String name;

  /// How it is written in Latin letters.
  final String latin;

  /// Its body colour.
  final Color body;

  /// The body's shaded side.
  final Color deep;

  /// What makes it itself.
  final PersonaCrest crest;

  /// Its temperament, in a few words.
  final String trait;

  /// What it says when you meet it.
  final String line;

  /// Its build: wider than round above 1.
  final double width;

  /// Taller than round above 1.
  final double height;

  /// `ramadan` or `eid` for a seasonal character.
  final String? season;

  /// Lit from inside.
  final bool glows;

  /// The character with [id], or زادو.
  static CompanionPersona byId(String? id) =>
      values.firstWhere((p) => p.id == id, orElse: () => zado);
}

/// Five stages: a level and an age, both (the server decides).
enum CompanionStage {
  /// Still in its shell.
  seed('بذرة', 0.80, 'لسه في قشرته، وعينيه كبيرة.'),

  /// Out, with two little hands.
  sprout('بُرعم', 0.87, 'خرج من القشرة وطلع له إيدين.'),

  /// Feet, and the full outfit.
  little('صغيّر', 0.93, 'طلع له رجلين، وبقى يلبس كل حاجة.'),

  /// A soft light around it.
  companion('رفيق', 1, 'هالة نور حواليه، وبيرقص لما تفرح.'),

  /// A gold halo and stars.
  sage('حكيم', 1.05, 'هالة دهب ونجوم بتلف حواليه.');

  new(this.label, this.scale, this.description);

  /// Its Arabic name.
  final String label;

  /// Its size against a grown companion.
  final double scale;

  /// What changed, said plainly.
  final String description;

  /// The stage numbered [i] (0–4).
  static CompanionStage at(int i) => values[i.clamp(0, values.length - 1)];
}

/// Something worn.
enum CompanionOutfit {
  /// Nothing.
  none('none', ''),

  /// Dark lenses.
  sunglasses('sunglasses', 'نضارة شمس'),

  /// A knitted cap with a pompom.
  winterHat('winter_hat', 'طاقية شتوي'),

  /// A chef's toque.
  chefHat('chef_hat', 'طاقية الشيف'),

  /// A red-and-white shemagh with its agal.
  shemagh('shemagh', 'شماغ'),

  /// A mortarboard with its tassel.
  gradCap('grad_cap', 'طاقية التخرج');

  new(this.id, this.label);

  /// The server's id.
  final String id;

  /// Its name.
  final String label;

  /// Covers the top of the head, so the character's crest is hidden.
  bool get coversHead => this != none && this != sunglasses;

  /// The outfit with [id], or nothing.
  static CompanionOutfit byId(String? id) =>
      values.firstWhere((o) => o.id == id, orElse: () => none);
}

/// Behind the companion in its studio.
enum CompanionBackground {
  /// Morning light.
  morning('morning', 'الصبح', <Color>[Color(0xFFEAF4FF), Color(0xFFFFF2E4)]),

  /// A warm evening.
  night('night', 'بالليل', <Color>[Color(0xFF191530), Color(0xFF3A2A22)]),

  /// Green and fresh.
  garden('garden', 'الجنينة', <Color>[Color(0xFFDDF6E4), Color(0xFFB7E4C7)]),

  /// The kitchen's warm tiles.
  kitchen('kitchen', 'المطبخ', <Color>[Color(0xFFFFF3D6), Color(0xFFF6D7B0)]),

  /// A sky of stars.
  stars('stars', 'سما النجوم', <Color>[Color(0xFF0B1033), Color(0xFF2B1F5C)]),

  /// Friends together.
  shilla('shilla', 'الشلة', <Color>[Color(0xFFFFE1EC), Color(0xFFE3E0FF)]);

  new(this.id, this.label, this.colors);

  /// The server's id.
  final String id;

  /// Its name.
  final String label;

  /// Top to bottom.
  final List<Color> colors;

  /// Dark, so text over it is light.
  bool get dark => this == night || this == stars;

  /// The background with [id], or the morning.
  static CompanionBackground byId(String? id) =>
      values.firstWhere((b) => b.id == id, orElse: () => morning);
}

/// What the orb draws: who, how grown, what it wears, and whether it sleeps.
@immutable
class CompanionLook {
  /// Creates a look.
  const new({
    this.persona = CompanionPersona.zado,
    this.stage = CompanionStage.companion,
    this.outfit = CompanionOutfit.none,
    this.asleep = false,
  });

  /// The character.
  final CompanionPersona persona;

  /// How grown.
  final CompanionStage stage;

  /// What it wears.
  final CompanionOutfit outfit;

  /// Eyes shut, Zs rising, breathing slow.
  final bool asleep;

  /// The same look, awake or asleep.
  CompanionLook copyWith({
    CompanionPersona? persona,
    CompanionStage? stage,
    CompanionOutfit? outfit,
    bool? asleep,
  }) => CompanionLook(
    persona: persona ?? this.persona,
    stage: stage ?? this.stage,
    outfit: outfit ?? this.outfit,
    asleep: asleep ?? this.asleep,
  );

  @override
  bool operator ==(Object other) =>
      other is CompanionLook &&
      other.persona == persona &&
      other.stage == stage &&
      other.outfit == outfit &&
      other.asleep == asleep;

  @override
  int get hashCode => Object.hash(persona, stage, outfit, asleep);
}
