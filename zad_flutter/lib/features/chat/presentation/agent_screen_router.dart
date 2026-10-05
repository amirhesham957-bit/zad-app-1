/// Carries out the agent's `app_command`: opens the screen it named, over the
/// chat, so back returns to the conversation. `add_item` also opens that
/// screen's add form where it has one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/chat/domain/agent_screen.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

/// Opens what [command] names. Returns once the screen is pushed, not when
/// it closes.
void openAgentScreen(
  BuildContext context,
  WidgetRef ref,
  AgentAppCommand command,
) {
  final add = command.action == AgentScreenAction.addItem;

  void household(HouseholdSection section, [Future<void> Function()? form]) {
    unawaited(ZadScreens.showHouseholdSection(context, section));
    if (add && form != null) unawaited(form());
  }

  switch (command.screen) {
    case AgentScreen.home:
      // The one destination that is the shell itself, not a page over it.
      Navigator.of(context).popUntil((r) => r.isFirst);
      ref.read(shellNavigationProvider.notifier).open(ShellTab.home);
    case AgentScreen.inventory:
      household(
        HouseholdSection.pantry,
        () => ZadScreens.showAddPantrySheet(context),
      );
    case AgentScreen.shopping:
      household(
        HouseholdSection.shopping,
        () => ZadScreens.showAddShoppingSheet(context),
      );
    case AgentScreen.pharmacy:
      household(
        HouseholdSection.pharmacy,
        () => ZadScreens.showAddMedicineSheet(context),
      );
    case AgentScreen.recipes:
      household(HouseholdSection.recipes);
    case AgentScreen.budget:
    case AgentScreen.obligations:
      unawaited(ZadScreens.showFinancesScreen(context));
    case AgentScreen.debts:
      unawaited(ZadScreens.showFinancesScreen(context, initialTab: 2));
    case AgentScreen.subscriptions:
      unawaited(ZadScreens.showSubscriptionsScreen(context));
      if (add) unawaited(ZadScreens.showAddEditSubscriptionDialog(context));
    case AgentScreen.family:
      unawaited(ZadScreens.showFamilyScreen(context));
    case AgentScreen.tasks:
      unawaited(ZadScreens.showFamilyScreen(context, initialTab: 1));
    case AgentScreen.maintenance:
      unawaited(ZadScreens.showMaintenanceScreen(context));
    case AgentScreen.documents:
      unawaited(ZadScreens.showDocumentsScreen(context));
    case AgentScreen.insights:
      unawaited(ZadScreens.showIntelligenceScreen(context));
    case AgentScreen.camera:
      unawaited(ZadScreens.showPantryPhotoSheet(context));
    case AgentScreen.cameraReceipt:
      unawaited(ZadScreens.showReceiptScanSheet(context, ref));
    case AgentScreen.tasbiha:
      unawaited(ZadScreens.showTasbihaScreen(context));
    case AgentScreen.notifications:
      unawaited(ZadScreens.showNotificationCenter(context));
    case AgentScreen.profile:
      unawaited(ZadScreens.showProfileScreen(context));
    case AgentScreen.statement:
      unawaited(ZadScreens.showStatementImportScreen(context));
    case AgentScreen.appointments:
      unawaited(ZadScreens.showAppointmentsScreen(context));
    case AgentScreen.zadMemory:
      unawaited(ZadScreens.showMemoryScreen(context));
    case AgentScreen.agentActionLog:
      unawaited(ZadScreens.showAgentActionLog(context));
    case AgentScreen.assistantAlerts:
      unawaited(ZadScreens.showSettingsScreen(context));
    case AgentScreen.prices:
      unawaited(ZadScreens.showPricesScreen(context));
    case AgentScreen.goals:
      unawaited(ZadScreens.showLifeGoalPickerSheet(context));
    case AgentScreen.nearby:
      unawaited(ZadScreens.showNearbyDealsScreen(context));
  }
}
