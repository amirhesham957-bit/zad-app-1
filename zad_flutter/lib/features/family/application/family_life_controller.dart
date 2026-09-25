/// The family screen's shared life: the live chat, chores, the grocery list,
/// goals and — for a parent — the children's spending.
///
/// Built only while the screen is open (auto-dispose): the chat stream and
/// the presence ping stop when the customer leaves, which is what Kotlin's
/// typing monitor failed to do (it kept polling after the screen closed).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/family/data/family_life_remote.dart';
import 'package:zad/features/family/domain/family.dart';
import 'package:zad/features/family/domain/family_life.dart';

/// What the tabs draw.
class FamilyLifeView {
  /// Creates a view.
  const new({
    this.messages = const <FamilyMessage>[],
    this.chores = const <Chore>[],
    this.groceries = const <SharedGroceryItem>[],
    this.goals = const <FamilyGoal>[],
    this.trees = const <TasbihaTree>[],
    this.childrenSpending = const <String, ChildSpending>{},
    this.suggestion,
    this.isSuggesting = false,
    this.isLoading = true,
    this.notice,
    this.noticeSerial = 0,
  });

  /// The chat, oldest first.
  final List<FamilyMessage> messages;

  /// Every chore.
  final List<Chore> chores;

  /// The shared grocery list.
  final List<SharedGroceryItem> groceries;

  /// Savings goals.
  final List<FamilyGoal> goals;

  /// Tasbiha trees.
  final List<TasbihaTree> trees;

  /// By child member id; a parent's view only.
  final Map<String, ChildSpending> childrenSpending;

  /// A goal زاد suggested, waiting for an admin.
  final GoalSuggestion? suggestion;

  /// Whether زاد is thinking of a goal.
  final bool isSuggesting;

  /// Whether the first read is still out.
  final bool isLoading;

  /// Something to tell the customer once.
  final String? notice;

  /// Bumped with each notice, so the same words twice still show twice.
  final int noticeSerial;

  /// The trees of [userId].
  List<TasbihaTree> treesOf(String userId) =>
      trees.where((t) => t.userId == userId).toList();

  /// A copy with the given fields replaced.
  FamilyLifeView copyWith({
    List<FamilyMessage>? messages,
    List<Chore>? chores,
    List<SharedGroceryItem>? groceries,
    List<FamilyGoal>? goals,
    List<TasbihaTree>? trees,
    Map<String, ChildSpending>? childrenSpending,
    GoalSuggestion? suggestion,
    bool clearSuggestion = false,
    bool? isSuggesting,
    bool? isLoading,
    String? notice,
  }) => FamilyLifeView(
    messages: messages ?? this.messages,
    chores: chores ?? this.chores,
    groceries: groceries ?? this.groceries,
    goals: goals ?? this.goals,
    trees: trees ?? this.trees,
    childrenSpending: childrenSpending ?? this.childrenSpending,
    suggestion: clearSuggestion ? null : (suggestion ?? this.suggestion),
    isSuggesting: isSuggesting ?? this.isSuggesting,
    isLoading: isLoading ?? this.isLoading,
    notice: notice ?? this.notice,
    noticeSerial: notice == null ? noticeSerial : noticeSerial + 1,
  );
}

/// Kotlin's quick replies, in its order.
const List<(String, String)> kFamilyQuickReplies = <(String, String)>[
  ('👍', 'تمام'),
  ('🕒', 'سأصل قريباً'),
  ('🛒', 'أضف حليب إلى القائمة'),
  ('🍞', 'أضف خبز إلى القائمة'),
  ('💰', 'أحتاج مصروف'),
  ('🍕', 'شو رأيكم نطلب أكل؟'),
  ('🌟', 'أحسنتم جميعاً!'),
  ('🙏', 'شكراً جزيلاً'),
  ('😊', 'الله يسعدكم'),
  ('🔥', 'استمرار في التسبيحة!'),
];

/// Holds the family's shared life and changes it.
class FamilyLifeController extends Notifier<FamilyLifeView> {
  StreamSubscription<List<Map<String, dynamic>>>? _chat;
  Timer? _presence;

  FamilyLifeRemote get _remote => ref.read(familyLifeRemoteProvider);

  Family? get _family => ref.read(familyControllerProvider).family;

  FamilyMember? get _me {
    final view = ref.read(familyControllerProvider);
    return view.family?.me(view.userId);
  }

  @override
  FamilyLifeView build() {
    final familyId = ref.watch(
      familyControllerProvider.select((v) => v.family?.id),
    );
    ref.onDispose(() {
      unawaited(_chat?.cancel());
      _presence?.cancel();
    });
    if (familyId == null) return const FamilyLifeView(isLoading: false);

    _chat = _remote
        .watchMessages(familyId)
        .listen(
          (rows) {
            if (!ref.mounted) return;
            state = state.copyWith(
              messages: <FamilyMessage>[
                for (final r in rows) FamilyMessage.fromJson(r),
              ],
            );
          },
          onError: (Object _) {
            // The chat keeps what it has; the next open resubscribes.
          },
        );
    _presence = Timer.periodic(const Duration(minutes: 1), (_) => _touch());
    unawaited(
      Future<void>.microtask(() {
        if (!ref.mounted) return;
        _touch();
        unawaited(refresh());
      }),
    );
    return const FamilyLifeView();
  }

  void _touch() {
    final me = _me;
    if (me != null) unawaited(_remote.touchLastSeen(me.id).catchError((_) {}));
  }

  /// Reads chores, groceries, goals and trees again; a parent's children's
  /// spending too.
  Future<void> refresh() async {
    final family = _family;
    if (family == null) return;
    try {
      final results = await Future.wait(<Future<List<Map<String, dynamic>>>>[
        _remote.fetchChores(family.id),
        _remote.fetchGroceries(family.id),
        _remote
            .fetchGoals(family.id)
            .catchError((_) => <Map<String, dynamic>>[]),
        _remote
            .fetchTrees(family.id)
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!ref.mounted) return;
      state = state.copyWith(
        chores: <Chore>[for (final r in results[0]) Chore.fromJson(r)],
        groceries: <SharedGroceryItem>[
          for (final r in results[1]) SharedGroceryItem.fromJson(r),
        ],
        goals: <FamilyGoal>[for (final r in results[2]) FamilyGoal.fromJson(r)],
        trees: <TasbihaTree>[
          for (final r in results[3]) TasbihaTree.fromJson(r),
        ],
        isLoading: false,
      );
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(
          isLoading: false,
          notice: 'مقدرتش أجيب بيانات العيلة. اسحب لتحت نجرب تاني.',
        );
      }
    }
    if (ref.read(familyControllerProvider).isAdmin) {
      unawaited(loadChildrenSpending());
    }
  }

  /// Kotlin's `loadChildrenSpending`: each child's real spending this month
  /// against their own monthly limit.
  Future<void> loadChildrenSpending() async {
    final family = _family;
    if (family == null) return;
    final children = family.members
        .where((m) => m.role == FamilyRole.child)
        .toList();
    if (children.isEmpty) return;
    try {
      final now = ref.read(nowProvider)();
      final monthStart = DateTime(now.year, now.month);
      final rows = await _remote.fetchFamilyExpenses(family.id, monthStart);
      final limits = await _remote.fetchMonthlyLimits(<String>[
        for (final c in children) c.userId,
      ]);
      if (!ref.mounted) return;
      state = state.copyWith(
        childrenSpending: <String, ChildSpending>{
          for (final child in children)
            child.id: ChildSpending(
              monthlyTotal: <double>[
                for (final r in rows)
                  if (r['user_id'] == child.userId)
                    (r['amount'] as num?)?.toDouble() ?? 0,
              ].fold(0, (a, b) => a + b),
              budgetCeiling: limits[child.userId] ?? 0,
            ),
        },
      );
    } on Object {
      // A parent's extra view; its absence is not worth a message.
    }
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  /// Sends a message, then does what Kotlin does with its words: "@زاد" asks
  /// the assistant (or sets a chore, for an admin: "@زاد كلف أحمد يرتب
  /// أوضته"), and "أضف …" puts it on the grocery list.
  Future<bool> send(
    String text, {
    FamilyMessageType type = FamilyMessageType.text,
    String? metadata,
  }) async {
    final family = _family;
    final me = _me;
    final message = text.trim();
    if (family == null || me == null || message.isEmpty) return false;
    try {
      await _remote.sendMessage(
        familyId: family.id,
        senderId: me.id,
        message: message,
        type: type.wireName,
        metadata: metadata,
      );
    } on Object {
      _say('الرسالة ماتبعتتش — اتأكد من النت.');
      return false;
    }
    if (type != FamilyMessageType.text) return true;

    final mentionsZad = RegExp('@(Zad|زاد)', caseSensitive: false);
    final wantsGrocery = RegExp('(أضف|نقص|شراء)');
    if (mentionsZad.hasMatch(message)) {
      final clean = message
          .replaceAll(RegExp(r'@(Zad|زاد)\s*', caseSensitive: false), '')
          .trim();
      if (wantsGrocery.hasMatch(clean)) {
        await _groceryFromChat(clean);
      } else {
        await _zadTaskOrQuestion(clean);
      }
    } else if (wantsGrocery.hasMatch(message)) {
      await _groceryFromChat(message);
    }
    return true;
  }

  Future<void> _zadSays(String text) async {
    final family = _family;
    if (family == null) return;
    try {
      await _remote.sendMessage(
        familyId: family.id,
        senderId: kZadSenderId,
        message: text,
        type: FamilyMessageType.text.wireName,
      );
    } on Object {
      // زاد's reply is a courtesy; the customer's own message already went.
    }
  }

  Future<void> _groceryFromChat(String raw) async {
    final name = raw
        .replaceAll(RegExp('(أضف|نقص|احتاج|شراء|إلى القائمة|للقائمة)'), '')
        .trim();
    if (name.isEmpty) {
      await _zadSays("الرجاء تحديد اسم العنصر بوضوح. مثال: 'أضف حليب'");
      return;
    }
    final added = await addGrocery(name, quiet: true);
    await _zadSays(
      added
          ? "تم إضافة '$name' إلى قائمة التسوق بنجاح ✅"
          : "عذراً، حدث خطأ أثناء إضافة '$name' ❌",
    );
  }

  Future<void> _zadTaskOrQuestion(String clean) async {
    final family = _family;
    final me = _me;
    if (family == null || me == null) return;
    final task = RegExp(r'^(?:كلف|مهمة)\s+(.+)').firstMatch(clean);
    if (task != null && me.role == FamilyRole.admin) {
      final rest = task.group(1)!.trim();
      final first = rest.split(' ').first;
      final match = family.members
          .where((m) => m.alias == first || m.alias.contains(first))
          .firstOrNull;
      final assignee = match ?? me;
      final title = match != null ? rest.substring(first.length).trim() : rest;
      if (title.isNotEmpty) {
        final ok = await addChore(assignedTo: assignee.id, title: title);
        if (ok) {
          await _zadSays("تم إضافة مهمة لـ ${assignee.alias}: '$title' ✅");
        }
        return;
      }
    }
    try {
      final answer = await _remote.ask(
        'family_assistant',
        ref.read(familyControllerProvider).userId,
        <String, dynamic>{
          'message': '${_contextBlock(family, me)}\n\nسؤال العضو: $clean',
          'role': me.role.wireName,
        },
      );
      await _zadSays(
        (answer['text'] as String?) ??
            'الذكاء الاصطناعي مشغول شوي دلوقتي 🙏 جرب تاني بعد لحظات.',
      );
    } on Object {
      await _zadSays(
        'الذكاء الاصطناعي مشغول شوي دلوقتي 🙏 جرب تاني بعد لحظات.',
      );
    }
  }

  /// Kotlin's `buildFamilyContextBlock`: the family's real figures, fenced,
  /// so the assistant answers from them and cannot be redefined by them.
  String _contextBlock(Family family, FamilyMember me) {
    final pendingChores = state.chores.where((c) => !c.isCompleted).toList();
    final pendingGroceries = state.groceries
        .where((g) => !g.isPurchased)
        .toList();
    String aliasOf(String id) =>
        family.members.where((m) => m.id == id).firstOrNull?.alias ?? '?';
    final choresLine = pendingChores.isEmpty
        ? 'لا يوجد'
        : pendingChores
              .take(10)
              .map((c) => '${c.title} (${aliasOf(c.assignedTo)})')
              .join('، ');
    final groceriesLine = pendingGroceries.isEmpty
        ? 'لا يوجد'
        : pendingGroceries.take(15).map((g) => g.itemName).join('، ');
    return <String>[
      _contextHeader,
      'اسم السائل: ${me.alias} | الدور: ${me.role.wireName}',
      'رصيده: ${me.balance}',
      if (me.dailyLimit != null) 'حد الصرف اليومي: ${me.dailyLimit}',
      if (me.weeklyLimit != null) 'حد الصرف الأسبوعي: ${me.weeklyLimit}',
      'عدد أفراد العائلة: ${family.members.length}',
      'المهام المعلقة (${pendingChores.length}): $choresLine',
      'عناصر التسوق المطلوبة (${pendingGroceries.length}): $groceriesLine',
      '=== نهاية البيانات ===',
    ].join('\n');
  }

  /// A purchase request in the customer's own name.
  Future<bool> requestMoney(String what, double amount) => send(
    'أحتاج ${_plain(amount)} لشراء $what',
    type: FamilyMessageType.purchaseRequest,
    metadata: jsonEncode(<String, dynamic>{
      'amount': amount,
      'status': 'PENDING',
    }),
  );

  /// A poll.
  Future<bool> sendPoll(String question, List<String> options) => send(
    '📊 $question',
    type: FamilyMessageType.poll,
    metadata: jsonEncode(<String, dynamic>{
      'question': question,
      'options': options,
      'votes': <String, int>{},
    }),
  );

  /// The SOS call.
  Future<bool> sendSos() =>
      send('الرجاء الانتباه، حالة طوارئ!', type: FamilyMessageType.sos);

  /// An admin's decision on a purchase request. The server debits the sender
  /// on approval and notifies them.
  Future<void> decide(FamilyMessage request, {required bool approve}) async {
    try {
      final result = await _remote.decideRequest(request.id, approve: approve);
      if (result['ok'] != true) {
        _say(switch (result['reason']) {
          'not_an_admin' => 'القرار ده للمسؤول بس.',
          _ => 'مقدرتش أسجّل القرار. جرّب تاني.',
        });
        return;
      }
      if (result['already'] == true) return;
      await send(
        approve
            ? 'تمت الموافقة على طلب: ${request.message}'
            : 'تم رفض طلب: ${request.message}',
      );
      unawaited(ref.read(familyControllerProvider.notifier).refresh());
    } on Object {
      _say('مقدرتش أوصل للسيرفر. جرّب تاني.');
    }
  }

  /// Pins or unpins.
  Future<void> togglePin(FamilyMessage message) => _patch(
    message.copyWith(isPinned: !message.isPinned),
    () => _remote.setPinned(message.id, pinned: !message.isPinned),
  );

  /// Adds or takes back one [emoji].
  Future<void> react(FamilyMessage message, String emoji) {
    final next = toggledReactions(message.reactions, emoji);
    return _patch(
      message.copyWith(reactions: next),
      () => _remote.setReactions(message.id, next),
    );
  }

  /// Votes on a poll — the member's vote replaces their earlier one.
  Future<void> vote(FamilyMessage poll, int option) {
    final me = _me;
    if (me == null) return Future<void>.value();
    final meta = <String, dynamic>{...poll.meta};
    meta['votes'] = <String, int>{...poll.pollVotes, me.id: option};
    final encoded = jsonEncode(meta);
    return _patch(
      poll.copyWith(metadata: encoded),
      () => _remote.setMetadata(poll.id, encoded),
    );
  }

  Future<void> _patch(FamilyMessage next, Future<void> Function() write) async {
    final before = state.messages;
    state = state.copyWith(
      messages: <FamilyMessage>[
        for (final m in before)
          if (m.id == next.id) next else m,
      ],
    );
    try {
      await write();
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(messages: before, notice: 'التعديل ماتحفظش.');
    }
  }

  // ── Chores ────────────────────────────────────────────────────────────────

  /// Sets a chore.
  Future<bool> addChore({
    required String assignedTo,
    required String title,
    String? dueDate,
    double reward = 0,
  }) async {
    final family = _family;
    if (family == null || title.trim().isEmpty) return false;
    try {
      await _remote.addChore(
        familyId: family.id,
        assignedTo: assignedTo,
        title: title.trim(),
        dueDate: dueDate,
        reward: reward,
      );
      await refresh();
      return true;
    } on Object catch (e) {
      _say(
        '$e'.contains('only_admins_set_rewards')
            ? 'المكافأة يحددها المسؤول بس.'
            : 'المهمة ماتضافتش. جرّب تاني.',
      );
      return false;
    }
  }

  /// Ticks a chore done (the server pays its reward once), or — an admin
  /// only — reopens it and takes the reward back.
  Future<void> toggleChore(Chore chore) async {
    try {
      final result = chore.isCompleted
          ? await _remote.reopenChore(chore.id)
          : await _remote.completeChore(chore.id);
      if (result['ok'] != true) {
        _say(switch (result['reason']) {
          'not_an_admin' => 'إلغاء إنجاز المهمة للمسؤول بس.',
          'not_yours' => 'دي مهمة حد تاني.',
          _ => 'مقدرتش أحدّث المهمة.',
        });
        return;
      }
      final paid = (result['paid'] as num?)?.toDouble() ?? 0;
      if (!chore.isCompleted && paid > 0) {
        _say('عمل رائع! 🌟 اتضاف $paid للرصيد.');
      }
      await refresh();
      unawaited(ref.read(familyControllerProvider.notifier).refresh());
    } on Object {
      _say('مقدرتش أوصل للسيرفر. جرّب تاني.');
    }
  }

  // ── Groceries ─────────────────────────────────────────────────────────────

  /// Adds a line to the family's list.
  Future<bool> addGrocery(String name, {bool quiet = false}) async {
    final family = _family;
    final me = _me;
    final clean = name.trim();
    if (family == null || me == null || clean.isEmpty) return false;
    try {
      final row = await _remote.addGrocery(
        familyId: family.id,
        addedBy: me.id,
        itemName: clean,
      );
      if (!ref.mounted) return true;
      state = state.copyWith(
        groceries: <SharedGroceryItem>[
          ...state.groceries,
          SharedGroceryItem.fromJson(row),
        ],
      );
      return true;
    } on Object {
      if (!quiet) _say('الصنف ماتضافش. جرّب تاني.');
      return false;
    }
  }

  /// Ticks or unticks a line.
  Future<void> toggleGrocery(SharedGroceryItem item) async {
    final before = state.groceries;
    state = state.copyWith(
      groceries: <SharedGroceryItem>[
        for (final g in before)
          if (g.id == item.id) g.withPurchased(value: !item.isPurchased) else g,
      ],
    );
    try {
      await _remote.setGroceryPurchased(item.id, purchased: !item.isPurchased);
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(groceries: before, notice: 'التعديل ماتحفظش.');
      }
    }
  }

  // ── Limits and goals ──────────────────────────────────────────────────────

  /// A parent's daily and weekly caps for [member]; null clears one.
  Future<bool> setSpendLimits(
    FamilyMember member, {
    double? daily,
    double? weekly,
  }) async {
    try {
      final row = await _remote.setSpendLimits(
        member.id,
        daily: daily,
        weekly: weekly,
      );
      if (row == null) {
        _say('حدود الصرف يحطها المسؤول بس.');
        return false;
      }
      await ref.read(familyControllerProvider.notifier).refresh();
      return true;
    } on Object {
      _say('الحدود ماتحفظتش. جرّب تاني.');
      return false;
    }
  }

  /// Asks زاد for a family savings goal — on a tap, never on open.
  Future<void> suggestGoal() async {
    final family = _family;
    if (family == null || state.isSuggesting) return;
    state = state.copyWith(isSuggesting: true);
    try {
      final kids = family.members.where((m) => m.role != FamilyRole.admin);
      final answer = await _remote.ask(
        'family_goals_suggest',
        ref.read(familyControllerProvider).userId,
        <String, dynamic>{
          'members': family.members
              .map((m) => '${m.alias}(${m.role.wireName})')
              .join(', '),
          'total_balance': kids.fold<double>(0, (a, m) => a + m.balance),
          'completed_tasks': state.chores.where((c) => c.isCompleted).length,
          'tasbiha_score': state.trees.fold<int>(0, (a, t) => a + t.score),
        },
      );
      if (!ref.mounted) return;
      final suggestion = GoalSuggestion.fromJson(answer);
      state = suggestion.targetAmount > 0
          ? state.copyWith(isSuggesting: false, suggestion: suggestion)
          : state.copyWith(
              isSuggesting: false,
              notice: 'زاد ماقدرش يقترح هدف دلوقتي. جرّب تاني.',
            );
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(
          isSuggesting: false,
          notice: 'زاد ماقدرش يقترح هدف دلوقتي. جرّب تاني.',
        );
      }
    }
  }

  /// Drops the suggestion.
  void clearSuggestion() => state = state.copyWith(clearSuggestion: true);

  /// Makes the suggestion this month's goal.
  Future<void> approveSuggestion() async {
    final family = _family;
    final suggestion = state.suggestion;
    if (family == null || suggestion == null) return;
    final now = ref.read(nowProvider)();
    try {
      await _remote.addGoal(
        familyId: family.id,
        target: suggestion.targetAmount,
        monthYear: '${now.year}-${now.month.toString().padLeft(2, '0')}',
        reward: suggestion.rewardSuggestion.isEmpty
            ? null
            : suggestion.rewardSuggestion,
      );
      state = state.copyWith(clearSuggestion: true);
      await refresh();
    } on Object {
      _say('الهدف ماتحفظش. جرّب تاني.');
    }
  }

  void _say(String words) {
    if (ref.mounted) state = state.copyWith(notice: words);
  }
}

const String _contextHeader =
    '=== بيانات العائلة الحقيقية (استخدمها في إجابتك، متختلقش أرقام تانية) ===';

String _plain(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// The remote.
final familyLifeRemoteProvider = Provider<FamilyLifeRemote>(
  (ref) => FamilyLifeRemote(ref.watch(supabaseClientProvider)),
);

/// The family's shared life, while the family screen is open.
final NotifierProvider<FamilyLifeController, FamilyLifeView>
familyLifeControllerProvider =
    NotifierProvider.autoDispose<FamilyLifeController, FamilyLifeView>(
      FamilyLifeController.new,
    );
