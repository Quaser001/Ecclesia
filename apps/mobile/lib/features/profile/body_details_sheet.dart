import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/user_profile.dart';

/// Ranges match the backend's validation (src/domain/models.py).
const _heightRange = (50.0, 250.0);
const _weightRange = (15.0, 350.0);
const _sexes = ['female', 'male', 'other'];
const _activities = ['sedentary', 'light', 'moderate', 'active', 'very_active'];

/// Edit body details in a bottom sheet. Returns the updated profile, or null
/// if the user backs out. Empty fields are saved as "not set".
Future<UserProfile?> showBodyDetailsSheet(BuildContext context, UserProfile profile) {
  return showModalBottomSheet<UserProfile>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _BodyDetailsSheet(profile: profile),
  );
}

class _BodyDetailsSheet extends StatefulWidget {
  final UserProfile profile;
  const _BodyDetailsSheet({required this.profile});

  @override
  State<_BodyDetailsSheet> createState() => _BodyDetailsSheetState();
}

/// Matches ADULT_AGE on the server.
const adultAge = 18;

class _BodyDetailsSheetState extends State<_BodyDetailsSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _target;
  late final TextEditingController _birthYear;
  String? _sex;
  String? _activity;

  static String _text(num? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _height = TextEditingController(text: _text(p.heightCm));
    _weight = TextEditingController(text: _text(p.weightKg));
    _target = TextEditingController(text: _text(p.targetWeightKg));
    _birthYear = TextEditingController(text: _text(p.birthYear));
    _sex = p.sex;
    _activity = p.activityLevel;
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _target.dispose();
    _birthYear.dispose();
    super.dispose();
  }

  String? _validate(String? raw, (double, double) range, AppLocalizations l) {
    final text = (raw ?? '').trim().replaceAll(',', '.');
    if (text.isEmpty) return null; // optional
    final v = double.tryParse(text);
    if (v == null || v < range.$1 || v > range.$2) {
      return l.invalidRange(range.$1.toStringAsFixed(0), range.$2.toStringAsFixed(0));
    }
    return null;
  }

  /// Adults only: a child's data needs verifiable parental consent (DPDP
  /// Act s.9), which CalFit doesn't collect. Same line as the server: turning
  /// 18 this calendar year is allowed.
  String? _validateBirthYear(String? raw, (double, double) range, AppLocalizations l) {
    final error = _validate(raw, range, l);
    if (error != null) return error;
    final year = int.tryParse((raw ?? '').trim());
    if (year != null && DateTime.now().year - year < adultAge) return l.adultsOnlyBirthYear;
    return null;
  }

  double? _parse(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final year = int.tryParse(_birthYear.text.trim());
    Navigator.pop(
      context,
      widget.profile.copyWith(
        heightCm: _parse(_height),
        weightKg: _parse(_weight),
        targetWeightKg: _parse(_target),
        birthYear: _birthYear.text.trim().isEmpty ? null : year,
        sex: _sex,
        activityLevel: _activity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final thisYear = DateTime.now().year;
    final yearRange = (1900.0, thisYear.toDouble());
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);

    Widget numberField(TextEditingController c, String label, String unit, (double, double) range,
            {bool decimal = true}) =>
        TextFormField(
          controller: c,
          keyboardType: decimal ? numberKeyboard : TextInputType.number,
          decoration: InputDecoration(labelText: label, suffixText: unit),
          validator: (v) => _validate(v, range, l),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.bodyEditTitle, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(l.bodyCaption, style: theme.textTheme.bodySmall),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: numberField(_height, l.height, l.unitCm, _heightRange)),
                    const SizedBox(width: 12),
                    Expanded(child: numberField(_weight, l.weight, l.unitKg, _weightRange)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: numberField(_target, l.targetWeight, l.unitKg, _weightRange)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextFormField(
                          controller: _birthYear,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: l.birthYear),
                          validator: (v) => _validateBirthYear(v, yearRange, l),
                        )),
                  ],
                ),
                const SizedBox(height: 18),
                Text(l.sex, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in _sexes)
                      ChoiceChip(
                        label: Text(l.sexLabel(s)),
                        selected: _sex == s,
                        onSelected: (on) => setState(() => _sex = on ? s : null),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(l.activityLevel, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                RadioGroup<String>(
                  groupValue: _activity,
                  onChanged: (v) => setState(() => _activity = v),
                  child: Column(
                    children: [
                      for (final a in _activities)
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: a,
                          title: Text(l.activityLabel(a)),
                          subtitle: Text(l.activityHint(a)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(l.bmiNote, style: theme.textTheme.bodySmall),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(onPressed: _save, child: Text(l.save))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
