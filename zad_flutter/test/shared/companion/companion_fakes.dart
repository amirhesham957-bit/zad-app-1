import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/data/companion_remote.dart';
import 'package:zad/shared/companion/domain/companion_status.dart';

/// A signed-in session.
class SignedIn extends SessionController {
  @override
  String? build() => 'user-1';
}

/// The server's answer, as `zad_companion_status()` shapes it.
Map<String, dynamic> statusJson({
  String persona = 'zado',
  String? outfit,
  int xp = 130,
  int level = 2,
  int stage = 0,
  int seeds = 80,
  int streak = 3,
  List<String> owned = const <String>['morning', 'zado'],
  Map<String, dynamic>? celebrate,
  int welcomeBack = 0,
  int awayHours = 0,
  bool log = true,
  bool pantry = false,
  bool scan = false,
}) => <String, dynamic>{
  'persona': persona,
  'outfit': outfit,
  'background': 'morning',
  'xp': xp,
  'level': level,
  'level_xp': 30,
  'level_need': 140,
  'stage': stage,
  'next_stage': <String, dynamic>{'level': 4, 'days': 3},
  'age_days': 1,
  'seeds': seeds,
  'streak': streak,
  'best_streak': 5,
  'today': <String, dynamic>{
    'log': log,
    'pantry': pantry,
    'scan': scan,
    'xp': 35,
  },
  'owned': owned,
  'invite_code': 'ZAD-7KQ4-M9TX',
  'invites': 1,
  'invites_pending': 2,
  'can_claim_invite': true,
  'celebrate': celebrate,
  'week': <String, dynamic>{'days': 3, 'goal': 5, 'done': false},
  'welcome_back': welcomeBack,
  'away_hours': awayHours,
};

/// A server in memory that records what it was asked.
class FakeCompanionRemote implements CompanionRemote {
  new(this.json);

  Map<String, dynamic> json;
  final List<String> calls = <String>[];
  CompanionResult next = (ok: true, reason: null, missing: null);

  @override
  Future<CompanionStatus?> status() async {
    calls.add('status');
    return CompanionStatus.fromJson(json);
  }

  @override
  Future<void> ack() async {
    calls.add('ack');
    json = <String, dynamic>{...json, 'celebrate': null};
  }

  @override
  Future<CompanionResult> equip(String item) async {
    calls.add('equip:$item');
    if (next.ok) json = <String, dynamic>{...json, 'persona': item};
    return next;
  }

  @override
  Future<CompanionResult> buy(String item, {String? season}) async {
    calls.add('buy:$item');
    if (next.ok) {
      json = <String, dynamic>{
        ...json,
        'owned': <String>[...(json['owned'] as List<String>), item],
      };
    }
    return next;
  }

  @override
  Future<CompanionResult> claimInvite(String code) async {
    calls.add('claim:$code');
    return next;
  }
}
