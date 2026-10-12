import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';

class _SignedIn extends SessionController {
  @override
  String? build() => 'user-1';
}

class _SignedOut extends SessionController {
  @override
  String? build() => null;
}

AttemptsBalance _plan({required bool ads}) => AttemptsBalance(
  tier: ads ? 'free' : 'plus',
  left: 5,
  perCycle: 5,
  nextRefillAt: null,
  adsEnabled: ads,
);

Future<bool> _allowed({
  bool signedIn = true,
  bool kids = false,
  AttemptsBalance? balance,
}) async {
  final c = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(
        signedIn ? _SignedIn.new : _SignedOut.new,
      ),
      kidsModeActiveProvider.overrideWithValue(kids),
      attemptsBalanceProvider.overrideWith((ref) => Future.value(balance)),
    ],
  );
  addTearDown(c.dispose);
  await c.read(attemptsBalanceProvider.future);
  final allowed = c.read(adsAllowedProvider);
  return allowed;
}

void main() {
  test('a free customer may see ads', () async {
    expect(await _allowed(balance: _plan(ads: true)), isTrue);
  });

  test('kids mode: never, whatever the plan', () async {
    expect(await _allowed(kids: true, balance: _plan(ads: true)), isFalse);
    expect(await _allowed(kids: true), isFalse);
  });

  test('a plan without ads: never', () async {
    expect(await _allowed(balance: _plan(ads: false)), isFalse);
  });

  test('signed out: never', () async {
    expect(await _allowed(signedIn: false, balance: _plan(ads: true)), isFalse);
  });

  test('plan unknown (offline): the free default', () async {
    expect(await _allowed(), isTrue);
  });
}
