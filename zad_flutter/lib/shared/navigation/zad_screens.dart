/// The screens and sheets one feature opens on behalf of another.
///
/// A feature never imports another feature's UI. When the pantry's row has
/// to open the camera, or the notification center has to open the
/// subscriptions list, it calls [ZadScreens]; `app/wiring/screens_wiring.dart`
/// binds each entry to the feature that owns the screen. The owner can then
/// change its screen — its route, its layout, its own state — without the
/// callers noticing, which is the point.
///
/// Every entry has the signature of the function it is bound to, so a call
/// through here behaves exactly as the direct call did.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/brain/domain/customer_profile.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/scan/data/vision_scanner.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// Opens a screen with nothing but the context.
typedef OpenScreen = Future<void> Function(BuildContext context);

/// Screens and sheets, by the feature that owns them.
abstract final class ZadScreens {
  // ── achievements
  /// الإنجازات والرتب.
  static late OpenScreen showAchievementsScreen;

  // ── appointments
  /// المواعيد.
  static late OpenScreen showAppointmentsScreen;

  // ── auth
  /// Asks, then signs out.
  static late Future<void> Function(BuildContext context, WidgetRef ref)
  confirmAndSignOut;

  // ── bank
  /// The bank-reading guide.
  static late OpenScreen showBankAccessGuide;

  /// Turns bank reading on, or explains how.
  static late Future<void> Function(BuildContext context, WidgetRef ref)
  openBankReading;

  // ── brain
  /// سجل تعديلات زاد.
  static late OpenScreen showAgentActionLog;

  /// صحة عقل زاد.
  static late OpenScreen showBrainHealth;

  /// عقل زاد's hub.
  static late OpenScreen showBrainHub;

  /// خريطة زاد.
  static late OpenScreen showKnowledgeMap;

  /// زاد عارف عني إيه.
  static late OpenScreen showMemoryScreen;

  /// «عرّفني بيك».
  static late Future<CustomerProfile?> Function(
    BuildContext context,
    CustomerProfile? current,
  )
  showProfileSheet;

  /// Why a figure changed.
  static late void Function(BuildContext context) openWhyChanged;

  // ── brain & family
  /// The brain and family screen, on `tab`.
  static late Future<void> Function(BuildContext context, {BrainFamilyTab tab})
  showBrainFamily;

  // ── budget
  /// الحسابات, on `initialTab`.
  static late Future<void> Function(BuildContext context, {int initialTab})
  showFinancesScreen;

  // ── family
  /// العائلة, on `initialTab`.
  static late Future<void> Function(BuildContext context, {int initialTab})
  showFamilyScreen;

  // ── goals
  /// Picks a life goal; true when one was chosen.
  static late Future<bool> Function(BuildContext context)
  showLifeGoalPickerSheet;

  // ── household
  /// البيت, on `section`.
  static late Future<void> Function(
    BuildContext context,
    HouseholdSection section,
  )
  showHouseholdSection;

  // ── intelligence
  /// عقل زاد's analysis screen.
  static late OpenScreen showIntelligenceScreen;

  // ── inventory
  /// Adds a pantry item.
  static late OpenScreen showAddPantrySheet;

  /// Adds a shopping item.
  static late OpenScreen showAddShoppingSheet;

  // ── kids
  /// The kids-mode PIN; true when it was entered.
  static late Future<bool> Function(BuildContext context) showPinPrompt;

  // ── obligations
  /// Saves a utility bill as an obligation — the one home for bills
  /// (20261005235107); a bill in the subscriptions table was counted twice
  /// by the budget once it was also an obligation.
  static late Future<void> Function(
    WidgetRef ref, {
    required String title,
    required double amount,
    int? dueDay,
    bool yearly,
  })
  addUtilityBill;

  // ── maintenance
  /// الصيانة.
  static late OpenScreen showMaintenanceScreen;

  // ── documents
  /// مستنداتي — حارس المستندات.
  static late OpenScreen showDocumentsScreen;

  // ── nearby
  /// Shops near the customer.
  static late OpenScreen showNearbyDealsScreen;

  // ── places
  /// «أماكني»: place reminders, outings and the habits learned from them.
  static late OpenScreen showMyPlaces;

  // ── notifications
  /// The notification center.
  static late OpenScreen showNotificationCenter;

  // ── orb
  /// «زيّن زاد».
  static late OpenScreen showOrbPicker;

  // ── paywall
  /// The subscription paywall.
  static late OpenScreen showPaywallScreen;

  // ── pharmacy
  /// Adds a medicine, from a scan when `scanned` is given.
  static late Future<void> Function(
    BuildContext context, {
    ScannedMedicine? scanned,
  })
  showAddMedicineSheet;

  // ── prices
  /// أسعار الناس.
  static late OpenScreen showPricesScreen;

  // ── profile
  /// The profile.
  static late OpenScreen showProfileScreen;

  /// The market and currency sheet.
  static late OpenScreen showRegionalSheet;

  // ── recommendations
  /// اقتراحات زاد.
  static late OpenScreen showRecommendationsScreen;

  // ── savings
  /// The family savings.
  static late OpenScreen showFamilySavingsScreen;

  // ── scan
  /// The shell's camera.
  static late OpenScreen openZadCamera;

  /// The camera, on `mode`.
  static late Future<void> Function(BuildContext context, CameraMode mode)
  showCameraScreen;

  /// A pantry photo.
  static late OpenScreen showPantryPhotoSheet;

  /// A receipt scan.
  static late Future<void> Function(BuildContext context, WidgetRef ref)
  showReceiptScanSheet;

  // ── settings
  /// The monthly limit.
  static late OpenScreen showMonthlyLimitSheet;

  /// الإعدادات.
  static late OpenScreen showSettingsScreen;

  // ── statement
  /// Imports a bank statement.
  static late OpenScreen showStatementImportScreen;

  // ── subscriptions
  /// الاشتراكات.
  static late OpenScreen showSubscriptionsScreen;

  /// Adds a subscription, or edits `subscription`.
  static late Future<void> Function(
    BuildContext context, {
    Subscription? subscription,
  })
  showAddEditSubscriptionDialog;

  // ── support
  /// المساعدة والدعم.
  static late OpenScreen showHelpSupportScreen;

  /// الشروط.
  static late OpenScreen showTermsScreen;

  // ── tasbiha
  /// التسبيحة.
  static late OpenScreen showTasbihaScreen;

  // ── transactions
  /// Adds a transaction.
  static late OpenScreen showAddTransactionSheet;

  /// Edits `txn`.
  static late Future<void> Function(BuildContext context, ZadTransaction txn)
  showEditTransactionSheet;

  /// Asks before deleting `txn`; true when it was deleted.
  static late Future<bool> Function(
    BuildContext context,
    WidgetRef ref,
    ZadTransaction txn,
  )
  confirmDeleteTransaction;

  /// A quick expense.
  static late OpenScreen showQuickExpenseSheet;
}
