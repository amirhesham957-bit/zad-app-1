/// Kotlin's `MainScreen` chrome: the header on top, the screen, the floating
/// pill at the bottom, the drawer behind the menu square — drawn once here
/// and never by a screen.
///
/// The bar has four places — زاد, فلوسي, بيتي, عيلتي (the owner's layout,
/// 2026-09-30, docs/agent/ZAD_BRAIN_PLAN.md) — with the mic orb and the
/// camera between them. عقل زاد and every other section open over the shell
/// from زاد's brief or the drawer.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/shell/zad_bottom_nav_bar.dart';
import 'package:zad/app/shell/zad_chrome.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/features/alerts/application/alerts_controller.dart';
import 'package:zad/features/brain_family/presentation/brain_family_screen.dart';
import 'package:zad/features/budget/presentation/budget_gate_screen.dart';
import 'package:zad/features/budget/presentation/finances_screen.dart';
import 'package:zad/features/chat/presentation/agent_screen_router.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/features/home/application/home_widget_controller.dart';
import 'package:zad/features/home/presentation/home_screen.dart';
import 'package:zad/features/home/presentation/sections_grid.dart';
import 'package:zad/features/household/presentation/household_screen.dart';
import 'package:zad/features/kids/presentation/kids_shell.dart';
import 'package:zad/features/nearby/presentation/nearby_deals_screen.dart';
import 'package:zad/features/notifications/presentation/notification_center_screen.dart';
import 'package:zad/features/orb/presentation/floating_companion.dart';
import 'package:zad/features/profile/presentation/profile_screen.dart';
import 'package:zad/features/scan/presentation/camera_screen.dart';
import 'package:zad/features/transactions/presentation/transactions_screen.dart';
import 'package:zad/features/voice/presentation/zad_voice_sheet.dart';
import 'package:zad/shared/alerts/application/local_reminders.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/notifications/application/notifications_controller.dart';
import 'package:zad/shared/profile/application/profile_controller.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';

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

  // فلوسي, بيتي and عيلتي fetch when they first build, so each is built on
  // its first visit and then kept — an IndexedStack builds every child up
  // front, and a launch should not spend a round of network on tabs nobody
  // opened.
  final Set<ZadNavDestination> _opened = <ZadNavDestination>{
    ZadNavDestination.home,
  };

  static const List<ZadNavDestination> _tabs = <ZadNavDestination>[
    ZadNavDestination.home,
    ZadNavDestination.money,
    ZadNavDestination.inventory,
    ZadNavDestination.family,
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
      if (mounted) await alerts.greetMorning();
    });
    // Back to the app in the morning is a first open too.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (mounted) {
          unawaited(ref.read(alertsControllerProvider.notifier).greetMorning());
        }
      },
    );
  }

  late final AppLifecycleListener _lifecycle;

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _show(ZadNavDestination tab) => setState(() {
    _tab = tab;
    _opened.add(tab);
  });

  String get _title => switch (_tab) {
    ZadNavDestination.money => 'فلوسي',
    ZadNavDestination.inventory => 'بيتي',
    ZadNavDestination.family => 'عيلتي',
    ZadNavDestination.home || ZadNavDestination.more => 'الرئيسية',
  };

  Future<void> _openBrain() => showBrainFamily(context);

  /// A route id from the drawer or a section tile.
  Future<void> _go(String id) async {
    switch (id) {
      case 'home':
        _show(ZadNavDestination.home);
      case 'budget':
        _show(ZadNavDestination.money);
      case 'inventory':
        _show(ZadNavDestination.inventory);
      case 'family':
        _show(ZadNavDestination.family);
      case 'assistant':
        await _openBrain();
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

  Future<void> _openCamera() => openZadCamera(context);

  static const MethodChannel _app = MethodChannel('zad/app');

  /// Back with nothing over the shell: another tab goes to الرئيسية, and
  /// الرئيسية hides the app. Letting Android finish the activity threw the
  /// Flutter engine away, so every return went through the splash again.
  void _back() {
    if (_tab != ZadNavDestination.home) {
      _show(ZadNavDestination.home);
      return;
    }
    unawaited(
      _app
          .invokeMethod<bool>('background')
          .then<void>((_) {}, onError: (Object _) => SystemNavigator.pop()),
    );
  }

  /// The mic orb: Kotlin's voice sheet — hold, speak, and زاد answers aloud.
  Future<void> _openVoice() => showZadVoiceSheet(context);

  Future<void> _openChat() => Navigator.of(context)
      .push<void>(MaterialPageRoute<void>(builder: (_) => const ChatScreen()));

  Future<void> _resolve(ShellTab request) async {
    switch (request) {
      case ShellTab.home:
      case ShellTab.proposals:
        // Kotlin lists the bank's waiting proposals on الرئيسية, and a
        // proposal's notification brings the customer there.
        _show(ZadNavDestination.home);
      case ShellTab.money:
        _show(ZadNavDestination.money);
      case ShellTab.assistant:
        await _openBrain();
      case ShellTab.inventory:
      case ShellTab.household:
        _show(ZadNavDestination.inventory);
      case ShellTab.chat:
        await _openChat();
      case ShellTab.transactions:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const TransactionsScreen()),
        );
      case ShellTab.family:
        // A child's shell already shows the family's latest messages on its
        // home; the adults' family screen is not theirs to open.
        if (ref.read(kidsModeActiveProvider)) return;
        _show(ZadNavDestination.family);
    }
  }

  @override
  Widget build(BuildContext context) {
    // «وريني مواعيدي»: the agent's app_command, from whichever surface sent
    // the turn — the chat, the mic sheet, the brain card. Heard here, not in
    // ChatScreen, so a spoken request opens its screen without the chat being
    // open; pushed over whatever is showing, so back returns to it.
    ref.listen(agentCommandProvider, (previous, next) {
      if (next == null || next.serial == previous?.serial) return;
      openAgentScreen(context, ref, next.command);
    });

    // A destination asked for from outside — a tapped alert, a tile, "اسأل
    // زاد". Whatever was pushed over the shell is closed first, or the tab
    // would change behind it.
    ref.listen(shellNavigationProvider, (previous, next) async {
      if (next == null) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ref.read(shellNavigationProvider.notifier).shown();
      await _resolve(next);
    });

    // The home-screen widget follows the balance and the newest rows.
    ref.watch(homeWidgetSyncProvider);

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: DecoratedBox(
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
                onNotifications: () =>
                    unawaited(showNotificationCenter(context)),
                onAvatar: () => unawaited(showProfileScreen(context)),
              ),
              Expanded(
                // IndexedStack, not a rebuild per tab: each screen's
                // controller reads its cache in build, and swapping the
                // subtree would throw away a scrolled list and re-read Hive
                // on every switch back.
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
                          if (_opened.contains(ZadNavDestination.money))
                            const FinancesScreen(embedded: true)
                          else
                            const SizedBox.shrink(),
                          if (_opened.contains(ZadNavDestination.inventory))
                            const HouseholdScreen(embedded: true)
                          else
                            const SizedBox.shrink(),
                          if (_opened.contains(ZadNavDestination.family))
                            ZadSlots.familyScreen()
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
            onOpenMore: () => _scaffold.currentState?.openDrawer(),
          ),
        ),
      ),
    );
  }
}
