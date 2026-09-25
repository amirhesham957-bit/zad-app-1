/// Kotlin's shell in kids mode: two tabs only (home and family), the top bar
/// with the «وضع الأطفال» badge, and «الوضع الكامل» — the only way back to
/// the money screens, behind the PIN.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/features/family/presentation/family_screen.dart';
import 'package:zad/features/kids/application/kids_mode_controller.dart';
import 'package:zad/features/kids/presentation/kids_home.dart';
import 'package:zad/features/kids/presentation/pin_prompt_dialog.dart';

const Color _kidsPrimary = Color(0xFF6B46C1);

/// Asks for the PIN and, on success, leaves kids mode as Kotlin does.
Future<bool> unlockKidsMode(BuildContext context, WidgetRef ref) async {
  final ok = await showPinPrompt(context);
  if (ok) {
    ref
        .read(kidsModeProvider.notifier)
        .unlocked(isChild: ref.read(isChildRoleProvider));
  }
  return ok;
}

/// The kids shell.
class KidsShell extends ConsumerStatefulWidget {
  /// Creates the shell.
  const new({super.key});

  @override
  ConsumerState<KidsShell> createState() => _KidsShellState();
}

class _KidsShellState extends ConsumerState<KidsShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ZadColors.canvasMid,
    appBar: AppBar(
      backgroundColor: ZadColors.surface,
      automaticallyImplyLeading: false,
      titleSpacing: 20,
      title: Row(
        children: <Widget>[
          const Text(
            'زاد',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: ZadColors.green700,
            ),
          ),
          const SizedBox(width: 8),
          const _Pill(label: 'وضع الأطفال', fontSize: 11),
          const Spacer(),
          _Pill(
            label: 'الوضع الكامل',
            fontSize: 11.5,
            onTap: () => unawaited(unlockKidsMode(context, ref)),
          ),
        ],
      ),
    ),
    body: IndexedStack(
      index: _index,
      children: <Widget>[
        KidsHome(onOpenFamily: () => setState(() => _index = 1)),
        const FamilyScreen(showFinancials: false),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      backgroundColor: ZadColors.surface,
      indicatorColor: _kidsPrimary.withValues(alpha: 0.12),
      destinations: const <NavigationDestination>[
        NavigationDestination(icon: Icon(ZadIcons.home), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(ZadIcons.family), label: 'العائلة'),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const new({required this.label, required this.fontSize, this.onTap});

  final String label;
  final double fontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _kidsPrimary.withValues(alpha: 0.10),
    shape: const StadiumBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: onTap == null ? 0 : 44),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: onTap == null ? 9 : 12,
            vertical: onTap == null ? 3 : 6,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: _kidsPrimary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
