/// Kotlin HomeScreen's blocks that had no Flutter counterpart yet: the
/// offline banner, the companion header row (0b), and the recent
/// transactions (`PremiumTransactionsRow`). Measures and strings are
/// Kotlin's.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_pulses.dart';
import 'package:zad/design/foundation/compose_shadow.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/orb/application/companion_mood.dart';
import 'package:zad/features/orb/application/pet_sound.dart';
import 'package:zad/features/orb/presentation/companion_orb.dart';
import 'package:zad/features/profile/application/profile_controller.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';
import 'package:zad/features/transactions/presentation/transactions_screen.dart';

/// Kotlin's `primary` — `ZadLuxe.emerald`.
const Color _emerald = Color(0xFF1B4332);

/// Kotlin's `textPrimary`.
const Color _textPrimary = Color(0xFF1F1F14);

/// Kotlin's `onSurfaceVariant`.
const Color _onSurfaceVariant = Color(0xFF5F6258);

/// Kotlin's `textTertiary`.
const Color _textTertiary = Color(0xFF6E7065);

/// Kotlin's `warningColor` (`secondary`, ZadMustardOchre).
const Color _warning = Color(0xFFC68216);

/// Kotlin's `dangerColor` (`error`, ZadTerracottaRust).
const Color _danger = Color(0xFFD95726);

/// Kotlin's `outline`.
const Color _outline = Color(0xFFE0E3DA);

// ── offline ──────────────────────────────────────────────────────────────────

/// Whether any network interface is up — what Kotlin's `NetworkMonitor`
/// reports. Starts online, so a cold start does not flash the banner before
/// the first reading.
final StreamProvider<bool> homeOnlineProvider = StreamProvider<bool>((
  ref,
) async* {
  final connectivity = Connectivity();
  bool up(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);
  yield up(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(up);
});

/// `OfflineBanner` + its 16dp gap, only while there is no network.
class HomeOfflineBanner extends ConsumerWidget {
  /// Creates the banner.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(homeOnlineProvider).value ?? true;
    if (online) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          boxShadow: kZadCardShadow,
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.cloud_off, size: 28, color: _warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'مفيش اتصال بالإنترنت',
                    style: ZadType.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    'بياناتك بتتحفظ محلياً وهتتزامن أول ما النت يرجع',
                    style: ZadType.labelMedium.copyWith(
                      color: _onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 0b. the companion header ─────────────────────────────────────────────────

/// Kotlin's 0b row: a white 20dp card with the 56dp companion orb, «أهلاً يا
/// …! 👋» over the pulsing «عقل زاد نشط», and the 40dp camera circle.
/// Tapping the card talks to زاد; the circle opens the camera.
class HomeCompanionHeader extends ConsumerWidget {
  /// Creates the row.
  const new({required this.onOpenVoice, required this.onOpenCamera, super.key});

  /// The card and the orb.
  final VoidCallback onOpenVoice;

  /// The camera circle.
  final VoidCallback onOpenCamera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(profileControllerProvider.select((v) => v.name));
    const radius = BorderRadius.all(Radius.circular(20));
    return Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: _outline, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Kotlin plays the happy chirp, then opens the voice.
        onTap: () {
          playPetSound(PetSound.happyChirp);
          onOpenVoice();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              // Kotlin: the living orb on the shared mood; a tap on it
              // plays its own squeeze-blink-glow before opening the voice.
              CompanionOrb(
                state: ref.watch(companionMoodProvider),
                size: 56,
                onTap: () {
                  playPetSound(PetSound.happyChirp);
                  onOpenVoice();
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'أهلاً يا ${name ?? '...'}! 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZadType.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _emerald,
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        const ZadDotPulse(
                          child: SizedBox.square(
                            dimension: 6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _emerald,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'عقل زاد نشط',
                          style: ZadType.labelMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _emerald.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Material(
                color: _emerald.withValues(alpha: 0.08),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpenCamera,
                  child: const SizedBox.square(
                    dimension: 40,
                    child: Icon(
                      Icons.camera_alt,
                      size: 19,
                      color: _emerald,
                      semanticLabel: 'مسح مخزون',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── recent transactions ──────────────────────────────────────────────────────

/// `PremiumTransactionsRow`: «أحدث المعاملات» with «عرض الكل», then the
/// three newest as 14dp white rows — name and relative day at the start,
/// the signed amount at the end.
class HomeRecentTransactions extends ConsumerWidget {
  /// Creates the block.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kotlin filters out zero-amount rows (bank ads logged as 0) for display.
    final rows = ref.watch(
      transactionsControllerProvider.select((v) => v.rows),
    );
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final zone = ref.watch(accountTimeZoneProvider);
    final now = ref.read(nowProvider)();
    final recent = <ZadTransaction>[
      for (final r in rows)
        if (r.amount != 0) r,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text(
              'أحدث المعاملات',
              style: TextStyle(
                fontSize: 15,
                height: 22 / 15,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const TransactionsScreen(),
                ),
              ),
              child: const Text(
                'عرض الكل',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 22 / 12.5,
                  fontWeight: FontWeight.w600,
                  color: _emerald,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.receipt_long, size: 18, color: _textTertiary),
                SizedBox(width: 8),
                Text(
                  'سيتم عرض المعاملات البنكية هنا',
                  style: TextStyle(fontSize: 12, color: _textTertiary),
                ),
              ],
            ),
          )
        else
          for (var i = 0; i < recent.length && i < 3; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            _TxRow(
              tx: recent[i],
              day: _relativeDay(recent[i].createdAt, now, zone),
              currency: currency,
            ),
          ],
      ],
    );
  }

  /// اليوم / أمس / قبل N أيام, counted in the account's zone.
  static String _relativeDay(DateTime at, DateTime now, String zone) {
    final location = tz.getLocation(zone);
    final a = tz.TZDateTime.from(at.toUtc(), location);
    final b = tz.TZDateTime.from(now.toUtc(), location);
    final days = DateTime.utc(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
    if (days <= 0) return 'اليوم';
    if (days == 1) return 'أمس';
    return 'قبل $days أيام';
  }
}

class _TxRow extends StatelessWidget {
  const new({required this.tx, required this.day, required this.currency});

  final ZadTransaction tx;
  final String day;
  final String currency;

  static final NumberFormat _format = NumberFormat('#,##0.##', 'en');

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: kZadCardShadow,
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                tx.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 22 / 13.5,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                day,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 22 / 11.5,
                  color: _textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${tx.isExpense ? '-' : '+'}${_format.format(tx.amount)} $currency',
          maxLines: 1,
          style: TextStyle(
            fontSize: 14,
            height: 22 / 14,
            fontWeight: FontWeight.w700,
            color: tx.isExpense ? _danger : _emerald,
          ),
        ),
      ],
    ),
  );
}
