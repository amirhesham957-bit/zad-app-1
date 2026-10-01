/// Binds [ZadScreens] and [ZadSlots] to the features that own each screen
/// and section. Called by `wireZad`.
library;

import 'package:zad/features/achievements/presentation/achievements_screen.dart';
import 'package:zad/features/affiliate/presentation/affiliate_product_card.dart';
import 'package:zad/features/affiliate/presentation/affiliate_suggestion.dart';
import 'package:zad/features/alerts/presentation/alerts_settings_section.dart';
import 'package:zad/features/appointments/presentation/appointments_screen.dart';
import 'package:zad/features/auth/presentation/sign_out_action.dart';
import 'package:zad/features/bank/presentation/bank_access_guide_screen.dart';
import 'package:zad/features/bank/presentation/stuck_notifications.dart';
import 'package:zad/features/brain/presentation/agent_action_log_screen.dart';
import 'package:zad/features/brain/presentation/brain_health_screen.dart';
import 'package:zad/features/brain/presentation/brain_hub_screen.dart';
import 'package:zad/features/brain/presentation/knowledge_map_screen.dart';
import 'package:zad/features/brain/presentation/memory_screen.dart';
import 'package:zad/features/brain/presentation/profile_sheet.dart';
import 'package:zad/features/brain/presentation/why_changed_sheet.dart';
import 'package:zad/features/brain_family/presentation/brain_family_screen.dart';
import 'package:zad/features/budget/presentation/finances_screen.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/features/chat/presentation/intelligence_chat_card.dart';
import 'package:zad/features/debts/presentation/debts_tab.dart';
import 'package:zad/features/family/presentation/family_screen.dart';
import 'package:zad/features/goals/presentation/life_goal_picker_sheet.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/insights/presentation/insight_cards.dart';
import 'package:zad/features/intelligence/presentation/home_reports_row.dart';
import 'package:zad/features/intelligence/presentation/intelligence_screen.dart';
import 'package:zad/features/inventory/presentation/pantry_view.dart';
import 'package:zad/features/inventory/presentation/shopping_list_view.dart';
import 'package:zad/features/kids/presentation/pin_prompt_dialog.dart';
import 'package:zad/features/maintenance/presentation/maintenance_screen.dart';
import 'package:zad/features/modes/presentation/modes_cards.dart';
import 'package:zad/features/nearby/presentation/nearby_deals_screen.dart';
import 'package:zad/features/notifications/presentation/notification_center_screen.dart';
import 'package:zad/features/obligations/presentation/obligations_section.dart';
import 'package:zad/features/orb/presentation/orb_picker_dialog.dart';
import 'package:zad/features/paywall/presentation/paywall_screen.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_view.dart';
import 'package:zad/features/places/presentation/keep_alive_guide.dart';
import 'package:zad/features/places/presentation/my_places_screen.dart';
import 'package:zad/features/places/presentation/street_alerts_section.dart';
import 'package:zad/features/prices/presentation/live_market_ticker.dart';
import 'package:zad/features/prices/presentation/prices_screen.dart';
import 'package:zad/features/profile/presentation/profile_screen.dart';
import 'package:zad/features/proposals/presentation/proposals_screen.dart';
import 'package:zad/features/recipes/presentation/home_chef_section.dart';
import 'package:zad/features/recipes/presentation/recipes_view.dart';
import 'package:zad/features/recommendations/presentation/recommendations_screen.dart';
import 'package:zad/features/savings/presentation/family_savings_screen.dart';
import 'package:zad/features/scan/presentation/camera_screen.dart';
import 'package:zad/features/scan/presentation/photo_scan_sheet.dart';
import 'package:zad/features/scan/presentation/receipt_scan_sheet.dart';
import 'package:zad/features/settings/presentation/monthly_limit_sheet.dart';
import 'package:zad/features/settings/presentation/settings_screen.dart';
import 'package:zad/features/statement/presentation/statement_import_screen.dart';
import 'package:zad/features/subscriptions/presentation/subscriptions_screen.dart';
import 'package:zad/features/support/presentation/help_support_screen.dart';
import 'package:zad/features/support/presentation/terms_screen.dart';
import 'package:zad/features/tasbiha/presentation/tasbiha_screen.dart';
import 'package:zad/features/telegram/presentation/telegram_binding.dart';
import 'package:zad/features/transactions/presentation/add_transaction_sheet.dart';
import 'package:zad/features/transactions/presentation/edit_transaction_sheet.dart';
import 'package:zad/features/transactions/presentation/quick_expense_sheet.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';

/// Binds the screens.
void wireScreens() {
  ZadScreens.showAchievementsScreen = showAchievementsScreen;
  ZadScreens.showAppointmentsScreen = showAppointmentsScreen;
  ZadScreens.showMyPlaces = showMyPlacesScreen;
  ZadScreens.confirmAndSignOut = confirmAndSignOut;
  ZadScreens.showBankAccessGuide = showBankAccessGuide;
  ZadScreens.openBankReading = openBankReading;
  ZadScreens.showAgentActionLog = showAgentActionLog;
  ZadScreens.showBrainHealth = showBrainHealth;
  ZadScreens.showBrainHub = showBrainHub;
  ZadScreens.showKnowledgeMap = showKnowledgeMap;
  ZadScreens.showMemoryScreen = showMemoryScreen;
  ZadScreens.showProfileSheet = showProfileSheet;
  ZadScreens.openWhyChanged = openWhyChanged;
  ZadScreens.showBrainFamily = showBrainFamily;
  ZadScreens.showFinancesScreen = showFinancesScreen;
  ZadScreens.showFamilyScreen = showFamilyScreen;
  ZadScreens.showLifeGoalPickerSheet = showLifeGoalPickerSheet;
  ZadScreens.showHouseholdSection = showHouseholdSection;
  ZadScreens.showIntelligenceScreen = showIntelligenceScreen;
  ZadScreens.showAddPantrySheet = showAddPantrySheet;
  ZadScreens.showAddShoppingSheet = showAddShoppingSheet;
  ZadScreens.showPinPrompt = showPinPrompt;
  ZadScreens.showMaintenanceScreen = showMaintenanceScreen;
  ZadScreens.showNearbyDealsScreen = showNearbyDealsScreen;
  ZadScreens.showNotificationCenter = showNotificationCenter;
  ZadScreens.showOrbPicker = showOrbPicker;
  ZadScreens.showPaywallScreen = showPaywallScreen;
  ZadScreens.showAddMedicineSheet = showAddMedicineSheet;
  ZadScreens.showPricesScreen = showPricesScreen;
  ZadScreens.showProfileScreen = showProfileScreen;
  ZadScreens.showRegionalSheet = showRegionalSheet;
  ZadScreens.showRecommendationsScreen = showRecommendationsScreen;
  ZadScreens.showFamilySavingsScreen = showFamilySavingsScreen;
  ZadScreens.openZadCamera = openZadCamera;
  ZadScreens.showCameraScreen = showCameraScreen;
  ZadScreens.showPantryPhotoSheet = showPantryPhotoSheet;
  ZadScreens.showReceiptScanSheet = showReceiptScanSheet;
  ZadScreens.showMonthlyLimitSheet = showMonthlyLimitSheet;
  ZadScreens.showSettingsScreen = showSettingsScreen;
  ZadScreens.showStatementImportScreen = showStatementImportScreen;
  ZadScreens.showSubscriptionsScreen = showSubscriptionsScreen;
  ZadScreens.showAddEditSubscriptionDialog = showAddEditSubscriptionDialog;
  ZadScreens.showHelpSupportScreen = showHelpSupportScreen;
  ZadScreens.showTermsScreen = showTermsScreen;
  ZadScreens.showTasbihaScreen = showTasbihaScreen;
  ZadScreens.showAddTransactionSheet = showAddTransactionSheet;
  ZadScreens.showEditTransactionSheet = showEditTransactionSheet;
  ZadScreens.confirmDeleteTransaction = confirmDeleteTransaction;
  ZadScreens.showQuickExpenseSheet = showQuickExpenseSheet;
}

/// Binds the slots.
void wireSlots() {
  ZadSlots.affiliateProductCard = ({required product, required onBuy, width}) =>
      AffiliateProductCard(product: product, onBuy: onBuy, width: width);
  ZadSlots.affiliateSuggestionSection = () =>
      const AffiliateSuggestionSection();
  ZadSlots.alertsSettingsSection = () => const AlertsSettingsSection();
  ZadSlots.signOutAction = () => const SignOutAction();
  ZadSlots.signOutTile = () => const SignOutTile();
  ZadSlots.stuckNotificationsSlot = () => const StuckNotificationsSlot();
  ZadSlots.chatScreen = () => const ChatScreen();
  ZadSlots.chatSectionCard = ({required expanded, required onToggle}) =>
      ChatSectionCard(expanded: expanded, onToggle: onToggle);
  ZadSlots.debtsTab = () => const DebtsTab();
  ZadSlots.liveDealsCard = () => const LiveDealsCard();
  ZadSlots.familyScreen = ({key, showFinancials = true, initialTab = 0}) =>
      FamilyScreen(
        key: key,
        showFinancials: showFinancials,
        initialTab: initialTab,
      );
  ZadSlots.homeInsightsSection = ({onOpenCamera}) =>
      HomeInsightsSection(onOpenCamera: onOpenCamera);
  ZadSlots.intelligenceScreen = ({key, embedded = false}) =>
      IntelligenceScreen(key: key, embedded: embedded);
  ZadSlots.homeReportsRow =
      ({
        required spent,
        required spendable,
        required daysLeft,
        required currency,
      }) => HomeReportsRow(
        spent: spent,
        spendable: spendable,
        daysLeft: daysLeft,
        currency: currency,
      );
  ZadSlots.pantryView = ({shortagesFirst = false}) =>
      PantryView(shortagesFirst: shortagesFirst);
  ZadSlots.shoppingListView = () => const ShoppingListView();
  ZadSlots.brokeModeSlot = ({offerEntry = false}) =>
      BrokeModeSlot(offerEntry: offerEntry);
  ZadSlots.savingsChallengeSlot = ({offerEntry = false, offerStop = false}) =>
      SavingsChallengeSlot(offerEntry: offerEntry, offerStop: offerStop);
  ZadSlots.obligationsSection = () => const ObligationsSection();
  ZadSlots.obligationRows = ({required kinds, title, whenEmpty}) =>
      ObligationRows(kinds: kinds, title: title, whenEmpty: whenEmpty);
  ZadSlots.pharmacyView = () => const PharmacyView();
  ZadSlots.streetAlertsSection = () => const StreetAlertsSection();
  ZadSlots.keepAliveGuide = () => const KeepAliveGuide();
  ZadSlots.liveMarketTickerSlot = () => const LiveMarketTickerSlot();
  ZadSlots.homeProposalsSection = () => const HomeProposalsSection();
  ZadSlots.proposalCard =
      ({
        required proposal,
        required busy,
        required failed,
        required onDecide,
      }) => ProposalCard(
        proposal: proposal,
        busy: busy,
        failed: failed,
        onDecide: onDecide,
      );
  ZadSlots.homeChefSection = () => const HomeChefSection();
  ZadSlots.recipesView = () => const RecipesView();
  ZadSlots.subscriptionsScreen = ({embedded = false, initialTab = 0}) =>
      SubscriptionsScreen(embedded: embedded, initialTab: initialTab);
  ZadSlots.homeTelegramBlocks = () => const HomeTelegramBlocks();
}
