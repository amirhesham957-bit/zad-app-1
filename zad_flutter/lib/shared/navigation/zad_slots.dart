/// The pieces of one feature's UI that another feature shows inside its own
/// screen — Home's cards, البيت's tabs, the settings sections.
///
/// Same arrangement as [ZadScreens]: the host asks for a slot here and never
/// imports the feature that fills it; `app/wiring/screens_wiring.dart` binds
/// each slot to its widget. Each builder takes exactly the widget's own
/// parameters, so a slot builds exactly what the direct constructor did.
library;

import 'package:flutter/widgets.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';
import 'package:zad/shared/navigation/zad_screens.dart' show ZadScreens;
import 'package:zad/shared/proposals/domain/transaction_proposal.dart';

/// Builds a slot that takes nothing.
typedef SlotBuilder = Widget Function();

/// Embedded sections, by the feature that owns them.
abstract final class ZadSlots {
  // ── affiliate
  /// One affiliate product.
  static late Widget Function({
    required AffiliateProduct product,
    required VoidCallback onBuy,
    double? width,
  })
  affiliateProductCard;

  /// The shopping list's affiliate suggestions.
  static late SlotBuilder affiliateSuggestionSection;

  // ── alerts
  /// The alerts section of الإعدادات.
  static late SlotBuilder alertsSettingsSection;

  // ── auth
  /// The app bar's sign-out action.
  static late SlotBuilder signOutAction;

  /// الإعدادات' sign-out row.
  static late SlotBuilder signOutTile;

  // ── bank
  /// Bank notifications that did not become transactions.
  static late SlotBuilder stuckNotificationsSlot;

  // ── chat
  /// The conversation, as a full screen.
  static late SlotBuilder chatScreen;

  /// عقل زاد's chat card.
  static late Widget Function({
    required bool expanded,
    required VoidCallback onToggle,
  })
  chatSectionCard;

  // ── debts
  /// الحسابات' debts tab.
  static late SlotBuilder debtsTab;

  /// «العروض المتاحة لنواقصك» — a live web search for the pantry's
  /// shortages, fetched on a tap (debts feature).
  static late SlotBuilder liveDealsCard;

  // ── family
  /// The family screen.
  static late Widget Function({Key? key, bool showFinancials, int initialTab})
  familyScreen;

  // ── insights
  /// Home's insights.
  static late Widget Function({VoidCallback? onOpenCamera}) homeInsightsSection;

  // ── intelligence
  /// عقل زاد's analysis, full screen or `embedded`.
  static late Widget Function({Key? key, bool embedded}) intelligenceScreen;

  /// Home's reports row.
  static late Widget Function({
    required double spent,
    required double? spendable,
    required int daysLeft,
    required String currency,
  })
  homeReportsRow;

  // ── inventory
  /// The pantry.
  static late Widget Function({bool shortagesFirst}) pantryView;

  /// The shopping list.
  static late SlotBuilder shoppingListView;

  // ── modes
  /// Broke mode.
  static late Widget Function({bool offerEntry}) brokeModeSlot;

  /// The savings challenge.
  static late Widget Function({bool offerEntry, bool offerStop})
  savingsChallengeSlot;

  // ── obligations
  /// Fixed obligations.
  static late SlotBuilder obligationsSection;

  /// The obligations of some kinds (stored `kind` values; empty = all), for
  /// «التزاماتي»'s tabs. `whenEmpty` shows when there are none.
  static late Widget Function({
    required Set<String> kinds,
    String? title,
    Widget? whenEmpty,
  })
  obligationRows;

  // ── pharmacy
  /// The medicine cabinet.
  static late SlotBuilder pharmacyView;

  // ── places
  /// Street alerts.
  static late SlotBuilder streetAlertsSection;

  /// The battery / auto-start guide (places feature).
  static late SlotBuilder keepAliveGuide;

  // ── prices
  /// Home's live market ticker.
  static late SlotBuilder liveMarketTickerSlot;

  // ── proposals
  /// Home's waiting bank transactions.
  static late SlotBuilder homeProposalsSection;

  /// One waiting bank transaction.
  static late Widget Function({
    required TransactionProposal proposal,
    required bool busy,
    required bool failed,
    required ValueChanged<ProposalDecision> onDecide,
  })
  proposalCard;

  // ── recipes
  /// Home's شيف زاد section.
  static late SlotBuilder homeChefSection;

  /// البيت's recipes tab.
  static late SlotBuilder recipesView;

  // ── subscriptions
  /// الاشتراكات, full screen or `embedded`.
  static late Widget Function({bool embedded, int initialTab})
  subscriptionsScreen;

  // ── telegram
  /// Home's Telegram blocks.
  static late SlotBuilder homeTelegramBlocks;
}
