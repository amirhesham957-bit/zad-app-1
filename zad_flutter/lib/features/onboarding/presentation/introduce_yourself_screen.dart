/// «عرّفني بيك» — the one-time introduction every account passes through.
///
/// What Zad cannot do without from the first day: the name to call the
/// customer, whether to address them as a man or a woman, their place in the
/// home, and who they look after. It used to be an optional card on home and
/// a sheet three screens deep; on the live project four accounts out of four
/// had no gender and one had a profile at all, so the brain spoke to everyone
/// in a neutral voice and assumed every customer was a parent of children.
///
/// Shown by the auth gate once the server has answered that the profile is
/// incomplete — never on a failed read, which would ask someone who has
/// already answered.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/onboarding/application/first_steps_controller.dart';
import 'package:zad/shared/brain/application/memory_controller.dart';
import 'package:zad/shared/brain/domain/customer_profile.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/profile/application/profile_controller.dart';

/// Implied by a role, so choosing «أم» answers the gender question too.
const Map<String, String> _roleGender = <String, String>{
  'father': 'male',
  'husband': 'male',
  'son': 'male',
  'mother': 'female',
  'wife': 'female',
  'daughter': 'female',
};

/// The household sizes offered as chips; the last stands for «7 or more»
/// (`household_size` allows 1–30, and a guess of 7 for a big home is closer
/// than no answer at all).
const List<int> _householdSizes = <int>[1, 2, 3, 4, 5, 6, 7];

/// What a stored `household_role` reads as on this screen.
String _roleLabel(ZadL10n l, String role) => switch (role) {
  'father' => l.introRoleFather,
  'mother' => l.introRoleMother,
  'husband' => l.introRoleHusband,
  'wife' => l.introRoleWife,
  'son' => l.introRoleSon,
  'daughter' => l.introRoleDaughter,
  'single' => l.introRoleSingle,
  'student' => l.introRoleStudent,
  'grandparent' => l.introRoleGrandparent,
  _ => l.introRoleOther,
};

/// What a stored `cares_for` value reads as on this screen.
String _caresLabel(ZadL10n l, String who) => switch (who) {
  'children' => l.introCaresChildren,
  'parents' => l.introCaresParents,
  'spouse' => l.introCaresSpouse,
  'siblings' => l.introCaresSiblings,
  'grandparents' => l.introCaresGrandparents,
  _ => who,
};

/// The screen.
class IntroduceYourselfScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<IntroduceYourselfScreen> createState() => _IntroState();
}

class _IntroState extends ConsumerState<IntroduceYourselfScreen> {
  late final CustomerProfile? _start = ref
      .read(memoryControllerProvider)
      .snapshot
      .profile;
  late final TextEditingController _name = TextEditingController(
    text: (_start?.preferredName?.trim().isNotEmpty ?? false)
        ? _start!.preferredName
        : ref.read(profileControllerProvider).name ?? '',
  );
  late String? _gender = _start?.gender;
  late String? _role = _start?.householdRole;
  // Null until answered; «محدش» is the empty set.
  late Set<String>? _caresFor = _start?.caresFor?.toSet();
  // Optional: the day the salary lands. The brain counts the month from it
  // (the salary cycle) and knows when money is tight.
  late int? _payDay = _start?.payDay;
  // How many live at home, the customer counted in. The pantry's forecasts
  // (ZAD_PLAN ١٠.١) scale with it; on 2026-11-12 the live profile had none.
  late int? _householdSize = _start?.householdSize;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _complete =>
      _name.text.trim().isNotEmpty &&
      _gender != null &&
      _role != null &&
      _caresFor != null &&
      _householdSize != null;

  Future<void> _save() async {
    if (!_complete || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final base = _start ?? const CustomerProfile();
    final profile = CustomerProfile(
      preferredName: _name.text.trim(),
      gender: _gender,
      householdRole: _role,
      ageRange: base.ageRange,
      occupation: base.occupation,
      payDay: _payDay,
      payFrequency: base.payFrequency,
      householdSize: _householdSize,
      kidsCount: base.kidsCount,
      city: base.city,
      dialect: base.dialect,
      caresFor: _caresFor!.toList(),
      zadVoice: base.zadVoice,
    );
    // The first steps (ZAD_PLAN ٢.٩) follow the introduction, and only it:
    // armed before the save, so the gate finds them when it opens.
    ref.read(firstStepsControllerProvider.notifier).arm();
    final failure = await ref
        .read(memoryControllerProvider.notifier)
        .saveProfile(profile);
    if (!mounted) return;
    // On success the gate sees a complete profile and opens the app; nothing
    // to do here.
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = context.l10n.introSaveFailed;
      });
    }
  }

  void _pickRole(String role) => setState(() {
    _role = role;
    _gender ??= _roleGender[role];
    // Living alone answers the household question too.
    if (role == 'single') _householdSize ??= 1;
  });

  void _toggleCare(String who) => setState(() {
    final next = <String>{...?_caresFor};
    next.contains(who) ? next.remove(who) : next.add(who);
    _caresFor = next;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return DecoratedBox(
      // Zad's canvas, and the answers chosen in Zad's green: it was a white
      // page of grey chips where a choice barely showed (emulator, 2026-11-10).
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Theme(
        data: theme.copyWith(
          chipTheme: theme.chipTheme.copyWith(
            backgroundColor: ZadColors.surface,
            selectedColor: ZadColors.green700,
            checkmarkColor: Colors.white,
            side: BorderSide(color: ZadColors.outline),
            shape: const StadiumBorder(),
            labelStyle: ZadType.bodyMedium.copyWith(color: ZadColors.ink),
            secondaryLabelStyle: ZadType.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: ZadSpacing.sm,
              vertical: ZadSpacing.xs,
            ),
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            title: Text(l.introTitle),
            actions: <Widget>[ZadSlots.signOutAction()],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.lg,
                ZadSpacing.sm,
                ZadSpacing.lg,
                ZadSpacing.xxl,
              ),
              children: <Widget>[
                Text(
                  l.introLead,
                  style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
                ),
                const SizedBox(height: ZadSpacing.xl),
                _Question(
                  title: l.introNameQuestion,
                  child: TextField(
                    controller: _name,
                    textInputAction: TextInputAction.done,
                    maxLength: 40,
                    decoration: InputDecoration(
                      hintText: l.introNameHint,
                      border: const OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
                _Question(
                  title: l.introGenderQuestion,
                  child: _Chips(
                    options: ProfileOptions.genders,
                    label: (g) =>
                        g == 'female' ? l.introGenderFemale : l.introGenderMale,
                    selected: <String>{?_gender},
                    onTap: (g) => setState(() => _gender = g),
                  ),
                ),
                _Question(
                  title: l.introRoleQuestion,
                  child: _Chips(
                    options: ProfileOptions.roles,
                    label: (v) => _roleLabel(l, v),
                    selected: <String>{?_role},
                    onTap: _pickRole,
                  ),
                ),
                _Question(
                  title: l.introCaresQuestion,
                  hint: l.introCaresHint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _Chips(
                        options: ProfileOptions.caresFor,
                        label: (v) => _caresLabel(l, v),
                        selected: _caresFor ?? const <String>{},
                        onTap: _toggleCare,
                      ),
                      const SizedBox(height: ZadSpacing.xs),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ChoiceChip(
                          label: Text(l.introCaresNobody),
                          selected: _caresFor?.isEmpty ?? false,
                          onSelected: (_) =>
                              setState(() => _caresFor = <String>{}),
                        ),
                      ),
                    ],
                  ),
                ),
                _Question(
                  title: l.introHouseholdQuestion,
                  hint: l.introHouseholdHint,
                  child: _Chips(
                    options: <String>[for (final n in _householdSizes) '$n'],
                    label: (n) => n == '${_householdSizes.last}'
                        ? l.introHouseholdMany
                        : n,
                    selected: <String>{
                      if (_householdSize case final n?)
                        '${n.clamp(1, _householdSizes.last)}',
                    },
                    onTap: (n) => setState(() => _householdSize = int.parse(n)),
                  ),
                ),
                _Question(
                  title: l.introPayDayQuestion,
                  hint: l.introPayDayHint,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _payDay,
                    isExpanded: true,
                    // Without a style it took the theme's title — large
                    // and bold beside the choice chips above (emulator,
                    // 2026-11-01).
                    style: ZadType.bodyLarge.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<int?>>[
                      DropdownMenuItem<int?>(child: Text(l.introPayDayNone)),
                      for (var d = 1; d <= 31; d++)
                        DropdownMenuItem<int?>(
                          value: d,
                          child: Text(l.introPayDay(d)),
                        ),
                    ],
                    onChanged: (d) => setState(() => _payDay = d),
                  ),
                ),
                if (_error case final error?) ...<Widget>[
                  Text(
                    error,
                    style: ZadType.bodySmall.copyWith(
                      color: ZadColors.terracottaRust,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.sm),
                ],
                const SizedBox(height: ZadSpacing.md),
                FilledButton(
                  onPressed: _complete && !_saving ? _save : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.introSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const new({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ZadSpacing.md),
    child: ZadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: ZadType.titleSmall),
          if (hint case final h?)
            Text(
              h,
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
          const SizedBox(height: ZadSpacing.sm),
          child,
        ],
      ),
    ),
  );
}

class _Chips extends StatelessWidget {
  const new({
    required this.options,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final List<String> options;
  final String Function(String) label;
  final Set<String> selected;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: ZadSpacing.sm,
    runSpacing: ZadSpacing.sm,
    children: <Widget>[
      for (final o in options)
        ChoiceChip(
          label: Text(label(o)),
          selected: selected.contains(o),
          onSelected: (_) => onTap(o),
        ),
    ],
  );
}
