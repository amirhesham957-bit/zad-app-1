/// The icon set: Lucide, bundled as a font.
///
/// Two things this does that the Kotlin app's `LucideIcon.kt` does not.
///
/// It ships the glyphs. That implementation fetches each icon from a CDN at use
/// site, so a first launch without a network draws nothing — which is the
/// opposite of what an offline-first app should do with its own chrome. Here
/// the icons are a font in the bundle and work with the radio off.
///
/// And it names meanings, not glyphs. A screen asks for [ZadIcons.expense], not
/// for `arrow-down-circle`, so the day somebody decides expenses should point a
/// different way there is one line to change instead of forty call sites — and
/// no screen can drift onto a near-miss glyph that means almost the same thing.
library;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The icons this app uses, by what they mean.
abstract final class ZadIcons {
  // ── Navigation ───────────────────────────────────────────────────────────

  /// Home.
  static const IconData home = LucideIcons.house;

  /// The budget screen.
  static const IconData budget = LucideIcons.wallet;

  /// Assistant / chat.
  static const IconData assistant = LucideIcons.sparkles;

  /// Settings.
  static const IconData settings = LucideIcons.settings;

  // ── Money ────────────────────────────────────────────────────────────────

  /// Money out.
  static const IconData expense = LucideIcons.arrowDownCircle;

  /// Money in.
  static const IconData income = LucideIcons.arrowUpCircle;

  /// Money moved between the user's own wallets.
  static const IconData transfer = LucideIcons.arrowLeftRight;

  /// Cash.
  static const IconData cash = LucideIcons.banknote;

  /// A card.
  static const IconData card = LucideIcons.creditCard;

  /// A bank account.
  static const IconData bank = LucideIcons.landmark;

  /// A recurring obligation: rent, a subscription, an instalment.
  static const IconData obligation = LucideIcons.calendarClock;

  // ── Sync state ───────────────────────────────────────────────────────────

  /// Saved on the device, not yet on the server.
  static const IconData pending = LucideIcons.cloudOff;

  /// Sent.
  static const IconData synced = LucideIcons.cloudCheck;

  /// Given up on, and waiting for the user to decide.
  static const IconData failed = LucideIcons.triangleAlert;

  // ── Household ────────────────────────────────────────────────────────────

  /// The pantry.
  static const IconData inventory = LucideIcons.package;

  /// The shopping list.
  static const IconData shopping = LucideIcons.shoppingCart;

  /// Medicines and doses.
  static const IconData pharmacy = LucideIcons.pill;

  /// The family.
  static const IconData family = LucideIcons.users;

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Add.
  static const IconData add = LucideIcons.plus;

  /// Scan a receipt.
  static const IconData scan = LucideIcons.scanLine;

  /// Speak.
  static const IconData voice = LucideIcons.mic;

  /// Retry.
  static const IconData retry = LucideIcons.rotateCw;

  /// Dismiss.
  static const IconData dismiss = LucideIcons.x;

  /// Search a list.
  static const IconData search = LucideIcons.search;

  /// The chosen one of several options.
  static const IconData selected = LucideIcons.circleCheck;

  /// A country, a market.
  static const IconData market = LucideIcons.globe;

  /// Forward, in reading order.
  ///
  /// The `Dir` variant, which carries `matchTextDirection: true` and so mirrors
  /// itself under RTL. That is the reason to use it rather than picking
  /// `chevronLeft` by hand: hand-picking bakes in one direction, and the day a
  /// screen renders LTR — an English figure, a number pad, a debug page — the
  /// chevron points backwards. A `RotatedBox` around it is the same mistake
  /// with extra steps.
  static const IconData forward = LucideIcons.chevronRightDir;

  /// Back, in reading order. Mirrors under RTL for the same reason.
  static const IconData back = LucideIcons.chevronLeftDir;
}
