/// «فريق زاد»: what Zad's staff noticed on their morning round — the pantry
/// keeper, the nurse, the accountant, the family secretary and the setup
/// coach (zad-brain/staff.ts). Each walks one corner of the account every
/// morning without a model call and leaves a note in the brain's mailbox
/// (`zad_agent_messages`); the brain reads the same notes before it answers.
/// This page shows the last week of them. Reads only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';

/// Opens the page.
Future<void> showStaffScreen(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const StaffScreen()));

/// One note on the page.
typedef StaffNote = ({
  String role,
  IconData icon,
  String subject,
  String detail,
  DateTime at,
});

/// Who wrote it. The mailbox's senders are the staff's names; `brain` is the
/// setup coach on the morning round.
({String role, IconData icon}) staffMember(String sender) => switch (sender) {
  'pantry' => (role: 'أمين المخزن', icon: ZadIcons.shopping),
  'pharmacy' => (role: 'الممرضة', icon: ZadIcons.pharmacy),
  'finance' => (role: 'المحاسب', icon: ZadIcons.wallet),
  'family' => (role: 'سكرتير العيلة', icon: ZadIcons.family),
  'home' => (role: 'مسؤول البيت', icon: ZadIcons.home),
  _ => (role: 'مدرّب الإعداد', icon: ZadIcons.assistant),
};

/// The mailbox rows as notes, newest first. A tool's own receipt («نفّذ
/// add_…», written after every action) is not a note: it is in «سجل تعديلات
/// زاد» already.
List<StaffNote> staffFeed(Iterable<Map<String, dynamic>> rows) {
  final notes = <StaffNote>[];
  for (final r in rows) {
    final subject = ((r['subject'] as String?) ?? '').trim();
    final at = DateTime.tryParse((r['created_at'] as String?) ?? '');
    if (subject.isEmpty || at == null || subject.startsWith('نفّذ ')) continue;
    final who = staffMember((r['sender'] as String?) ?? '');
    notes.add((
      role: who.role,
      icon: who.icon,
      subject: subject,
      detail: ((r['detail'] as String?) ?? '').trim(),
      at: at,
    ));
  }
  return notes..sort((a, b) => b.at.compareTo(a.at));
}

/// The last week of notes.
final FutureProvider<List<StaffNote>> staffNotesProvider =
    FutureProvider.autoDispose<List<StaffNote>>((ref) async {
      final client = ref.watch(supabaseClientProvider);
      final uid = client.auth.currentUser?.id;
      if (uid == null) return const <StaffNote>[];
      final since = ref
          .read(nowProvider)()
          .toUtc()
          .subtract(const Duration(days: 7));
      final rows = await client
          .from('zad_agent_messages')
          .select('sender, subject, detail, created_at')
          .eq('user_id', uid)
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: false)
          .limit(60);
      return staffFeed(rows);
    });

/// The page.
class StaffScreen extends ConsumerWidget {
  /// Creates the page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(staffNotesProvider);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('فريق زاد')),
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(staffNotesProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(ZadSpacing.gutter),
            children: <Widget>[
              Text(
                'كل صبح الفريق بيلف على بيتك: المخزن، الصيدلية، الفلوس، '
                'العيلة، والإعدادات — ويبلّغ زاد باللي محتاج انتباه.',
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.lg),
              ...switch (notes) {
                AsyncData(:final value) when value.isEmpty => <Widget>[
                  const ZadEmptyState(
                    icon: ZadIcons.selected,
                    title: 'الفريق مالقاش حاجة تستاهل',
                    message: 'الجولة الجاية الصبح — لو لقوا حاجة هتلاقيها هنا.',
                  ),
                ],
                AsyncData(:final value) => <Widget>[
                  for (final n in value) ...<Widget>[
                    _NoteCard(note: n),
                    const SizedBox(height: ZadSpacing.md),
                  ],
                ],
                AsyncError() => <Widget>[
                  const ZadEmptyState(
                    icon: ZadIcons.search,
                    title: 'مقدرتش أجيب ملاحظات الفريق',
                    message: 'اسحب لتحت نجرب تاني.',
                    tone: ZadEmptyTone.problem,
                  ),
                ],
                _ => <Widget>[const Center(child: CircularProgressIndicator())],
              },
            ],
          ),
        ),
      ),
    );
  }
}

final DateFormat _day = DateFormat('d/M', 'ar');

class _NoteCard extends StatelessWidget {
  const new({required this.note});

  final StaffNote note;

  @override
  Widget build(BuildContext context) => ZadCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(note.icon, color: ZadColors.green700, size: 22),
        const SizedBox(width: ZadSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${note.role} · ${_day.format(note.at.toLocal())}',
                style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(note.subject, style: ZadType.titleSmall),
              if (note.detail.isNotEmpty) ...<Widget>[
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  note.detail,
                  style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
