/// «خمّن السعر» and «ذاكرة الأسعار» with رفيق زاد (ZAD_PLAN ٥.٤): two short
/// games next to the ball game, on real prices only (`price_games.dart`).
/// Each ends with a pat — joy, as the ball game does — and grants nothing.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/companion/application/price_games_provider.dart';
import 'package:zad/shared/companion/domain/price_games.dart';
import 'package:zad/shared/orb/application/pet_sound.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// Opens «خمّن السعر»; resolves to the right answers.
Future<int?> showPetGuessGame(BuildContext context, {required String name}) =>
    Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        fullscreenDialog: true,
        builder: (_) => PetGuessGame(name: name),
      ),
    );

/// Opens «ذاكرة الأسعار»; resolves to the moves it took.
Future<int?> showPetMemoryGame(BuildContext context, {required String name}) =>
    Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        fullscreenDialog: true,
        builder: (_) => PetMemoryGame(name: name),
      ),
    );

/// The prices, a spinner while they come, or the empty state.
class _WithFacts extends ConsumerWidget {
  const new({
    required this.name,
    required this.facts,
    required this.enough,
    required this.builder,
  });

  final String name;
  final List<PriceFact>? facts;
  final bool Function(List<PriceFact>) enough;
  final Widget Function(List<PriceFact> facts, String currency) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(priceGameCurrencyProvider);
    final given = facts;
    if (given != null) return _orEmpty(given, currency);
    return ref
        .watch(petPriceFactsProvider)
        .when(
          data: (f) => _orEmpty(f, currency),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _orEmpty(const <PriceFact>[], currency),
        );
  }

  Widget _orEmpty(List<PriceFact> f, String currency) => enough(f)
      ? builder(f, currency)
      : Center(
          child: ZadEmptyState(
            key: const ValueKey<String>('price-game-empty'),
            icon: Icons.sell_outlined,
            title: 'لسه مفيش أسعار كفاية',
            message:
                'سجّل كام مصروف أو بلّغ عن سعر في «أسعار الناس»، '
                'و$name هيلعب معاك بيها.',
          ),
        );
}

String _withCurrency(double p, String currency) =>
    currency.isEmpty ? priceText(p) : '${priceText(p)} $currency';

/// The buttons at the end of a game: again, or done with [result].
class _EndButtons extends StatelessWidget {
  const new({required this.again, required this.result});

  final Widget Function() again;
  final int result;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: FilledButton(
          key: const ValueKey<String>('price-game-again'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<int>(
              fullscreenDialog: true,
              builder: (_) => again(),
            ),
          ),
          child: const Text('🔁 تاني'),
        ),
      ),
      const SizedBox(width: ZadSpacing.md),
      Expanded(
        child: OutlinedButton(
          key: const ValueKey<String>('price-game-done'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: () => Navigator.of(context).pop(result),
          child: const Text('خلصت'),
        ),
      ),
    ],
  );
}

// ───────────────────────────── خمّن السعر ─────────────────────────────

/// «خمّن السعر»: five items, three prices each, one of them real.
class PetGuessGame extends ConsumerStatefulWidget {
  /// Creates it.
  const new({required this.name, this.facts, this.rng, super.key});

  /// The pet's name.
  final String name;

  /// The prices; null reads them ([petPriceFactsProvider]). Tests pass some.
  final List<PriceFact>? facts;

  /// The draw; tests pass a seeded one.
  final math.Random? rng;

  @override
  ConsumerState<PetGuessGame> createState() => _PetGuessGameState();
}

class _PetGuessGameState extends ConsumerState<PetGuessGame> {
  late final math.Random _rng = widget.rng ?? math.Random();
  List<GuessRound>? _rounds;
  int _at = 0;
  int _right = 0;
  int? _picked;
  CompanionState _mood = CompanionState.happy;
  bool _over = false;

  void _pick(GuessRound round, int i) {
    if (_picked != null) return;
    final ok = i == round.answer;
    unawaited(HapticFeedback.lightImpact());
    playPetSound(ok ? PetSound.happyChirp : PetSound.whimper);
    setState(() {
      _picked = i;
      if (ok) _right++;
      _mood = ok ? CompanionState.celebrating : CompanionState.sad;
    });
  }

  void _next(int total) {
    if (_at + 1 >= total) {
      ref.read(petCareProvider.notifier).pet();
      playPetSound(PetSound.purr);
      setState(() {
        _over = true;
        _mood = CompanionState.celebrating;
      });
      return;
    }
    setState(() {
      _at++;
      _picked = null;
      _mood = CompanionState.happy;
    });
  }

  String _verdict(int total) {
    if (_right == total) return 'كلهم صح! ${widget.name} مش مصدّق 🏆';
    if (_right * 2 >= total) return 'برافو! عينك على الأسعار 🤩';
    if (_right > 0) return 'مش وحش! ${widget.name} اتبسط 😊';
    return 'الأسعار غلبتنا المرة دي 😅 تاني؟';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ZadColors.surface,
    appBar: AppBar(title: const Text('💰 خمّن السعر')),
    body: SafeArea(
      child: _WithFacts(
        name: widget.name,
        facts: widget.facts,
        enough: (f) => f.length >= guessMinFacts,
        builder: (facts, currency) {
          final rounds = _rounds ??= guessRounds(facts, _rng);
          return _board(rounds, currency);
        },
      ),
    ),
  );

  Widget _board(List<GuessRound> rounds, String currency) {
    final round = rounds[_at];
    final picked = _picked;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZadSpacing.xl,
        ZadSpacing.md,
        ZadSpacing.xl,
        ZadSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _over
                ? '$_right من ${rounds.length}'
                : 'سؤال ${_at + 1} من ${rounds.length} · صح $_right',
            key: const ValueKey<String>('guess-progress'),
            textAlign: TextAlign.center,
            style: ZadType.labelLarge.copyWith(color: ZadColors.textTertiary),
          ),
          const SizedBox(height: ZadSpacing.md),
          Center(child: CompanionOrb(state: _mood, size: 112)),
          const SizedBox(height: ZadSpacing.lg),
          if (_over)
            Text(
              _verdict(rounds.length),
              key: const ValueKey<String>('guess-verdict'),
              textAlign: TextAlign.center,
              style: ZadType.titleLarge,
            )
          else ...<Widget>[
            Text(
              'بكام «${round.fact.label}»؟',
              key: const ValueKey<String>('guess-question'),
              textAlign: TextAlign.center,
              style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: ZadSpacing.xs),
            AnimatedOpacity(
              opacity: picked == null ? 0 : 1,
              duration: ZadDuration.quick,
              child: Text(
                '${round.fact.source.label}: '
                '${_withCurrency(round.fact.price, currency)}',
                key: const ValueKey<String>('guess-source'),
                textAlign: TextAlign.center,
                style: ZadType.bodyMedium.copyWith(
                  color: ZadColors.textTertiary,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (_over)
            _EndButtons(
              result: _right,
              again: () => PetGuessGame(name: widget.name, facts: widget.facts),
            )
          else ...<Widget>[
            for (final (i, p) in round.options.indexed) ...<Widget>[
              _OptionButton(
                key: ValueKey<String>('guess-option-$i'),
                text: _withCurrency(p, currency),
                tone: picked == null
                    ? null
                    : i == round.answer
                    ? ZadColors.forestEmerald
                    : i == picked
                    ? ZadColors.terracottaRust
                    : null,
                onTap: () => _pick(round, i),
              ),
              const SizedBox(height: ZadSpacing.sm),
            ],
            const SizedBox(height: ZadSpacing.xs),
            FilledButton(
              key: const ValueKey<String>('guess-next'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: picked == null ? null : () => _next(rounds.length),
              child: Text(_at + 1 >= rounds.length ? 'النتيجة' : 'اللي بعده'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const new({
    required this.text,
    required this.tone,
    required this.onTap,
    super.key,
  });

  final String text;
  final Color? tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = this.tone;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: tone?.withValues(alpha: 0.12),
        side: BorderSide(color: tone ?? ZadColors.outline, width: 1.5),
        foregroundColor: tone ?? ZadColors.ink,
      ),
      onPressed: onTap,
      child: Text(
        text,
        style: ZadType.titleMedium.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ──────────────────────────── ذاكرة الأسعار ────────────────────────────

/// «ذاكرة الأسعار»: turn two cards; an item and its own price stay up.
class PetMemoryGame extends ConsumerStatefulWidget {
  /// Creates it.
  const new({required this.name, this.facts, this.rng, super.key});

  /// The pet's name.
  final String name;

  /// The prices; null reads them ([petPriceFactsProvider]). Tests pass some.
  final List<PriceFact>? facts;

  /// The shuffle; tests pass a seeded one.
  final math.Random? rng;

  /// How long a wrong pair stays turned.
  static const Duration peek = Duration(milliseconds: 900);

  @override
  ConsumerState<PetMemoryGame> createState() => _PetMemoryGameState();
}

class _PetMemoryGameState extends ConsumerState<PetMemoryGame> {
  late final math.Random _rng = widget.rng ?? math.Random();
  List<MemoryCard>? _deck;
  final Set<int> _matched = <int>{};
  final List<int> _up = <int>[];
  Timer? _flipBack;
  int _moves = 0;
  CompanionState _mood = CompanionState.happy;
  bool _over = false;

  @override
  void dispose() {
    _flipBack?.cancel();
    super.dispose();
  }

  void _turn(List<MemoryCard> deck, int i) {
    if (_over || _up.length == 2 || _up.contains(i)) return;
    if (_matched.contains(deck[i].pair)) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _up.add(i));
    if (_up.length < 2) return;
    _moves++;
    final a = deck[_up[0]];
    final b = deck[_up[1]];
    if (a.pair == b.pair && a.isPrice != b.isPrice) {
      playPetSound(PetSound.happyChirp);
      setState(() {
        _matched.add(a.pair);
        _up.clear();
        _mood = CompanionState.celebrating;
      });
      if (_matched.length * 2 == deck.length) {
        ref.read(petCareProvider.notifier).pet();
        playPetSound(PetSound.purr);
        setState(() => _over = true);
      }
      return;
    }
    setState(() => _mood = CompanionState.focused);
    _flipBack = Timer(PetMemoryGame.peek, () {
      if (!mounted) return;
      setState(() {
        _up.clear();
        _mood = CompanionState.happy;
      });
    });
  }

  String _verdict(int pairs) => _moves <= pairs + 1
      ? 'ذاكرة حديد! ${widget.name} مبهور 🏆'
      : _moves <= pairs * 2
      ? 'برافو! خلصتها في $_moves محاولات 🤩'
      : 'خلصناها في $_moves محاولات، ${widget.name} اتبسط 😊';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ZadColors.surface,
    appBar: AppBar(title: const Text('🧠 ذاكرة الأسعار')),
    body: SafeArea(
      child: _WithFacts(
        name: widget.name,
        facts: widget.facts,
        enough: (f) => memoryDeck(f, math.Random(0)).isNotEmpty,
        builder: (facts, currency) {
          final deck = _deck ??= memoryDeck(facts, _rng);
          return _board(deck, currency);
        },
      ),
    ),
  );

  Widget _board(List<MemoryCard> deck, String currency) => Padding(
    padding: const EdgeInsets.fromLTRB(
      ZadSpacing.lg,
      ZadSpacing.md,
      ZadSpacing.lg,
      ZadSpacing.lg,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            CompanionOrb(state: _mood, size: 72),
            const SizedBox(width: ZadSpacing.md),
            Expanded(
              child: Text(
                _over
                    ? _verdict(deck.length ~/ 2)
                    : 'وصّل كل حاجة بسعرها · محاولات $_moves',
                key: const ValueKey<String>('memory-status'),
                style: ZadType.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        Expanded(
          // Rows that share the space, so every card shows on any screen.
          child: Column(
            children: <Widget>[
              for (var row = 0; row < deck.length; row += 2)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (var i = row; i < row + 2 && i < deck.length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                end: i == row ? ZadSpacing.sm : 0,
                              ),
                              child: _MemoryTile(
                                key: ValueKey<String>('memory-card-$i'),
                                card: deck[i],
                                currency: currency,
                                up:
                                    _up.contains(i) ||
                                    _matched.contains(deck[i].pair),
                                matched: _matched.contains(deck[i].pair),
                                onTap: () => _turn(deck, i),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_over)
          _EndButtons(
            result: _moves,
            again: () => PetMemoryGame(name: widget.name, facts: widget.facts),
          ),
      ],
    ),
  );
}

class _MemoryTile extends StatelessWidget {
  const new({
    required this.card,
    required this.currency,
    required this.up,
    required this.matched,
    required this.onTap,
    super.key,
  });

  final MemoryCard card;
  final String currency;
  final bool up;
  final bool matched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final face = card.isPrice
        ? (currency.isEmpty ? card.text : '${card.text} $currency')
        : card.text;
    return Material(
      color: matched
          ? ZadColors.mint100
          : up
          ? ZadColors.surfaceVariant
          : ZadColors.forestEmerald,
      borderRadius: BorderRadius.circular(ZadRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZadRadii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.sm),
          child: Center(
            child: AnimatedSwitcher(
              duration: ZadDuration.quick,
              child: up
                  ? Text(
                      face,
                      key: ValueKey<bool>(up),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (card.isPrice
                                  ? ZadType.titleLarge
                                  : ZadType.titleSmall)
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                color: ZadColors.ink,
                              ),
                    )
                  : Text(
                      card.isPrice ? '💰' : '🛒',
                      key: ValueKey<bool>(up),
                      style: ZadType.headlineMedium,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
