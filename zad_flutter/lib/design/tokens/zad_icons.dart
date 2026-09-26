/// The icon set: Material Icons, the same set the Kotlin app draws with
/// (`androidx.compose.material.icons`, `Icons.Default.*`).
///
/// Each meaning below maps to the icon Kotlin uses for that same thing — the
/// nav bar's `Icons.Default.Inventory2` is `inventory`, the family screen's
/// SOS `Icons.Default.Warning` is `sos` — so a screen copied from Kotlin gets
/// Kotlin's glyph by naming the meaning. Where a Kotlin screen names a glyph
/// that has no meaning here, the copy uses `Icons.<name>` directly.
///
/// Kotlin's `Icons.AutoMirrored.*` flip under RTL. Flutter's `Icons` already
/// flip `arrow_back`, `chevron_*` and `send`; `forward` is declared by hand
/// because Flutter's `keyboard_arrow_right` does not.
library;

import 'package:flutter/material.dart';

/// Kotlin's `Icons.AutoMirrored.Filled.KeyboardArrowRight`.
const IconData _kArrowRightMirrored = IconData(
  0xe355,
  fontFamily: 'MaterialIcons',
  matchTextDirection: true,
);

/// The icons this app uses, by what they mean.
abstract final class ZadIcons {
  // ── Navigation ───────────────────────────────────────────────────────────

  /// Home.
  static const IconData home = Icons.home;

  /// The budget screen.
  static const IconData budget = Icons.account_balance_wallet;

  /// Assistant / chat.
  static const IconData assistant = Icons.auto_awesome;

  /// Settings.
  static const IconData settings = Icons.settings;

  // ── Money ────────────────────────────────────────────────────────────────

  /// Money out.
  static const IconData expense = Icons.trending_down;

  /// Money in.
  static const IconData income = Icons.trending_up;

  /// Sending something off — the quick expense sheet's button.
  static const IconData send = Icons.send;

  /// Money moved between the user's own wallets.
  static const IconData transfer = Icons.swap_horiz;

  /// Cash.
  static const IconData cash = Icons.payments;

  /// A card.
  static const IconData card = Icons.credit_card;

  /// A bank account.
  static const IconData bank = Icons.account_balance;

  /// A recurring obligation: rent, a subscription, an instalment.
  static const IconData obligation = Icons.event_repeat;

  // ── Sync state ───────────────────────────────────────────────────────────

  /// Saved on the device, not yet on the server.
  static const IconData pending = Icons.cloud_off;

  /// Sent.
  static const IconData synced = Icons.cloud_done;

  /// Given up on, and waiting for the user to decide.
  static const IconData failed = Icons.warning;

  // ── Household ────────────────────────────────────────────────────────────

  /// The pantry.
  static const IconData inventory = Icons.inventory_2;

  /// The shopping list.
  static const IconData shopping = Icons.shopping_cart;

  /// Medicines and doses.
  static const IconData pharmacy = Icons.local_pharmacy;

  /// شيف زاد and the recipes.
  static const IconData chef = Icons.restaurant;

  /// How long something takes.
  static const IconData duration = Icons.schedule;

  /// An opinion: liked it.
  static const IconData like = Icons.thumb_up;

  /// An opinion: did not.
  static const IconData dislike = Icons.thumb_down;

  /// Prices: what things cost, and where.
  static const IconData prices = Icons.local_offer;

  /// A shop.
  static const IconData store = Icons.storefront;

  /// Where the customer is.
  static const IconData location = Icons.near_me;

  /// Who reports most.
  static const IconData leaderboard = Icons.emoji_events;

  /// The family.
  static const IconData family = Icons.family_restroom;

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Add.
  static const IconData add = Icons.add;

  /// Scan a receipt.
  static const IconData scan = Icons.camera_alt;

  /// Speak.
  static const IconData voice = Icons.mic;

  /// Retry.
  static const IconData retry = Icons.refresh;

  /// Dismiss.
  static const IconData dismiss = Icons.close;

  /// Search a list.
  static const IconData search = Icons.search;

  /// The chosen one of several options.
  static const IconData selected = Icons.check_circle;

  /// A country, a market.
  static const IconData market = Icons.public;

  // ── Recurring charges ────────────────────────────────────────────────────

  /// A subscription — something that renews.
  static const IconData recurring = Icons.event_repeat;

  /// A utility bill.
  static const IconData bill = Icons.bolt;

  /// Mark a charge paid.
  static const IconData paid = Icons.event_available;

  /// Stop something that runs.
  static const IconData pause = Icons.pause_circle;

  /// Start it again.
  static const IconData resume = Icons.play_circle;

  /// Edit.
  static const IconData edit = Icons.edit;

  /// Delete for good.
  static const IconData delete = Icons.delete_outline;

  /// Notifications.
  static const IconData notifications = Icons.notifications;

  /// No notifications.
  static const IconData noNotifications = Icons.notifications_none;

  /// Mark everything read.
  static const IconData markAllRead = Icons.done_all;

  /// عقل زاد: what the assistant knows, did and is doing.
  static const IconData brain = Icons.psychology;

  /// What زاد remembers about the customer.
  static const IconData memory = Icons.lightbulb;

  /// Who the customer is to زاد.
  static const IconData profile = Icons.badge;

  /// Habits and outings learned from behaviour.
  static const IconData habits = Icons.insights;

  /// The log of what زاد changed.
  static const IconData actionLog = Icons.history;

  /// Take a change back.
  static const IconData undo = Icons.undo;

  /// How the customer's areas connect.
  static const IconData knowledgeMap = Icons.hub;

  /// Whether the brain is working.
  static const IconData brainHealth = Icons.monitor_heart;

  /// Appliances and their upkeep.
  static const IconData maintenance = Icons.build;

  /// Ask زاد about something.
  static const IconData ask = Icons.chat;

  /// Open a folded list — "كل الأقسام".
  static const IconData expand = Icons.expand_more;

  /// Forward, in reading order.
  ///
  /// Mirrors under RTL (`matchTextDirection: true`), as Kotlin's AutoMirrored
  /// arrow does. Hand-picking a left arrow for Arabic would bake in one
  /// direction, and the day a screen renders LTR the arrow points backwards.
  static const IconData forward = _kArrowRightMirrored;

  /// Back, in reading order. Mirrors under RTL for the same reason.
  static const IconData back = Icons.arrow_back;

  // ── Family ───────────────────────────────────────────────────────────────

  /// An emergency call to the family.
  static const IconData sos = Icons.warning;

  /// Invite someone.
  static const IconData invite = Icons.person_add;

  /// Join a family by code.
  static const IconData joinFamily = Icons.group_add;

  /// Share.
  static const IconData share = Icons.share;

  /// Pin a message.
  static const IconData pin = Icons.push_pin;

  /// React to a message.
  static const IconData react = Icons.emoji_emotions;

  /// A poll.
  static const IconData poll = Icons.bar_chart;

  /// A chore.
  static const IconData chore = Icons.assignment;

  /// An admin.
  static const IconData admin = Icons.star;

  /// A child.
  static const IconData child = Icons.child_care;

  /// Pocket money.
  static const IconData coins = Icons.monetization_on;

  /// Not done yet.
  static const IconData open = Icons.radio_button_unchecked;

  /// Leave.
  static const IconData leave = Icons.exit_to_app;

  /// A reward.
  static const IconData gift = Icons.card_giftcard;

  /// Copy.
  static const IconData copy = Icons.content_copy;

  /// Savings.
  static const IconData savings = Icons.savings;

  /// A tasbiha tree.
  static const IconData tree = Icons.park;

  /// Play.
  static const IconData play = Icons.play_arrow;

  /// A QR code.
  static const IconData qr = Icons.qr_code;

  /// Turned down.
  static const IconData rejected = Icons.cancel;

  /// A wallet.
  static const IconData wallet = Icons.account_balance_wallet;
}
