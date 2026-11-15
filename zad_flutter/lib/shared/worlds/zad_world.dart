/// The «عوالم»: every screen of the app is one world — a colour, a painted
/// scene with the customer's companion in it, calm white cards, and a strip
/// of the worlds it feeds. This is the registry; `ZadWorldScaffold` draws
/// one and `ZadWorldLinks` joins them.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';

/// A world.
enum ZadWorld {
  /// عقل زاد.
  brain(ZadWorldColors.brain, ZadIcons.brain),

  /// شيف زاد.
  chef(ZadWorldColors.chef, ZadIcons.chef),

  /// المخزون.
  inv(ZadWorldColors.inventory, ZadIcons.inventory),

  /// التسوق.
  shop(ZadWorldColors.shopping, ZadIcons.shopping),

  /// المعاملات.
  tx(ZadWorldColors.transactions, Icons.receipt_long),

  /// الميزانية.
  budget(ZadWorldColors.budget, ZadIcons.budget),

  /// كشف الحساب.
  stmt(ZadWorldColors.statement, Icons.query_stats),

  /// الاشتراكات.
  subs(ZadWorldColors.subscriptions, ZadIcons.recurring),

  /// الصيدلية.
  ph(ZadWorldColors.pharmacy, ZadIcons.pharmacy),

  /// المواعيد.
  appt(ZadWorldColors.appointments, Icons.event_note),

  /// الصيانة.
  maint(ZadWorldColors.maintenance, ZadIcons.maintenance),

  /// المستندات.
  docs(ZadWorldColors.documents, Icons.folder),

  /// أماكني.
  places(ZadWorldColors.places, Icons.place),

  /// رفيق زاد.
  comp(ZadWorldColors.companion, Icons.spa),

  /// الشات.
  chat(ZadWorldColors.chat, ZadIcons.ask),

  /// الإشعارات.
  notif(ZadWorldColors.notifications, ZadIcons.notifications),

  /// حسابي.
  profile(ZadWorldColors.profile, Icons.person),

  /// بريميوم.
  prem(ZadWorldColors.premium, Icons.workspace_premium),

  /// بستان التسبيح.
  tas(ZadWorldColors.tasbih, Icons.park),

  /// ألعاب زادو.
  games(ZadWorldColors.games, Icons.sports_esports),

  /// أسعار النهارده.
  prices(ZadWorldColors.prices, ZadIcons.prices),

  /// عروضي.
  offers(ZadWorldColors.offers, Icons.card_giftcard),

  /// إنجازاتي.
  ach(ZadWorldColors.achievements, ZadIcons.leaderboard);

  new(this.color, this.icon);

  /// The world's one colour.
  final Color color;

  /// Its glyph, on the chip that opens it.
  final IconData icon;

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
