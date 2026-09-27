/// Carries out the agent's `app_command`: opens the screen it named, over the
/// chat, so back returns to the conversation. `add_item` also opens that
/// screen's add form where it has one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/features/appointments/presentation/appointments_screen.dart';
import 'package:zad/features/brain/presentation/agent_action_log_screen.dart';
import 'package:zad/features/brain/presentation/memory_screen.dart';
import 'package:zad/features/budget/presentation/finances_screen.dart';
import 'package:zad/features/chat/domain/agent_screen.dart';
import 'package:zad/features/family/presentation/family_screen.dart';
import 'package:zad/features/goals/presentation/life_goal_picker_sheet.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/intelligence/presentation/intelligence_screen.dart';
import 'package:zad/features/inventory/presentation/pantry_view.dart';
import 'package:zad/features/inventory/presentation/shopping_list_view.dart';
import 'package:zad/features/maintenance/presentation/maintenance_screen.dart';
import 'package:zad/features/nearby/presentation/nearby_deals_screen.dart';
import 'package:zad/features/notifications/presentation/notification_center_screen.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_view.dart';
import 'package:zad/features/prices/presentation/prices_screen.dart';
import 'package:zad/features/profile/presentation/profile_screen.dart';
import 'package:zad/features/scan/presentation/photo_scan_sheet.dart';
import 'package:zad/features/scan/presentation/receipt_scan_sheet.dart';
import 'package:zad/features/settings/presentation/settings_screen.dart';
import 'package:zad/features/statement/presentation/statement_import_screen.dart';
import 'package:zad/features/subscriptions/presentation/subscriptions_screen.dart';
import 'package:zad/features/tasbiha/presentation/tasbiha_screen.dart';

/// Opens what [command] names. Returns once the screen is pushed, not when
/// it closes.
void openAgentScreen(
  BuildContext context,
  WidgetRef ref,
  AgentAppCommand command,
) {
  final add = command.action == AgentScreenAction.addItem;

  void household(HouseholdSection section, [Future<void> Function()? form]) {
    unawaited(showHouseholdSection(context, section));
    if (add && form != null) unawaited(form());
  }

  switch (command.screen) {
    case AgentScreen.home:
      // The one destination that is the shell itself, not a page over it.
      Navigator.of(context).popUntil((r) => r.isFirst);
      ref.read(shellNavigationProvider.notifier).open(ShellTab.home);
    case AgentScreen.inventory:
      household(HouseholdSection.pantry, () => showAddPantrySheet(context));
    case AgentScreen.shopping:
      household(HouseholdSection.shopping, () => showAddShoppingSheet(context));
    case AgentScreen.pharmacy:
      household(HouseholdSection.pharmacy, () => showAddMedicineSheet(context));
    case AgentScreen.recipes:
      household(HouseholdSection.recipes);
    case AgentScreen.budget:
    case AgentScreen.obligations:
      unawaited(showFinancesScreen(context));
    case AgentScreen.debts:
      unawaited(showFinancesScreen(context, initialTab: 2));
    case AgentScreen.subscriptions:
      unawaited(showSubscriptionsScreen(context));
      if (add) unawaited(showSubscriptionSheet(context));
    case AgentScreen.family:
      unawaited(showFamilyScreen(context));
    case AgentScreen.tasks:
      unawaited(showFamilyScreen(context, initialTab: 1));
    case AgentScreen.maintenance:
      unawaited(showMaintenanceScreen(context));
    case AgentScreen.insights:
      unawaited(showIntelligenceScreen(context));
    case AgentScreen.camera:
      unawaited(showPantryPhotoSheet(context));
    case AgentScreen.cameraReceipt:
      unawaited(showReceiptScanSheet(context, ref));
    case AgentScreen.tasbiha:
      unawaited(showTasbihaScreen(context));
    case AgentScreen.notifications:
      unawaited(showNotificationCenter(context));
    case AgentScreen.profile:
      unawaited(showProfileScreen(context));
    case AgentScreen.statement:
      unawaited(showStatementImportScreen(context));
    case AgentScreen.appointments:
      unawaited(showAppointmentsScreen(context));
    case AgentScreen.zadMemory:
      unawaited(showMemoryScreen(context));
    case AgentScreen.agentActionLog:
      unawaited(showAgentActionLog(context));
    case AgentScreen.assistantAlerts:
      unawaited(showSettingsScreen(context));
    case AgentScreen.prices:
      unawaited(showPricesScreen(context));
    case AgentScreen.goals:
      unawaited(showLifeGoalPickerSheet(context));
    case AgentScreen.nearby:
      unawaited(showNearbyDealsScreen(context));
  }
}
