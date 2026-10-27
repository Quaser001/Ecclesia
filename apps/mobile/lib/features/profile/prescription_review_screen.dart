import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/prescription_suggestions.dart';
import '../../models/user_profile.dart';

/// Review what was read from the prescription and pick what to add.
///
/// Nothing is pre-selected. Pops the updated [UserProfile] when the user
/// confirms, or `null` when they close the screen.
class PrescriptionReviewScreen extends StatefulWidget {
  final PrescriptionSuggestions suggestions;
  final UserProfile currentProfile;

  const PrescriptionReviewScreen({
    super.key,
    required this.suggestions,
    required this.currentProfile,
  });

  @override
  State<PrescriptionReviewScreen> createState() =>
      _PrescriptionReviewScreenState();
}

class _PrescriptionReviewScreenState extends State<PrescriptionReviewScreen> {
  final Set<String> _conditions = {};
  final Set<String> _allergies = {};

  int get _count => _conditions.length + _allergies.length;

  static String _humanize(String raw) => raw
      .split('_')
      .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');

  void _confirm() {
    final p = widget.currentProfile;
    Navigator.pop(
      context,
      p.copyWith(
        healthConditions: {...p.healthConditions, ..._conditions}.toList(),
        allergies: {...p.allergies, ..._allergies}.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestions;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: s.isEmpty ? _empty(theme, s) : _list(theme, s),
      bottomNavigationBar: s.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: _count == 0 ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.verdict,
                    foregroundColor: AppColors.bg,
                  ),
                  child: Text(_count == 0
                      ? 'Select what to add'
                      : 'Add selected ($_count)'),
                ),
              ),
            ),
    );
  }

  Widget _empty(ThemeData theme, PrescriptionSuggestions s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 44, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(height: 16),
            Text(s.message ?? "We couldn't find anything to add from this photo.",
                textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (s.unrecognised.isNotEmpty) ...[
              const SizedBox(height: 16),
              _skipped(theme, s),
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(ThemeData theme, PrescriptionSuggestions s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(
          'Tick what applies to you. Nothing is added until you confirm.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (s.conditions.isNotEmpty) ...[
          Text('Conditions', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final c in s.conditions)
                  CheckboxListTile(
                    value: _conditions.contains(c.condition),
                    onChanged: (v) => _toggle(_conditions, c.condition, v),
                    activeColor: AppColors.verdict,
                    checkColor: AppColors.bg,
                    title: Text(_humanize(c.condition)),
                    subtitle: Text(
                      c.inferred
                          ? 'Inferred from a medicine (${c.sourceText}). Check this applies to you.'
                          : 'Stated on the prescription',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        color: c.inferred ? AppColors.ember : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (s.allergies.isNotEmpty) ...[
          Text('Allergies', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final a in s.allergies)
                  CheckboxListTile(
                    value: _allergies.contains(a.name),
                    onChanged: (v) => _toggle(_allergies, a.name, v),
                    activeColor: AppColors.verdict,
                    checkColor: AppColors.bg,
                    title: Text(_humanize(a.name)),
                    subtitle: Text('Stated on the prescription',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontSize: 12.5)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (s.unrecognised.isNotEmpty) _skipped(theme, s),
      ],
    );
  }

  Widget _skipped(ThemeData theme, PrescriptionSuggestions s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Read but not added',
            style: AppTheme.ui(12,
                weight: FontWeight.w700, color: theme.textTheme.bodyMedium?.color)),
        const SizedBox(height: 6),
        Text(s.unrecognised.join(' · '), style: theme.textTheme.bodyMedium),
      ],
    );
  }

  void _toggle(Set<String> set, String value, bool? on) {
    HapticFeedback.selectionClick();
    setState(() => on == true ? set.add(value) : set.remove(value));
  }
}
