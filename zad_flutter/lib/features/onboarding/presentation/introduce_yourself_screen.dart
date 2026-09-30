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
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
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
      _caresFor != null;

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
      payDay: base.payDay,
      payFrequency: base.payFrequency,
      householdSize: base.householdSize,
      kidsCount: base.kidsCount,
      city: base.city,
      dialect: base.dialect,
      caresFor: _caresFor!.toList(),
    );
    final failure = await ref
        .read(memoryControllerProvider.notifier)
        .saveProfile(profile);
    if (!mounted) return;
    // On success the gate sees a complete profile and opens the app; nothing
    // to do here.
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = 'مقدرتش أحفظ — اتأكد من النت وجرّب تاني.';
      });
    }
  }

  void _pickRole(String role) => setState(() {
    _role = role;
    _gender ??= _roleGender[role];
  });

  void _toggleCare(String who) => setState(() {
    final next = <String>{...?_caresFor};
    next.contains(who) ? next.remove(who) : next.add(who);
    _caresFor = next;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('عرّفني بيك'),
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
              'أربع أسئلة بس، عشان أكلمك صح وآخد بالي من اللي في رعايتك.',
              style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.xl),
            _Question(
              title: 'أناديك بإيه؟',
              child: TextField(
                controller: _name,
                textInputAction: TextInputAction.done,
                maxLength: 40,
                decoration: const InputDecoration(
                  hintText: 'اسمك أو اسم الدلع',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ),
            _Question(
              title: 'أكلمك بصيغة إيه؟',
              child: _Chips(
                options: ProfileOptions.genders,
                label: (g) => g == 'female' ? 'ست' : 'راجل',
                selected: <String>{?_gender},
                onTap: (g) => setState(() => _gender = g),
              ),
            ),
            _Question(
              title: 'إنت مين في البيت؟',
              child: _Chips(
                options: ProfileOptions.roles,
                label: ProfileLabels.role,
                selected: <String>{?_role},
                onTap: _pickRole,
              ),
            ),
            _Question(
              title: 'مين في رعايتك؟',
              hint: 'اختار كل اللي ينطبق.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Chips(
                    options: ProfileOptions.caresFor,
                    label: ProfileLabels.caresFor,
                    selected: _caresFor ?? const <String>{},
                    onTap: _toggleCare,
                  ),
                  const SizedBox(height: ZadSpacing.xs),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ChoiceChip(
                      label: const Text('محدش — مسؤول عن نفسي بس'),
                      selected: _caresFor?.isEmpty ?? false,
                      onSelected: (_) => setState(() => _caresFor = <String>{}),
                    ),
                  ),
                ],
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
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('يلا بينا'),
            ),
          ],
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
    padding: const EdgeInsets.only(bottom: ZadSpacing.xl),
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
