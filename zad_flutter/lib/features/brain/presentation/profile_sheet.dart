/// The form behind "إنت مين عند زاد": the fields the customer can correct.
///
/// Returns the edited profile, normalised to what the table accepts, or null
/// when dismissed. Nothing is autofocused — a sheet with a blinking cursor
/// never settles under test, and the customer came to read before typing.
library;

import 'package:flutter/material.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/brain/domain/customer_profile.dart';

/// Opens the form over [current].
Future<CustomerProfile?> showProfileSheet(
  BuildContext context,
  CustomerProfile? current,
) => showModalBottomSheet<CustomerProfile>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => ProfileSheet(initial: current ?? const CustomerProfile()),
);

/// Reads a whole number typed with either digit set.
int? parseWholeNumber(String text) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final western = String.fromCharCodes(<int>[
    for (final c in text.trim().runes)
      if (arabic.contains(String.fromCharCode(c)))
        '0'.codeUnitAt(0) + arabic.indexOf(String.fromCharCode(c))
      else
        c,
  ]);
  return int.tryParse(western);
}

/// The form.
class ProfileSheet extends StatefulWidget {
  /// Creates the form.
  const new({required this.initial, super.key});

  /// What the server had.
  final CustomerProfile initial;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.preferredName,
  );
  late final TextEditingController _occupation = TextEditingController(
    text: widget.initial.occupation,
  );
  late final TextEditingController _payDay = TextEditingController(
    text: widget.initial.payDay?.toString(),
  );
  late final TextEditingController _household = TextEditingController(
    text: widget.initial.householdSize?.toString(),
  );
  late final TextEditingController _kids = TextEditingController(
    text: widget.initial.kidsCount?.toString(),
  );
  late final TextEditingController _city = TextEditingController(
    text: widget.initial.city,
  );
  late String? _gender = widget.initial.gender;
  late String? _role = widget.initial.householdRole;
  late String? _age = widget.initial.ageRange;
  late String? _frequency = widget.initial.payFrequency;
  late String? _dialect = widget.initial.dialect;

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _name,
      _occupation,
      _payDay,
      _household,
      _kids,
      _city,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(
    CustomerProfile(
      preferredName: _name.text,
      gender: _gender,
      householdRole: _role,
      ageRange: _age,
      occupation: _occupation.text,
      payDay: parseWholeNumber(_payDay.text),
      payFrequency: _frequency,
      householdSize: parseWholeNumber(_household.text),
      kidsCount: parseWholeNumber(_kids.text),
      city: _city.text,
      dialect: _dialect,
    ).normalized(),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            0,
            ZadSpacing.gutter,
            ZadSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('إنت مين عند زاد', style: ZadType.titleMedium),
              const SizedBox(height: ZadSpacing.lg),
              TextField(
                controller: _name,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'بتحب أناديك'),
              ),
              _Chips(
                title: 'النوع',
                options: ProfileOptions.genders,
                selected: _gender,
                label: ProfileLabels.gender,
                onChanged: (v) => setState(() => _gender = v),
              ),
              _Chips(
                title: 'دورك في البيت',
                options: ProfileOptions.roles,
                selected: _role,
                label: ProfileLabels.role,
                onChanged: (v) => setState(() => _role = v),
              ),
              _Chips(
                title: 'العمر',
                options: ProfileOptions.ageRanges,
                selected: _age,
                label: ProfileLabels.age,
                onChanged: (v) => setState(() => _age = v),
              ),
              const SizedBox(height: ZadSpacing.md),
              TextField(
                controller: _occupation,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'شغلك'),
              ),
              TextField(
                controller: _payDay,
                keyboardType: TextInputType.number,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'بتقبض يوم كام في الشهر؟',
                ),
              ),
              _Chips(
                title: 'بتقبض كل قد إيه',
                options: ProfileOptions.payFrequencies,
                selected: _frequency,
                label: ProfileLabels.frequency,
                onChanged: (v) => setState(() => _frequency = v),
              ),
              const SizedBox(height: ZadSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _household,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      decoration: const InputDecoration(
                        labelText: 'عدد اللي في البيت',
                      ),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _kids,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      decoration: const InputDecoration(
                        labelText: 'عدد العيال',
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _city,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'المدينة'),
              ),
              _Chips(
                title: 'اللهجة',
                options: ProfileOptions.dialects,
                selected: _dialect,
                label: ProfileLabels.dialect,
                onChanged: (v) => setState(() => _dialect = v),
              ),
              const SizedBox(height: ZadSpacing.xl),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('احفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One choice from a list; tapping the chosen one again clears it back to
/// "not known".
class _Chips extends StatelessWidget {
  const new({
    required this.title,
    required this.options,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final String? selected;
  final String Function(String) label;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: ZadSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: ZadType.labelLarge),
        const SizedBox(height: ZadSpacing.xs),
        Wrap(
          spacing: ZadSpacing.sm,
          runSpacing: ZadSpacing.xs,
          children: <Widget>[
            for (final o in options)
              FilterChip(
                label: Text(label(o)),
                selected: selected == o,
                onSelected: (_) => onChanged(selected == o ? null : o),
              ),
          ],
        ),
      ],
    ),
  );
}
