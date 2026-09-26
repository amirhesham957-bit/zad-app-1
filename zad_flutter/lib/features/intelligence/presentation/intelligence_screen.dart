/// Kotlin's `ZadIntelligenceScreen` («عقل زاد الذكي»), as it actually renders:
/// the SOS banner, the orb hero with four quick prompts, then either the
/// "log three expenses first" card or the three analysis cards — the AI
/// monthly report (on a tap, never on open), the financial stress test with
/// its emergency-fund editor, and the category distribution — each with its
/// «اشرح بالذكاء الاصطناعي» — and the chat card.
///
/// Kotlin embeds its chat here; in Flutter the chat is its own tab, so the
/// prompts and the chat card send to it and open it. The ad gate and ad
/// battery are Kotlin's AdMob path, not in this sideloaded build, and the
/// PDF export needs Kotlin's local brain report, which Flutter does not
/// compute — the AI report is shared as text instead, as Kotlin also does.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:share_plus/share_plus.dart';
import 'package:zad/app/shell_navigation.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/application/family_life_controller.dart';
import 'package:zad/features/family/domain/family_life.dart';
import 'package:zad/features/family/presentation/family_screen.dart';
import 'package:zad/features/orb/application/companion_mood.dart';
import 'package:zad/features/orb/presentation/companion_orb.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// Opens the screen.
Future<void> showIntelligenceScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const IntelligenceScreen()),
    );

const List<String> _quickPrompts = <String>[
  'حلل مصاريفي 📊',
  'توقع مصاريف الشهر القادم 🔮',
  'اقترح وجبة للغداء 🍲',
  'هل وضعي المالي آمن؟ 💰',
];

const List<Color> _palette = <Color>[
  Color(0xFF0B6B4E),
  Color(0xFFC68216),
  Color(0xFF2B6CB0),
  Color(0xFFD95726),
  Color(0xFF6D28D9),
];

bool _isExpense(ZadTransaction t) => t.kind == TxnKind.expense;

/// `ai_text` on zad-core-intelligence — Kotlin's `callGeminiText`.
Future<String?> _aiText(WidgetRef ref, String system, String user) async {
  try {
    final client = ref.read(supabaseClientProvider);
    final response = await client.functions.invoke(
      'zad-core-intelligence',
      body: <String, dynamic>{
        'action': 'ai_text',
        'user_id': client.auth.currentUser?.id,
        'payload': <String, dynamic>{
          'system_prompt': system,
          'user_prompt': user,
          'response_mime_type': 'text/plain',
        },
      },
    );
    final data = response.data;
    final text = data is Map ? data['text'] : null;
    return text is String && text.trim().isNotEmpty ? text.trim() : null;
  } on Object catch (e) {
    debugPrint('ai_text failed: $e');
    return null;
  }
}

/// The screen.
class IntelligenceScreen extends ConsumerWidget {
  /// Creates the screen; [embedded] drops the app bar inside BrainFamily.
  const new({this.embedded = false, super.key});

  /// Whether a host screen already shows the title.
  final bool embedded;

  void _ask(BuildContext context, WidgetRef ref, [String? prompt]) {
    if (prompt != null) {
      unawaited(ref.read(chatControllerProvider.notifier).send(prompt));
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
    ref.read(shellNavigationProvider.notifier).open(ShellTab.chat);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(transactionsRepositoryProvider).allCached();
    final budget = ref.watch(budgetControllerProvider).snapshot;
    final expenses = all.where(_isExpense).toList();
    final start = budget?.cycleStart;
    final end = budget?.cycleEnd;
    bool inCycle(ZadTransaction t) =>
        start == null ||
        (!t.createdAt.isBefore(start) &&
            (end == null || t.createdAt.isBefore(end)));
    final categories = <String, double>{};
    for (final t in expenses.where(inCycle)) {
      final c = (t.category ?? '').trim().isEmpty ? 'أخرى' : t.category!;
      categories[c] = (categories[c] ?? 0) + t.amount;
    }
    final categoryList = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final enough = expenses.length >= 3;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: embedded ? null : AppBar(title: const Text('عقل زاد')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.lg,
            ZadSpacing.sm,
            ZadSpacing.lg,
            120,
          ),
          children:
              <Widget>[
                    const _SosBanner(),
                    _Hero(
                      onOrb: () => _ask(context, ref),
                      onPrompt: (p) => _ask(context, ref, p),
                    ),
                    if (!enough)
                      _NotEnough(
                        count: expenses.length,
                        onTalk: () => _ask(context, ref),
                      )
                    else ...<Widget>[
                      _ReportCard(
                        transactions: all,
                        budget: budget?.openingBalance ?? 0,
                        income: budget?.income ?? 0,
                        expense: budget?.spent ?? 0,
                        categories: categoryList.take(5).toList(),
                        cycleStart: start,
                      ),
                      _StressTestCard(
                        expenses: expenses,
                        available: budget?.spendable ?? 0,
                      ),
                      _DistributionCard(
                        total: budget?.spent ?? 0,
                        categories: categoryList,
                      ),
                    ],
                    _ChatCard(onOpen: () => _ask(context, ref)),
                  ]
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
                      child: w,
                    ),
                  )
                  .toList()
                  .animate(interval: 40.ms)
                  .fadeIn(duration: ZadDuration.enter)
                  .moveY(begin: 10, curve: ZadCurves.standard),
        ),
      ),
    );
  }
}

// ── SOS ─────────────────────────────────────────────────────────────────────

class _SosBanner extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyControllerProvider).family;
    if (family == null) return const SizedBox.shrink();
    final messages = ref.watch(familyLifeControllerProvider).messages;
    final sos = messages.lastWhere(
      (m) => m.type == FamilyMessageType.sos,
      orElse: () => messages.isEmpty ? _none : messages.first,
    );
    final at = sos.createdAt;
    if (sos.type != FamilyMessageType.sos ||
        at == null ||
        DateTime.now().difference(at) > const Duration(hours: 2)) {
      return const SizedBox.shrink();
    }
    final alias = family.members
        .where((m) => m.id == sos.senderId)
        .firstOrNull
        ?.alias;
    if (alias == null) return const SizedBox.shrink();
    return Material(
      color: ZadColors.terracottaRust.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(showFamilyScreen(context)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Icon(ZadIcons.sos, color: ZadColors.terracottaRust),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'نداء طوارئ من $alias!',
                  style: ZadType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ZadColors.terracottaRust,
                  ),
                ),
              ),
              Icon(ZadIcons.back, size: 18, color: ZadColors.terracottaRust),
            ],
          ),
        ),
      ),
    );
  }
}

final FamilyMessage _none = FamilyMessage.fromJson(const <String, dynamic>{
  'id': '',
  'sender_id': '',
  'message': '',
  'message_type': 'TEXT',
});

// ── Hero ────────────────────────────────────────────────────────────────────

class _Hero extends ConsumerWidget {
  const new({required this.onOrb, required this.onPrompt});

  final VoidCallback onOrb;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typing = ref.watch(
      chatControllerProvider.select((v) => v.isAwaitingReply),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            ZadColors.mint100,
            ZadColors.mint100.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            // Kotlin: the living orb, 96dp, on the one shared mood; a tap
            // squeezes, blinks and glows, then opens the chat.
            CompanionOrb(state: ref.watch(companionMoodProvider), onTap: onOrb),
            const SizedBox(height: 14),
            Text(
              'عقل زاد الذكي',
              style: ZadType.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: ZadColors.green800,
              ),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              typing
                  ? 'زاد يحلل بياناتك الآن 🧠✨'
                  : 'متصل ومستعد لمساعدتك في إدارتك المالية والمنزلية ⚡',
              textAlign: TextAlign.center,
              style: ZadType.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: ZadColors.green800.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: ZadSpacing.sm),
                itemBuilder: (context, i) => ActionChip(
                  onPressed: () => onPrompt(_quickPrompts[i]),
                  backgroundColor: ZadColors.green800.withValues(alpha: 0.12),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  label: Text(
                    _quickPrompts[i],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ZadColors.green800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared pieces ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZadColors.surface,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: ZadColors.shadowSpot,
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
        BoxShadow(color: ZadColors.shadowAmbient, blurRadius: 2),
      ],
    ),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

class _Header extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ZadColors.green700.withValues(alpha: 0.12),
        ),
        child: Icon(icon, size: 22, color: ZadColors.green700),
      ),
      const SizedBox(width: ZadSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              subtitle,
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

/// Kotlin's `AiNarrativeSection`: «اشرح بالذكاء الاصطناعي», then the answer.
class _Narrative extends ConsumerStatefulWidget {
  const new({required this.system, required this.user});

  final String system;
  final String Function() user;

  @override
  ConsumerState<_Narrative> createState() => _NarrativeState();
}

class _NarrativeState extends ConsumerState<_Narrative> {
  String? _text;
  bool _loading = false;

  Future<void> _explain() async {
    setState(() => _loading = true);
    final text = await _aiText(ref, widget.system, widget.user());
    if (!mounted) return;
    setState(() {
      _text = text;
      _loading = false;
    });
    if (text == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('زاد مقدرش يرد دلوقتي — جرّب تاني.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Row(
        children: <Widget>[
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: ZadSpacing.sm),
          Text(
            'زاد يقوم بالتحليل...',
            style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
          ),
        ],
      );
    }
    final text = _text;
    if (text != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: ZadColors.mint50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                ZadIcons.assistant,
                size: 16,
                color: ZadColors.green700,
              ),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(child: Text(text, style: ZadType.bodySmall)),
            ],
          ),
        ),
      ).animate().fadeIn(duration: ZadDuration.enter);
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: () => unawaited(_explain()),
        icon: const Icon(ZadIcons.assistant, size: 14),
        label: const Text(
          'اشرح بالذكاء الاصطناعي',
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

String _money(WidgetRef ref, double v) {
  final currency = ref.watch(
    budgetControllerProvider.select((s) => s.snapshot?.currency ?? ''),
  );
  return '${NumberFormat('#,##0.##', 'en').format(v)} $currency'.trim();
}

// ── Not enough data ─────────────────────────────────────────────────────────

class _NotEnough extends StatelessWidget {
  const new({required this.count, required this.onTalk});

  final int count;
  final VoidCallback onTalk;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      children: <Widget>[
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ZadColors.green700.withValues(alpha: 0.12),
          ),
          child: const Icon(
            ZadIcons.assistant,
            size: 30,
            color: ZadColors.green700,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'سجل أول 3 مصاريف لتفعيل عقل زاد التحليلي',
          textAlign: TextAlign.center,
          style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'يحتاج عقل زاد إلى 3 مصاريف على الأقل لتحليل سلوكك المالي بدقة '
          'وتوليد تقارير الصمود المالي.',
          textAlign: TextAlign.center,
          style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            color: ZadColors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'تم تسجيل $count من 3 مصاريف',
                        style: ZadType.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${(count * 100 ~/ 3).clamp(0, 100)}%',
                      style: ZadType.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ZadColors.green700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZadSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (count / 3).clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: ZadColors.green700.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onTalk,
            icon: const Icon(ZadIcons.ask, size: 18),
            label: const Text('تحدث مع زاد الآن 💬'),
          ),
        ),
      ],
    ),
  );
}

// ── AI report ───────────────────────────────────────────────────────────────

typedef _Report = ({
  String summary,
  List<String> insights,
  List<String> recommendations,
  String health,
});

class _ReportCard extends ConsumerStatefulWidget {
  const new({
    required this.transactions,
    required this.budget,
    required this.income,
    required this.expense,
    required this.categories,
    required this.cycleStart,
  });

  final List<ZadTransaction> transactions;
  final double budget;
  final double income;
  final double expense;
  final List<MapEntry<String, double>> categories;
  final DateTime? cycleStart;

  @override
  ConsumerState<_ReportCard> createState() => _ReportState();
}

class _ReportState extends ConsumerState<_ReportCard> {
  _Report? _report;
  bool _loading = false;
  bool _failed = false;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final tx = widget.transactions;
    final recent = tx.length > 60 ? tx.sublist(tx.length - 60) : tx;
    final cycle = widget.cycleStart == null
        ? ''
        : DateFormat('MMMM yyyy', 'ar').format(widget.cycleStart!);
    try {
      final client = ref.read(supabaseClientProvider);
      final response = await client.functions.invoke(
        'zad-core-intelligence',
        body: <String, dynamic>{
          'action': 'monthly_expense_report',
          'user_id': client.auth.currentUser?.id,
          'payload': <String, dynamic>{
            'cycle': cycle,
            'budget': widget.budget,
            'total_income': widget.income,
            'total_expense': widget.expense,
            'top_categories': widget.categories
                .map((e) => '${e.key}=${e.value}')
                .join(', '),
            'transaction_count': tx.length,
            'transactions': recent
                .map((t) => '${t.title}:${t.amount}:${t.category ?? 'أخرى'}')
                .join(', '),
          },
        },
      );
      final d = response.data;
      if (d is! Map) {
        throw StateError('monthly_expense_report: ${d.runtimeType}');
      }
      List<String> strings(Object? v) => <String>[
        if (v is List)
          for (final s in v)
            if (s is String) s,
      ];
      if (!mounted) return;
      setState(() {
        _report = (
          summary: (d['summary'] as String?) ?? '',
          insights: strings(d['insights']),
          recommendations: strings(d['recommendations']),
          health: (d['health_label'] as String?) ?? '',
        );
        _loading = false;
      });
    } on Object catch (e) {
      debugPrint('monthly_expense_report failed: $e');
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  void _share(_Report r) {
    final b = StringBuffer(r.summary);
    if (r.insights.isNotEmpty) {
      b.write('\n\n');
      for (final i in r.insights) {
        b.writeln('• $i');
      }
    }
    if (r.recommendations.isNotEmpty) {
      b.writeln();
      for (final i in r.recommendations) {
        b.writeln('✓ $i');
      }
    }
    unawaited(
      SharePlus.instance.share(
        ShareParams(text: b.toString(), subject: 'تقرير زاد المالي'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Header(
            icon: ZadIcons.assistant,
            title: 'توليد تقرير الذكاء الاصطناعي الشامل',
            subtitle:
                'تحليل فوري دقيق لجميع حركاتك ومصروفاتك عبر نماذج الذكاء '
                'الاصطناعي',
            trailing: report == null
                ? null
                : IconButton(
                    tooltip: 'مشاركة تقرير زاد',
                    onPressed: () => _share(report),
                    icon: const Icon(ZadIcons.share, color: ZadColors.green700),
                  ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            DecoratedBox(
              decoration: BoxDecoration(
                color: ZadColors.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(ZadSpacing.lg),
                child: Row(
                  children: <Widget>[
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: ZadSpacing.md),
                    Expanded(
                      child: Text(
                        'جاري تحليل الحركات وتوليد التقرير بالذكاء '
                        'الاصطناعي...',
                        style: ZadType.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: ZadColors.green700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_failed) ...<Widget>[
            Text(
              'تعذر حفظ التغييرات — تحقق من الاتصال وحاول مرة أخرى',
              style: ZadType.bodySmall.copyWith(
                color: ZadColors.terracottaRust,
              ),
            ),
            const SizedBox(height: ZadSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => unawaited(_generate()),
                child: const Text('إعادة المحاولة'),
              ),
            ),
          ] else if (report == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => unawaited(_generate()),
                icon: const Icon(ZadIcons.assistant, size: 18),
                label: const Text('توليد تقرير الذكاء الاصطناعي الشامل'),
              ),
            )
          else ...<Widget>[
            if (report.health.isNotEmpty) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ZadColors.green700.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  report.health,
                  style: ZadType.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ZadColors.green700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (report.summary.isNotEmpty)
              Text(report.summary, style: ZadType.bodyMedium),
            if (report.insights.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              for (final i in report.insights)
                _Bullet(mark: '• ', color: ZadColors.green700, text: i),
            ],
            if (report.recommendations.isNotEmpty) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              Text(
                'نصايح زاد',
                style: ZadType.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: ZadSpacing.xs),
              for (final r in report.recommendations)
                _Bullet(mark: '✓ ', color: ZadColors.green600, text: r),
            ],
            const SizedBox(height: ZadSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => unawaited(_generate()),
                icon: const Icon(ZadIcons.retry, size: 16),
                label: const Text('تحديث التقرير 🔄'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const new({required this.mark, required this.color, required this.text});

  final String mark;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          mark,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        Expanded(
          child: Text(
            text,
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
        ),
      ],
    ),
  );
}

// ── Stress test ─────────────────────────────────────────────────────────────

class _StressTestCard extends ConsumerStatefulWidget {
  const new({required this.expenses, required this.available});

  final List<ZadTransaction> expenses;
  final double available;

  @override
  ConsumerState<_StressTestCard> createState() => _StressState();
}

class _StressState extends ConsumerState<_StressTestCard> {
  double _fund = 0;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_loadFund));
  }

  Future<void> _loadFund() async {
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await client
          .from('zad_users')
          .select('emergency_fund_balance')
          .eq('id', uid)
          .maybeSingle();
      final v = (row?['emergency_fund_balance'] as num?)?.toDouble() ?? 0;
      if (mounted) setState(() => _fund = v);
    } on Object catch (e) {
      debugPrint('emergency fund read failed: $e');
    }
  }

  Future<void> _editFund() async {
    final c = TextEditingController(text: _fund > 0 ? '$_fund' : '');
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'تحديث الرصيد',
          style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'رصيد صندوق الطوارئ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext)
                    .pop(double.tryParse(c.text.trim()) ?? 0),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    c.dispose();
    if (value == null) return;
    setState(() => _fund = value);
    final client = ref.read(supabaseClientProvider);
    try {
      await client
          .from('zad_users')
          .update(<String, dynamic>{'emergency_fund_balance': value})
          .eq('id', client.auth.currentUser?.id ?? '');
    } on Object catch (e) {
      debugPrint('emergency fund write failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kotlin's calculateStressTest: 30-day window, measured over the days
    // actually observed, 90-day target, the gap closed over six months.
    const targetDays = 90;
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(const Duration(days: 30));
    final recent = widget.expenses
        .where((t) => !t.createdAt.isBefore(cutoff))
        .toList();
    final total = recent.fold<double>(0, (s, t) => s + t.amount);
    DateTime? oldest;
    for (final t in recent) {
      if (oldest == null || t.createdAt.isBefore(oldest)) oldest = t.createdAt;
    }
    final observed = oldest == null
        ? 30
        : (now.difference(oldest).inDays + 1).clamp(1, 30);
    final daily = total > 0 ? total / observed : 0.0;

    final usingAvailable = _fund <= 0 && widget.available > 0;
    final savings = _fund > 0 ? _fund : widget.available;
    final allTotal = widget.expenses.fold<double>(0, (s, t) => s + t.amount);
    final safeDaily = daily > 0
        ? daily
        : allTotal > 0
        ? (allTotal / 30).clamp(1, double.infinity).toDouble()
        : 1.0;
    final coverage = (savings / safeDaily).floor().clamp(0, 1 << 30);
    final gap = (targetDays - coverage).clamp(0, targetDays);
    final suggested = daily > 0 && gap > 0 ? gap * daily / 6 : 0.0;
    final (color, label, status) = coverage < 30
        ? (ZadColors.terracottaRust, 'حرج', 'CRITICAL')
        : coverage < targetDays
        ? (const Color(0xFFD97706), 'منخفض', 'LOW')
        : (ZadColors.green600, 'صحي', 'HEALTHY');

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.security, size: 22),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  'اختبار الصمود المالي',
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => unawaited(_editFund()),
                child: const Text(
                  'تحديث الرصيد',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            'كم يوماً تستطيع الصمود لو توقف دخلك؟',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.lg),
          Text(
            '$coverage يوم تغطية',
            style: ZadType.headlineMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            'الهدف: $targetDays يوم',
            style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: (coverage / targetDays).clamp(0, 1)),
              duration: ZadDuration.settle,
              curve: ZadCurves.standard,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      usingAvailable
                          ? 'رصيدك المتاح حالياً (لسه محددتش صندوق طوارئ)'
                          : 'رصيد صندوق الطوارئ',
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                    Text(
                      _money(ref, savings),
                      style: ZadType.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: ZadType.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'متوسط الصرف اليومي',
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
              ),
              Text(
                _money(ref, safeDaily),
                style: ZadType.labelSmall.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (suggested > 0) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'وفّر ${_money(ref, suggested)} شهرياً للوصول للهدف',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
          const SizedBox(height: ZadSpacing.md),
          _Narrative(
            system:
                'أنت محلل مالي شخصي داخل تطبيق زاد. لخص وضع صمود المستخدم '
                'المالي في جملة أو جملتين بالعربي، بدون اختراع أرقام غير '
                "الموجودة في البيانات. لو أيام التغطية 'غير محسوبة'، قول إنها "
                'لسه محتاجة مصروفات مسجلة أكتر — وممنوع تعتبرها صفر أو تقول '
                'إن المستخدم مكشوف.',
            user: () =>
                '=== بيانات اختبار الصمود المالي ===\n'
                'أيام التغطية عند الطوارئ: $coverage\n'
                'متوسط الصرف اليومي: $safeDaily\n'
                'رصيد الطوارئ الحالي: $savings\n'
                'الهدف: $targetDays يوم تغطية\n'
                'التوفير الشهري المقترح للوصول للهدف: $suggested\n'
                'الحالة: $status\n'
                '=== نهاية البيانات ===',
          ),
        ],
      ),
    );
  }
}

// ── Distribution ────────────────────────────────────────────────────────────

class _DistributionCard extends ConsumerWidget {
  const new({required this.total, required this.categories});

  final double total;
  final List<MapEntry<String, double>> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sum = categories.fold<double>(0, (s, e) => s + e.value);
    final safeTotal = total > 0 ? total : (sum < 1 ? 1 : sum);
    final maxAmount = categories.isEmpty || categories.first.value <= 0
        ? 1.0
        : categories.first.value;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Header(
            icon: Icons.pie_chart,
            title: 'توزيع المصروفات والملاحظات السلوكية',
            subtitle: 'تحليل نسب الصرف على الفئات والملاحظات السلوكية الذكية',
            trailing: Text(
              _money(ref, total),
              style: ZadType.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: ZadColors.green700,
              ),
            ),
          ),
          if (categories.isNotEmpty) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: ZadColors.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '💡 أعلى استهلاك في فئة [${categories.first.key}] بنسبة '
                  '${(categories.first.value / safeTotal * 100).toInt()}% من '
                  'إجمالي مصروفاتك',
                  style: ZadType.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          for (final (i, e) in categories.take(5).indexed) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    e.key,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${(e.value / safeTotal * 100).toInt()}% • '
                  '${_money(ref, e.value)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ZadColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: (e.value / maxAmount).clamp(0, 1)),
                duration: ZadDuration.settle,
                curve: ZadCurves.standard,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  color: _palette[i % _palette.length],
                  backgroundColor: ZadColors.ink.withValues(alpha: 0.08),
                ),
              ),
            ),
          ],
          const SizedBox(height: ZadSpacing.md),
          _Narrative(
            system:
                'أنت خبير تحليل سلوك مالي داخل تطبيق زاد. حلل توزيع المصروفات '
                'أدناه وقدم ملاحظة سلوكية ذكية وودودة في جملة أو جملتين '
                'بالعربي، مع توجيه واقعي لتحسين الصرف.',
            user: () =>
                '=== بيانات توزيع المصروفات ===\n'
                'إجمالي المصروفات: $total\n'
                'توزيع الفئات:\n'
                '${_summary(categories)}\n'
                '=== نهاية البيانات ===',
          ),
        ],
      ),
    );
  }
}

String _summary(List<MapEntry<String, double>> c) =>
    c.take(5).map((e) => '${e.key}: ${e.value}').join(', ');

// ── Chat ────────────────────────────────────────────────────────────────────

class _ChatCard extends StatelessWidget {
  const new({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: ZadColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ZadColors.green700,
              ),
              child: const Icon(ZadIcons.ask, color: Colors.white, size: 22),
            ),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'اتكلم مع زاد',
                    style: ZadType.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'اسأله عن مصاريفك، ميزانيتك، أو بيتك — بالكتابة أو بصوتك',
                    style: ZadType.bodySmall.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(ZadIcons.back, color: ZadColors.inkMuted),
          ],
        ),
      ),
    ),
  );
}
