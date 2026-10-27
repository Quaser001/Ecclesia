import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/health_score_ring.dart';
import '../../core/widgets/medical_disclaimer.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/scan_result.dart';

/// Scan result screen.
///
/// The hero of this screen is the score reveal. Product name sits above it
/// in serif display type, the verdict sits beneath. Findings use editorial
/// callouts (severity label + title + concrete detail), not generic
/// ListTiles with coloured icons.
class ScanResultScreen extends StatelessWidget {
  final ScanResult scanResult;

  const ScanResultScreen({super.key, required this.scanResult});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
        ),
        title: const Text('Scan result'),
      ),
      body: scanResult.insufficientData
          ? _buildInsufficientData(context)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(context),
                  const SizedBox(height: 32),
                  _buildFindingsSection(context),
                  const SizedBox(height: 28),
                  _buildNutritionSection(context),
                  const SizedBox(height: 28),
                  _buildAlternativesSection(context),
                  const MedicalDisclaimerFooter(),
                ],
              ),
            ),
    );
  }

  // ---------- Hero ----------

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    final score = scanResult.scoreResult.score;
    final color = AppColors.scoreColor(score);

    return Column(
      children: [
        if (scanResult.product.brand != null)
          Text(
            scanResult.product.brand!.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
          ),
        const SizedBox(height: 6),
        Text(
          scanResult.product.productName ?? 'Unnamed product',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayMedium,
        ),
        const SizedBox(height: 28),
        HealthScoreRing(score: score, size: 196, strokeWidth: 12),
        const SizedBox(height: 16),
        Text(
          scanResult.scoreResult.suitability.displayName.toLowerCase(),
          style: AppTheme.display(20, weight: FontWeight.w500, color: color),
        ),
        if (scanResult.explanation.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              scanResult.explanation,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
                height: 1.55,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------- Insufficient data ----------

  Widget _buildInsufficientData(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_filter_outlined,
                size: 56, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(height: 18),
            Text("We couldn't read this label",
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall),
            const SizedBox(height: 10),
            Text(
              scanResult.pipelineMessage ??
                  'The photo was blurry or the label was out of frame. '
                      'A clearer, closer shot usually works.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.verdict,
                foregroundColor: AppColors.bg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try another photo'),
            )
          ],
        ),
      ),
    );
  }

  // ---------- Findings ----------

  Widget _buildFindingsSection(BuildContext context) {
    if (scanResult.scoreResult.findings.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final findings = scanResult.scoreResult.findings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('What we found', style: theme.textTheme.headlineMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${findings.length}',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final f in findings) ...[
          _FindingCard(finding: f),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ---------- Nutrition ----------

  Widget _buildNutritionSection(BuildContext context) {
    final theme = Theme.of(context);
    final nut = scanResult.product.nutrition;
    final ingredients = scanResult.product.ingredients;

    final rows = <_NutritionRow>[
      _NutritionRow('Calories', _fmt(nut.caloriesKcal), 'kcal'),
      _NutritionRow('Total fat', _fmt(nut.totalFatG), 'g'),
      _NutritionRow('Saturated fat', _fmt(nut.saturatedFatG), 'g'),
      _NutritionRow('Sodium', _fmt(nut.sodiumMg), 'mg'),
      _NutritionRow('Total carbs', _fmt(nut.totalCarbsG), 'g'),
      _NutritionRow('Sugars', _fmt(nut.sugarsG), 'g'),
      _NutritionRow('Protein', _fmt(nut.proteinG), 'g'),
    ];

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('On the label', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          for (final r in rows) _buildNutrientRow(context, r),
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: theme.dividerColor, height: 1),
            const SizedBox(height: 16),
            Text('Ingredients', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(ingredients.join(', '),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _buildNutrientRow(BuildContext context, _NutritionRow row) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(row.name, style: theme.textTheme.bodyMedium),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(row.value,
                  style: AppTheme.display(17,
                      weight: FontWeight.w500,
                      color: theme.textTheme.titleLarge?.color)),
              const SizedBox(width: 4),
              Text(row.unit,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double? val) {
    if (val == null) return '—';
    if (val == val.toInt()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }

  // ---------- Alternatives ----------

  Widget _buildAlternativesSection(BuildContext context) {
    final theme = Theme.of(context);

    if (scanResult.alternatives.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.check_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "This product is a solid fit — no alternative needed.",
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Try instead', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        for (final alt in scanResult.alternatives) ...[
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alt.name ?? alt.criteria ?? 'Suggested alternative',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    if (alt.verified)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'In our database',
                          style: AppTheme.ui(10,
                              weight: FontWeight.w600,
                              color: theme.colorScheme.primary),
                        ),
                      ),
                  ],
                ),
                if (alt.brand != null) ...[
                  const SizedBox(height: 2),
                  Text(alt.brand!, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 8),
                Text(alt.reason,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _NutritionRow {
  final String name;
  final String value;
  final String unit;
  const _NutritionRow(this.name, this.value, this.unit);
}

/// Editorial callout card for a scoring finding. Severity label, title in
/// title case, concrete detail. Score impact becomes a subtle "-x pts" chip,
/// not a shouting number.
class _FindingCard extends StatelessWidget {
  final ScanFinding finding;
  const _FindingCard({required this.finding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bgColor, strokeColor, textColor, label) =
        _severityStyle(finding.severity, theme);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: strokeColor, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: AppTheme.ui(10,
                      weight: FontWeight.w700, color: textColor),
                ),
              ),
              const Spacer(),
              if (finding.scoreImpact > 0)
                Text('−${finding.scoreImpact} pts',
                    style: AppTheme.ui(11,
                        weight: FontWeight.w600,
                        color: theme.textTheme.bodyMedium?.color)),
            ],
          ),
          const SizedBox(height: 10),
          Text(finding.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(finding.detail,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }

  (Color, Color, Color, String) _severityStyle(
      FindingSeverity severity, ThemeData theme) {
    switch (severity) {
      case FindingSeverity.critical:
        return (
          AppColors.critical.withValues(alpha: 0.08),
          AppColors.critical.withValues(alpha: 0.3),
          AppColors.critical,
          'Stop',
        );
      case FindingSeverity.alert:
        return (
          AppColors.ember.withValues(alpha: 0.08),
          AppColors.ember.withValues(alpha: 0.3),
          AppColors.ember,
          'Alert',
        );
      case FindingSeverity.warning:
        return (
          AppColors.ember.withValues(alpha: 0.06),
          AppColors.ember.withValues(alpha: 0.2),
          AppColors.ember,
          'Warning',
        );
      case FindingSeverity.info:
        return (
          theme.colorScheme.primary.withValues(alpha: 0.06),
          theme.colorScheme.primary.withValues(alpha: 0.2),
          theme.colorScheme.primary,
          'Info',
        );
    }
  }
}
