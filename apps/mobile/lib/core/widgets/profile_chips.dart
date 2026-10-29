import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/user_profile.dart';
import '../constants/app_colors.dart';

/// A profile as chips: allergies, conditions, diets, goals. Used for "Scoring
/// for you" on Home and "Scored for" on a scan, so both read the same way.
class ProfileChips extends StatelessWidget {
  final UserProfile profile;
  const ProfileChips({super.key, required this.profile});

  static bool isEmpty(UserProfile p) =>
      p.allergies.isEmpty &&
      p.healthConditions.isEmpty &&
      p.dietaryPreferences.isEmpty &&
      p.healthGoals.isEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final l = context.l10n;
    final p = profile;
    final chips = <(String, Color, IconData)>[
      for (final a in p.allergies)
        (
          l.allergyChip(a.isEmpty ? a : '${a[0].toUpperCase()}${a.substring(1)}'),
          c.critical,
          Icons.warning_amber_rounded,
        ),
      for (final x in p.healthConditions) (l.conditionLabel(x), c.accent, Icons.monitor_heart_outlined),
      for (final d in p.dietaryPreferences) (l.dietLabel(d), c.good, Icons.restaurant_outlined),
      for (final g in p.healthGoals) (l.goalLabel(g), c.brand, Icons.flag_outlined),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, tone, icon) in chips)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
            decoration: BoxDecoration(
              color: c.tint(tone, theme.brightness),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: tone),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label, style: AppTheme.ui(13, weight: FontWeight.w600, color: tone)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
