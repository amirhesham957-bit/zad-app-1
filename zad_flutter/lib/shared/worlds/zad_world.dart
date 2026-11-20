/// The «عوالم»: every screen of the app is one world — a colour, a painted
/// scene with the customer's companion in it, calm white cards, and a strip
/// of the worlds it feeds. This is the registry; `ZadWorldScaffold` draws
/// one and `ZadWorldLinks` joins them.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/worlds/art/zad_art_kinds.dart';

/// A world.
enum ZadWorld {
  /// عقل زاد.
  brain(ZadWorldColors.brain, ZadIconArt.brain),

  /// شيف زاد.
  chef(ZadWorldColors.chef, ZadIconArt.pot),

  /// المخزون.
  inv(ZadWorldColors.inventory, ZadIconArt.pantry),

  /// التسوق.
  shop(ZadWorldColors.shopping, ZadIconArt.cart),

  /// المعاملات.
  tx(ZadWorldColors.transactions, ZadIconArt.receipt),

  /// الميزانية.
  budget(ZadWorldColors.budget, ZadIconArt.coin),

  /// كشف الحساب.
  stmt(ZadWorldColors.statement, ZadIconArt.chart),

  /// الاشتراكات.
  subs(ZadWorldColors.subscriptions, ZadIconArt.repeat),

  /// الصيدلية.
  ph(ZadWorldColors.pharmacy, ZadIconArt.pill),

  /// المواعيد.
  appt(ZadWorldColors.appointments, ZadIconArt.calendar),

  /// الصيانة.
  maint(ZadWorldColors.maintenance, ZadIconArt.wrench),

  /// المستندات.
  docs(ZadWorldColors.documents, ZadIconArt.folder),

  /// أماكني.
  places(ZadWorldColors.places, ZadIconArt.pin),

  /// رفيق زاد.
  comp(ZadWorldColors.companion, ZadIconArt.sprout),

  /// الشات.
  chat(ZadWorldColors.chat, ZadIconArt.chat),

  /// الإشعارات.
  notif(ZadWorldColors.notifications, ZadIconArt.bell),

  /// حسابي.
  profile(ZadWorldColors.profile, ZadIconArt.person),

  /// بريميوم.
  prem(ZadWorldColors.premium, ZadIconArt.crown),

  /// بستان التسبيح.
  tas(ZadWorldColors.tasbih, ZadIconArt.beads),

  /// ألعاب زادو.
  games(ZadWorldColors.games, ZadIconArt.play),

  /// أسعار النهارده.
  prices(ZadWorldColors.prices, ZadIconArt.tag),

  /// عروضي.
  offers(ZadWorldColors.offers, ZadIconArt.gift),

  /// إنجازاتي.
  ach(ZadWorldColors.achievements, ZadIconArt.star);

  new(this.color, this.art);

  /// The world's one colour.
  final Color color;

  /// Its drawn icon, on the chip that opens it.
  final ZadIconArt art;

  /// The name the customer reads.
  String label(ZadL10n l) => switch (this) {
    brain => l.worldLabelBrain,
    chef => l.worldLabelChef,
    inv => l.worldLabelInv,
    shop => l.worldLabelShop,
    tx => l.worldLabelTx,
    budget => l.worldLabelBudget,
    stmt => l.worldLabelStmt,
    subs => l.worldLabelSubs,
    ph => l.worldLabelPh,
    appt => l.worldLabelAppt,
    maint => l.worldLabelMaint,
    docs => l.worldLabelDocs,
    places => l.worldLabelPlaces,
    comp => l.worldLabelComp,
    chat => l.worldLabelChat,
    notif => l.worldLabelNotif,
    profile => l.worldLabelProfile,
    prem => l.worldLabelPrem,
    tas => l.worldLabelTas,
    games => l.worldLabelGames,
    prices => l.worldLabelPrices,
    offers => l.worldLabelOffers,
    ach => l.worldLabelAch,
  };

  /// The worlds this one feeds — what happens here changes what they show
  /// (the preview's FEEDS table).
  List<ZadWorld> get feeds => switch (this) {
    brain => const <ZadWorld>[tx, inv, places, chat, comp],
    chef => const <ZadWorld>[inv, shop, budget],
    inv => const <ZadWorld>[chef, shop, tx],
    shop => const <ZadWorld>[inv, chef, places, budget],
    tx => const <ZadWorld>[budget, brain, stmt, subs],
    budget => const <ZadWorld>[tx, subs, stmt, brain],
    stmt => const <ZadWorld>[tx, budget, subs],
    subs => const <ZadWorld>[budget, notif, tx],
    ph => const <ZadWorld>[appt, notif, shop],
    appt => const <ZadWorld>[notif, ph, places],
    maint => const <ZadWorld>[notif, budget, docs],
    docs => const <ZadWorld>[notif, maint],
    places => const <ZadWorld>[shop, notif, brain],
    comp => const <ZadWorld>[brain, chat, ach],
    chat => const <ZadWorld>[brain, tx, inv, shop],
    notif => const <ZadWorld>[ph, appt, subs, maint],
    profile => const <ZadWorld>[prem, brain, docs],
    prem => const <ZadWorld>[profile, brain, chef],
    tas => const <ZadWorld>[comp, ach, notif],
    games => const <ZadWorld>[comp, prices],
    prices => const <ZadWorld>[shop, budget, chef],
    offers => const <ZadWorld>[shop, chef, notif],
    ach => const <ZadWorld>[comp, games, tas],
  };
}
