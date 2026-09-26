/// Kotlin's `MainScreen` chrome: the header on top, the screen, the floating
/// pill at the bottom, the drawer behind the menu square — drawn once here
/// and never by a screen.
///
/// The bar has Kotlin's three screens (الرئيسية, عقل زاد, المخزون), the mic
/// orb and the camera between them, and المزيد. Every other section opens
/// over the shell from the grid, the drawer or the المزيد sheet.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/shell/zad_bottom_nav_bar.dart';
import 'package:zad/app/shell/zad_chrome.dart';
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/features/alerts/application/alerts_controller.dart';
import 'package:zad/features/alerts/application/local_reminders.dart';
import 'package:zad/features/brain_family/presentation/brain_family_screen.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/budget/presentation/budget_gate_screen.dart';
import 'package:zad/features/chat/application/voice_input_controller.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/features/home/presentation/home_screen.dart';
import 'package:zad/features/home/presentation/sections_grid.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/kids/application/kids_mode_controller.dart';
import 'package:zad/features/kids/presentation/kids_shell.dart';
import 'package:zad/features/nearby/presentation/nearby_deals_screen.dart';
import 'package:zad/features/notifications/application/notifications_controller.dart';
import 'package:zad/features/notifications/presentation/notification_center_screen.dart';
import 'package:zad/features/orb/presentation/floating_companion.dart';
import 'package:zad/features/profile/application/profile_controller.dart';
import 'package:zad/features/profile/presentation/profile_screen.dart';
import 'package:zad/features/scan/presentation/photo_scan_sheet.dart';
import 'package:zad/features/scan/presentation/receipt_scan_sheet.dart';
import 'package:zad/features/settings/application/settings_controller.dart';
import 'package:zad/features/transactions/presentation/transactions_screen.dart';

/// Holds the tabs.
class ZadShell extends ConsumerStatefulWidget {
  /// Creates the shell.
  const new({super.key});

  @override
  ConsumerState<ZadShell> createState() => _ZadShellState();
}

class _ZadShellState extends ConsumerState<ZadShell> {
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();

  ZadNavDestination _tab = ZadNavDestination.home;

  // عقل زاد and المخزون fetch when they first build, so each is built on its
  // first visit and then kept — an IndexedStack builds every child up front,
  // and a launch should not spend a round of network on tabs nobody opened.
  bool _assistantOpened = false;
  bool _inventoryOpened = false;

  static const List<ZadNavDestination> _tabs = <ZadNavDestination>[
    ZadNavDestination.home,
    ZadNavDestination.assistant,
    ZadNavDestination.inventory,
  ];

  @override
  void initState() {
    super.initState();
    // The shell exists only while somebody is signed in, which is exactly
    // when this device's token belongs on an account. After the first frame:
    // starting changes provider state, and the permission prompt should come
    // over a drawn screen, not a blank one.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final alerts = ref.read(alertsControllerProvider.notifier);
      await alerts.start();
      if (mounted) await alerts.askOnce();
      // Kotlin's on-phone reminders: doses, tasbih at 17:00, seasons.
      if (mounted) await ref.read(localRemindersProvider).resyncAll();
    });
  }

  void _show(ZadNavDestination tab) => setState(() {
    _tab = tab;
    if (tab == ZadNavDestination.assistant) _assistantOpened = true;
    if (tab == ZadNavDestination.inventory) _inventoryOpened = true;
  });

  /// Kotlin's screen titles (`zadScreenTitle`).
  String get _title => switch (_tab) {
    ZadNavDestination.assistant => 'عقل زاد',
    ZadNavDestination.inventory => 'المخزون',
    _ => 'لوحة الميزانية',
  };

  /// A route id from the drawer, the المزيد sheet or the grid.
  Future<void> _go(String id) async {
    switch (id) {
      case 'home':
        _show(ZadNavDestination.home);
      case 'inventory':
        _show(ZadNavDestination.inventory);
      case 'assistant':
        _show(ZadNavDestination.assistant);
      case 'deals':
        await showNearbyDealsScreen(context);
      default:
        for (final s in zadSections) {
          if (s.id == id) {
            await s.open(context);
            return;
          }
        }
    }
  }

  Future<void> _openCamera() async {
    final choice = await showZadCameraSheet(context);
    if (!mounted || choice == null) return;
    switch (choice) {
      case ZadCameraChoice.inventory:
        await showPantryPhotoSheet(context);
      case ZadCameraChoice.receipt:
        await showReceiptScanSheet(context, ref);
    }
  }

  /// The mic orb: Kotlin's voice sheet. Here the conversation opens with the
  /// microphone already listening; what is heard lands in the composer.
  Future<void> _openVoice() async {
    unawaited(ref.read(voiceInputControllerProvider.notifier).start());
    await _openChat();
  }

  Future<void> _openChat() => Navigator.of(context)
      .push<void>(MaterialPageRoute<void>(builder: (_) => const ChatScreen()));

  Future<void> _openMore() async {
    final id = await showZadMoreSheet(context);
    if (mounted && id != null) await _go(id);
  }

  Future<void> _resolve(ShellTab request) async {
    switch (request) {
      case ShellTab.home:
      case ShellTab.proposals:
        // Kotlin lists the bank's waiting proposals on الرئيسية, and a
        // proposal's notification brings the customer there.
        _show(ZadNavDestination.home);
      case ShellTab.assistant:
        _show(ZadNavDestination.assistant);
      case ShellTab.inventory:
      case ShellTab.household:
        _show(ZadNavDestination.inventory);
      case ShellTab.chat:
        await _openChat();
      case ShellTab.transactions:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const TransactionsScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // A destination asked for from outside — a tapped alert, a tile, "اسأل
    // زاد". Whatever was pushed over the shell is closed first, or the tab
    // would change behind it.
    ref.listen(shellNavigationProvider, (previous, next) async {
      if (next == null) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ref.read(shellNavigationProvider.notifier).shown();
      await _resolve(next);
    });

    // Kids mode replaces the whole shell: home and family, nothing else.
    if (ref.watch(kidsModeActiveProvider)) return const KidsShell();

    // Kotlin's BudgetGateScreen: no money screen before the ceiling is
    // confirmed — decided only once the server has said so.
    final unconfirmed = ref.watch(
      budgetControllerProvider.select(
        (v) => v.snapshot != null && !v.snapshot!.limitConfirmed,
      ),
    );
    // A ceiling saved here but still queued (offline) counts as confirmed:
    // the gate must not trap the customer until the outbox drains.
    final confirmedHere = ref.watch(
      settingsControllerProvider.select(
        (v) => v.settings?.limitConfirmedAt != null,
      ),
    );
    if (unconfirmed && !confirmedHere) return const BudgetGateScreen();

    final unread = ref.watch(
      notificationsControllerProvider.select((v) => v.unread > 0),
    );
    final name = ref.watch(profileControllerProvider.select((v) => v.name));
    final avatar = ref.watch(
      profileControllerProvider.select((v) => v.avatarUrl),
    );

    return DecoratedBox(
      // Kotlin paints the canvas once, behind the whole scaffold.
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        key: _scaffold,
        backgroundColor: Colors.transparent,
        drawer: ZadDrawer(
          current: _tab.name,
          entries: zadDrawerEntries,
          userName: name,
          avatarUrl: avatar,
          onNavigate: (id) {
            _scaffold.currentState?.closeDrawer();
            unawaited(_go(id));
          },
          onProfile: () {
            _scaffold.currentState?.closeDrawer();
            unawaited(showProfileScreen(context));
          },
        ),
        body: Column(
          children: <Widget>[
            ZadTopHeader(
              title: _title,
              hasUnreadNotifications: unread,
              avatarUrl: avatar,
              onOpenDrawer: () => _scaffold.currentState?.openDrawer(),
              onNotifications: () => unawaited(showNotificationCenter(context)),
              onAvatar: () => unawaited(showProfileScreen(context)),
            ),
            Expanded(
              // IndexedStack, not a rebuild per tab: each screen's controller
              // reads its cache in build, and swapping the subtree would throw
              // away a scrolled list and re-read Hive on every switch back.
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: IndexedStack(
                      index: _tabs.indexOf(_tab),
                      children: <Widget>[
                        HomeScreen(
                          onOpenVoice: () => unawaited(_openVoice()),
                          onOpenCamera: () => unawaited(_openCamera()),
                        ),
                        if (_assistantOpened)
                          const BrainFamilyScreen(embedded: true)
                        else
                          const SizedBox.shrink(),
                        if (_inventoryOpened)
                          const HouseholdScreen(embedded: true)
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                  // Kotlin shows the floating companion on الرئيسية only —
                  // elsewhere it covered the last icons of a row.
                  if (_tab == ZadNavDestination.home)
                    Positioned.fill(
                      child: FloatingCompanion(
                        onOpenVoice: () => unawaited(_openVoice()),
                        onOpenChat: () => unawaited(_openChat()),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: ZadBottomNavBar(
          current: _tab,
          onNavigate: _show,
          onOpenCamera: () => unawaited(_openCamera()),
          onOpenVoice: () => unawaited(_openVoice()),
          onOpenMore: () => unawaited(_openMore()),
        ),
      ),
    );
  }
}
