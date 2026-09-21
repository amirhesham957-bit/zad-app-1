/// عقل زاد: the four windows onto what the assistant knows and does.
///
/// Kotlin puts the same four behind icons over its intelligence tab. Here they
/// hang off the chat, since that is where the customer talks to the thing they
/// describe.
library;

import 'package:flutter/material.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/brain/presentation/agent_action_log_screen.dart';
import 'package:zad/features/brain/presentation/brain_health_screen.dart';
import 'package:zad/features/brain/presentation/knowledge_map_screen.dart';
import 'package:zad/features/brain/presentation/memory_screen.dart';

/// Opens the hub.
Future<void> showBrainHub(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const BrainHubScreen()));

/// The hub.
class BrainHubScreen extends StatelessWidget {
  /// Creates the hub.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    const entries = <_Entry>[
      _Entry(
        icon: ZadIcons.memory,
        title: 'زاد عارف عني إيه',
        subtitle: 'اللي زاد فاكره عنك وبيكلمك على أساسه — صحّحه أو خلّيه ينساه',
        open: showMemoryScreen,
      ),
      _Entry(
        icon: ZadIcons.knowledgeMap,
        title: 'خريطة زاد',
        subtitle: 'إزاي ميزانيتك واشتراكاتك وبيتك متصلين ببعض',
        open: showKnowledgeMap,
      ),
      _Entry(
        icon: ZadIcons.actionLog,
        title: 'سجل تعديلات زاد',
        subtitle: 'كل حاجة زاد سجّلها أو عدّلها لك، وترجع فيها لو غلط',
        open: showAgentActionLog,
      ),
      _Entry(
        icon: ZadIcons.brainHealth,
        title: 'صحة عقل زاد',
        subtitle: 'زاد شغال في الخلفية ولا واقف — ولو واقف، ليه',
        open: showBrainHealth,
      ),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('عقل زاد')),
        body: ListView.separated(
          padding: const EdgeInsets.all(ZadSpacing.gutter),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: ZadSpacing.md),
          itemBuilder: (context, i) => _EntryCard(entry: entries[i]),
        ),
      ),
    );
  }
}

class _Entry {
  const new({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.open,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function(BuildContext) open;
}

class _EntryCard extends StatelessWidget {
  const new({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) => ZadCard(
    onTap: () => entry.open(context),
    child: Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: ZadColors.green600.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(ZadSpacing.md),
            child: Icon(entry.icon, color: ZadColors.green700, size: 22),
          ),
        ),
        const SizedBox(width: ZadSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(entry.title, style: ZadType.titleSmall),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                entry.subtitle,
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        const Icon(ZadIcons.forward, size: 18, color: ZadColors.inkMuted),
      ],
    ),
  );
}
