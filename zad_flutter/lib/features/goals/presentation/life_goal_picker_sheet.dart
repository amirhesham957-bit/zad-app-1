/// Kotlin's `LifeGoalPickerSheet` (`ui/components/LifeGoalPickerSheet.kt`):
/// the activation card's «حدد أول هدف لبيتك» step.
///
/// Records the goal through `zad_seed_life_goal` directly — deterministic, no
/// model call — which also links a weekly follow-up, so the progress loop
/// starts at once.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/goals/data/life_goals_remote.dart';
import 'package:zad/features/goals/domain/life_goal_seed.dart';

/// Opens the sheet. Resolves true when a goal was saved.
Future<bool> showLifeGoalPickerSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _LifeGoalPickerSheet(),
  );
  return saved ?? false;
}

class _LifeGoalPickerSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_LifeGoalPickerSheet> createState() => _State();
}

class _State extends ConsumerState<_LifeGoalPickerSheet> {
  LifeGoalPreset _preset = LifeGoalPreset.saveMonthly;
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _custom = TextEditingController();
  bool _saving = false;
  String? _errorCode;

  @override
  void dispose() {
    _amount.dispose();
    _custom.dispose();
    super.dispose();
  }

  LifeGoalSeed? get _seed => LifeGoalSeeds.build(
    preset: _preset,
    amount: double.tryParse(_amount.text.trim().replaceAll(',', '.')),
    customTitle: _custom.text,
    today: DateTime.now(),
  );

  Future<void> _submit(LifeGoalSeed seed) async {
    setState(() {
      _saving = true;
      _errorCode = null;
    });
    final result = await ref.read(lifeGoalsRemoteProvider).seedLifeGoal(seed);
    if (!mounted) return;
    if (result.ok) {
      ref.read(hasActiveLifeGoalProvider.notifier).markSaved();
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _errorCode = result.error ?? 'unknown';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final seed = _seed;
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'إيه أهم هدف لبيتك دلوقتي؟',
                style: ZadType.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'اختار واحد — زاد هيتابعه معاك كل أسبوع لمدة ٣ شهور، '
                'وتقدر تلغيه في أي وقت.',
                style: ZadType.bodySmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _PresetRow(
                value: LifeGoalPreset.saveMonthly,
                selected: _preset,
                icon: Icons.savings,
                title: 'أوفّر مبلغ كل شهر',
                description: 'حدد المبلغ، وزاد يتابع صرفك عشان توصله',
                onSelect: _select,
              ),
              if (_preset == LifeGoalPreset.saveMonthly) ...<Widget>[
                const SizedBox(height: 8),
                TextField(
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                    LengthLimitingTextInputFormatter(12),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ الشهري',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _PresetRow(
                value: LifeGoalPreset.stickToBudget,
                selected: _preset,
                icon: Icons.account_balance_wallet,
                title: 'ألتزم بميزانية الشهر',
                description: 'زاد ينبهك قبل ما الصرف يسبق الميزانية',
                onSelect: _select,
              ),
              const SizedBox(height: 8),
              _PresetRow(
                value: LifeGoalPreset.payOffDebts,
                selected: _preset,
                icon: Icons.credit_card,
                title: 'أسدد ديوني',
                description: 'زاد يتابع معاك المتبقي وأقرب قسط',
                onSelect: _select,
              ),
              const SizedBox(height: 8),
              _PresetRow(
                value: LifeGoalPreset.reduceWaste,
                selected: _preset,
                icon: Icons.kitchen,
                title: 'أقلل هدر المطبخ',
                description: 'زاد يفكرك بالأصناف قبل ما تبوظ',
                onSelect: _select,
              ),
              const SizedBox(height: 8),
              _PresetRow(
                value: LifeGoalPreset.custom,
                selected: _preset,
                icon: Icons.edit,
                title: 'هدف تاني بكلامي',
                description: 'اكتبه زي ما بتقوله',
                onSelect: _select,
              ),
              if (_preset == LifeGoalPreset.custom) ...<Widget>[
                const SizedBox(height: 8),
                TextField(
                  controller: _custom,
                  enabled: !_saving,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(200),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'اكتب هدفك',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_errorCode != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _errorCode == 'too_many_active_goals'
                      ? 'عندك ٥ أهداف شغالة — خلّص واحد أو ألغيه الأول'
                      : 'معرفتش أسجل الهدف — جرّب تاني',
                  style: ZadType.bodySmall.copyWith(color: scheme.error),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: seed != null && !_saving
                      ? () => _submit(seed)
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : Text(
                          'ابدأ الهدف',
                          style: ZadType.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
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

  void _select(LifeGoalPreset p) => setState(() => _preset = p);
}

class _PresetRow extends StatelessWidget {
  const new({
    required this.value,
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onSelect,
  });

  final LifeGoalPreset value;
  final LifeGoalPreset selected;
  final IconData icon;
  final String title;
  final String description;
  final ValueChanged<LifeGoalPreset> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = value == selected;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      child: Material(
        color: isSelected ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            width: isSelected ? 2 : 1,
            color: isSelected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelect(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: ZadType.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: ZadType.bodySmall.copyWith(
                          color: isSelected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IgnorePointer(
                  child: RadioGroup<LifeGoalPreset>(
                    groupValue: selected,
                    onChanged: (_) {},
                    child: Radio<LifeGoalPreset>(value: value),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
