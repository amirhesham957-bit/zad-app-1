/// «تشخيص الأتمتة» — where the bank reading and the proactive messages stop.
///
/// The phone half is the existing [BankReadingStatusSection]; this adds what
/// the phone could not see: what reached the server and why it was set
/// aside, and every message Zad tried to start and why it did not arrive.
/// Each chain ends in one line naming the first broken link
/// (`automation_diagnosis.dart`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_appear.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/profile/data/automation_diagnostics_remote.dart';
import 'package:zad/features/profile/domain/automation_diagnosis.dart';
import 'package:zad/features/profile/presentation/profile_sub_screens.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';

/// Opens «تشخيص الأتمتة».
Future<void> showAutomationDiagnosticsScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AutomationDiagnosticsScreen(),
      ),
    );

/// The screen.
class AutomationDiagnosticsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<AutomationDiagnosticsScreen> createState() => _State();
}

class _State extends ConsumerState<AutomationDiagnosticsScreen> {
  ServerAutomation? _server;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = ref.read(nowProvider)();
    final server = await ref
        .read(automationDiagnosticsRemoteProvider)
        .read(now);
    if (!mounted) return;
    setState(() {
      _server = server;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final server = _server;
    return Scaffold(
      appBar: SubScreenTopBar(title: l10n.diagTitle),
      body: ZadAppearOnEntry(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(ZadSpacing.lg),
            children: <Widget>[
              const BankReadingStatusSection(),
              const SizedBox(height: ZadSpacing.xl),
              if (server == null)
                const Center(child: CircularProgressIndicator())
              else ...<Widget>[
                _BankServerSection(server: server),
                const SizedBox(height: ZadSpacing.xl),
                _ProactiveSection(server: server),
              ],
              const SizedBox(height: ZadSpacing.lg),
              FilledButton.icon(
                onPressed: _loading ? null : () => unawaited(_load()),
                icon: const Icon(ZadIcons.retry),
                label: Text(l10n.diagRefresh),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _when(DateTime at) => DateFormat('d/M HH:mm').format(at);

class _Verdict extends StatelessWidget {
  const new({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(ZadSpacing.md),
      decoration: BoxDecoration(
        color: ok ? scheme.primaryContainer : scheme.errorContainer,
        borderRadius: BorderRadius.circular(ZadSpacing.md),
      ),
      child: Text(
        text,
        style: ZadType.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: ok ? scheme.onPrimaryContainer : scheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.title, required this.note});

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: ZadType.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: ZadSpacing.xs),
        Text(
          note,
          style: ZadType.bodySmall.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: ZadSpacing.md),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const new({required this.lead, required this.text, this.when});

  final String lead;
  final String text;
  final DateTime? when;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  lead,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZadType.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  text,
                  style: ZadType.bodySmall.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (when case final at?) ...<Widget>[
            const SizedBox(width: ZadSpacing.sm),
            Text(
              _when(at),
              style: ZadType.labelSmall.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadFailed extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ZadEmptyState(
    icon: ZadIcons.failed,
    title: context.l10n.diagReadFailedTitle,
    message: context.l10n.diagReadFailedBody,
  );
}

class _BankServerSection extends ConsumerWidget {
  const new({required this.server});

  final ServerAutomation server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(bankAccessControllerProvider);
    final rows = server.ingest;
    final verdict = rows == null
        ? null
        : bankBreak(
            PhoneBank(
              granted: s.granted,
              connected: s.lastConnectedAt != null,
              lastSeenAnyAt: s.lastSeenAnyAt,
              pending: s.pending,
            ),
            rows,
            ref.read(nowProvider)(),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(title: l10n.diagBankTitle, note: l10n.diagBankNote),
        if (verdict != null) ...<Widget>[
          _Verdict(
            ok: verdict == BankBreak.none,
            text: _bankText(l10n, verdict),
          ),
          const SizedBox(height: ZadSpacing.md),
        ],
        if (rows == null)
          const _ReadFailed()
        else if (rows.isEmpty)
          ZadEmptyState(
            icon: ZadIcons.bank,
            title: l10n.diagBankEmptyTitle,
            message: l10n.diagBankEmptyBody,
          )
        else
          for (final r in rows)
            _Line(
              lead: (r.title ?? '').trim().isEmpty
                  ? l10n.diagNotification
                  : r.title!.trim(),
              text: _ingestText(l10n, r),
              when: r.at,
            ),
      ],
    );
  }
}

String _bankText(ZadL10n l10n, BankBreak b) => switch (b) {
  BankBreak.noAccess => l10n.diagBankNoAccess,
  BankBreak.serviceNotBound => l10n.diagBankNotBound,
  BankBreak.serviceSilent => l10n.diagBankSilent,
  BankBreak.stuckOnPhone => l10n.diagBankStuck,
  BankBreak.nothingReachedServer => l10n.diagBankNothing,
  BankBreak.allSetAside => l10n.diagBankSetAside,
  BankBreak.waitingForYou => l10n.diagBankWaiting,
  BankBreak.none => l10n.diagBankOk,
};

String _ingestText(ZadL10n l10n, IngestRow r) => switch (ingestReason(r)) {
  IngestReason.recorded => l10n.diagIngestRecorded,
  IngestReason.waiting => l10n.diagIngestWaiting,
  IngestReason.promo => l10n.diagIngestPromo,
  IngestReason.otp => l10n.diagIngestOtp,
  IngestReason.order => l10n.diagIngestOrder,
  IngestReason.personal => l10n.diagIngestPersonal,
  IngestReason.nonFinancial => l10n.diagIngestNonFinancial,
  IngestReason.unavailable => l10n.diagIngestUnavailable,
  IngestReason.otherKind => l10n.diagIngestKind(ingestKind(r)),
  IngestReason.informational => l10n.diagIngestInfo,
  IngestReason.failedTransaction => l10n.diagIngestFailedTxn,
  IngestReason.merged => l10n.diagIngestMerged,
  IngestReason.serverError => l10n.diagIngestServerError,
  IngestReason.reviewing => l10n.diagIngestReviewing,
  IngestReason.unknown => r.status,
};

class _ProactiveSection extends StatelessWidget {
  const new({required this.server});

  final ServerAutomation server;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final moments = server.moments;
    final telegram = server.telegramLinked;
    final tokens = server.pushTokens;
    final verdict = moments == null
        ? null
        : proactiveBreak(
            telegramLinked: telegram ?? false,
            hasPushToken: (tokens ?? 0) > 0,
            moments: moments,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(title: l10n.diagProTitle, note: l10n.diagProNote),
        _Line(
          lead: l10n.diagTelegram,
          text: switch (telegram) {
            null => l10n.diagUnknown,
            true => l10n.diagLinked,
            false => l10n.diagNotLinked,
          },
        ),
        _Line(
          lead: l10n.diagPush,
          text: switch (tokens) {
            null => l10n.diagUnknown,
            final n when n > 0 => l10n.diagPushOn(n),
            _ => l10n.diagPushOff,
          },
        ),
        const SizedBox(height: ZadSpacing.md),
        if (verdict != null) ...<Widget>[
          _Verdict(
            ok: verdict == ProactiveBreak.none,
            text: _proactiveText(l10n, verdict),
          ),
          const SizedBox(height: ZadSpacing.md),
        ],
        if (moments == null)
          const _ReadFailed()
        else if (moments.isEmpty)
          ZadEmptyState(
            icon: ZadIcons.notifications,
            title: l10n.diagProEmptyTitle,
            message: l10n.diagProEmptyBody,
          )
        else
          for (final m in moments)
            _Line(
              lead: _momentName(l10n, m.moment),
              text: _momentText(l10n, m),
              when: m.at,
            ),
      ],
    );
  }
}

String _proactiveText(ZadL10n l10n, ProactiveBreak b) => switch (b) {
  ProactiveBreak.noChannel => l10n.diagProNoChannel,
  ProactiveBreak.nothingQueued => l10n.diagProNothing,
  ProactiveBreak.failing => l10n.diagProFailing,
  ProactiveBreak.none => l10n.diagProOk,
};

String _momentText(ZadL10n l10n, MomentRow m) => switch (momentOutcome(m)) {
  MomentOutcome.sent => l10n.diagMomentSent,
  MomentOutcome.pending => l10n.diagMomentPending,
  MomentOutcome.skipped => l10n.diagMomentSkipped,
  MomentOutcome.noChannel => l10n.diagMomentNoChannel,
  MomentOutcome.failed => (m.error ?? '').isEmpty ? m.status : m.error!,
};

String _momentName(ZadL10n l10n, String moment) => switch (moment) {
  'morning_greeting' => l10n.diagMomentMorning,
  'good_night' => l10n.diagMomentNight,
  'close_day' => l10n.diagMomentCloseDay,
  'dose_due' => l10n.diagMomentDoseDue,
  'dose_missed' || 'dose_missed_again' => l10n.diagMomentDoseMissed,
  'dose_nudge' => l10n.diagMomentDoseNudge,
  'appointment_soon' => l10n.diagMomentAppointment,
  'weekly_money_story' ||
  'weekly_money_proud' ||
  'weekly_money_reproach' => l10n.diagMomentWeekly,
  'monthly_story' => l10n.diagMomentMonthly,
  _ => moment,
};
