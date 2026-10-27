import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/health_score_ring.dart';
import '../../core/widgets/medical_disclaimer.dart';
import '../../core/widgets/status_view.dart';
import '../../core/widgets/surface_card.dart';
import '../../l10n/l10n.dart';
import '../../models/scan_result.dart';

/// Scan result: the score reveal, what was found, what's on the label and
/// what to try instead.
///
/// Also used for past scans opened from Home, History or Insights
/// ([isPastScan]). Alternatives are not stored with a scan, so that section
/// is left out for past scans rather than claiming none were needed.
class ScanResultScreen extends StatelessWidget {
  final ScanResult scanResult;
  final String? title;
  final bool isPastScan;

  const ScanResultScreen({
    super.key,
    required this.scanResult,
    this.title,
    this.isPastScan = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(isPastScan ? Icons.arrow_back_rounded : Icons.close_rounded),
          tooltip: isPastScan ? context.l10n.back : context.l10n.close,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
        ),
        title: Text(title ?? context.l10n.scanResultTitle),
      ),
      body: scanResult.insufficientData
          ? StatusView(
              icon: Icons.photo_camera_back_outlined,
              title: context.l10n.cantReadLabel,
              message: scanResult.pipelineMessage ?? context.l10n.cantReadLabelBody,
              actionLabel: context.l10n.tryAnotherPhoto,
              onAction: () => Navigator.of(context).pop(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                _Hero(scanResult: scanResult, isPastScan: isPastScan),
                const SizedBox(height: 28),
                _Findings(findings: scanResult.scoreResult.findings),
                _LabelFacts(scanResult: scanResult),
                if (!isPastScan) ...[
                  const SizedBox(height: 28),
                  _Alternatives(scanResult: scanResult),
                ],
                const MedicalDisclaimerFooter(),
              ],
            ),
    );
  }
}

class _Hero extends StatelessWidget {
  final ScanResult scanResult;
  final bool isPastScan;
  const _Hero({required this.scanResult, required this.isPastScan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final score = scanResult.scoreResult.score;
    final color = c.score(score);
    final brand = scanResult.product.brand;

    return Column(
      children: [
        if (brand != null && brand.isNotEmpty)
          Text(brand.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Text(
          scanResult.product.productName ?? context.l10n.unnamedProduct,
          textAlign: TextAlign.center,
          style: theme.textTheme.displayMedium,
        ),
        if (isPastScan) ...[
          const SizedBox(height: 6),
          Text(context.l10n.scannedWhen(context.l10n.relativeTime(scanResult.scannedAt)),
              style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 24),
        HealthScoreRing(score: score, size: 188, strokeWidth: 12, animate: !isPastScan),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: c.tint(color, theme.brightness),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            context.l10n.suitabilityLabel(scanResult.scoreResult.suitability),
            style: AppTheme.ui(14, weight: FontWeight.w700, color: color),
          ),
        ),
        if (scanResult.explanation.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            scanResult.explanation,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _Findings extends StatelessWidget {
  final List<ScanFinding> findings;
  const _Findings({required this.findings});

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.whatWeFound(findings.length),
              style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          for (final f in findings) ...[
            _FindingCard(finding: f),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _LabelFacts extends StatelessWidget {
  final ScanResult scanResult;
  const _LabelFacts({required this.scanResult});

  static String _fmt(double? val) {
    if (val == null) return '—';
    if (val == val.toInt()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nut = scanResult.product.nutrition;
    final ingredients = scanResult.product.ingredients;
    final l = context.l10n;
    final rows = <(String, String, String)>[
      (l.nutrientCalories, _fmt(nut.caloriesKcal), 'kcal'),
      (l.nutrientTotalFat, _fmt(nut.totalFatG), 'g'),
      (l.nutrientSaturatedFat, _fmt(nut.saturatedFatG), 'g'),
      (l.nutrientSodium, _fmt(nut.sodiumMg), 'mg'),
      (l.nutrientCarbs, _fmt(nut.totalCarbsG), 'g'),
      (l.nutrientSugars, _fmt(nut.sugarsG), 'g'),
      (l.nutrientProtein, _fmt(nut.proteinG), 'g'),
    ];

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.onTheLabel, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(l.perServingNote, style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, color: context.colors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text(r.$1, style: theme.textTheme.bodyLarge)),
                  Text(r.$2, style: theme.textTheme.titleMedium),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 34,
                    child: Text(r.$3, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ],
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l.ingredients, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(ingredients.join(', '), style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _Alternatives extends StatelessWidget {
  final ScanResult scanResult;
  const _Alternatives({required this.scanResult});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;

    if (scanResult.alternatives.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: c.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Text(context.l10n.noAlternative, style: theme.textTheme.bodyLarge),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.tryInstead, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(context.l10n.tryInsteadBody, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        for (final alt in scanResult.alternatives) ...[
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (alt.imageUrl != null) ...[
                      _ProductThumb(url: alt.imageUrl!),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(alt.name ?? alt.criteria ?? context.l10n.tryInstead,
                          style: theme.textTheme.titleLarge),
                    ),
                    if (alt.verified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.brandSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(context.l10n.inOurDatabase,
                            style: AppTheme.ui(12, weight: FontWeight.w700, color: c.brand)),
                      ),
                  ],
                ),
                if (alt.brand != null) ...[
                  const SizedBox(height: 2),
                  Text(alt.brand!, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 8),
                Text(alt.reason, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// A scoring finding: severity pill (word + colour), title, detail, and the
/// points it cost.
class _FindingCard extends StatelessWidget {
  final ScanFinding finding;
  const _FindingCard({required this.finding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final (tone, label, icon) = switch (finding.severity) {
      FindingSeverity.critical => (c.critical, context.l10n.severityAvoid, Icons.block_rounded),
      FindingSeverity.alert => (c.accent, context.l10n.severityCaution, Icons.warning_amber_rounded),
      FindingSeverity.warning => (c.warning, context.l10n.severityHeadsUp, Icons.info_outline_rounded),
      FindingSeverity.info => (c.brand, context.l10n.severityGoodToKnow, Icons.lightbulb_outline_rounded),
    };

    return SurfaceCard(
      background: Color.alphaBlend(c.tint(tone, theme.brightness).withValues(alpha: 0.06),
          theme.colorScheme.surface),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                decoration: BoxDecoration(
                  color: c.tint(tone, theme.brightness),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: tone),
                    const SizedBox(width: 4),
                    Text(label, style: AppTheme.ui(12, weight: FontWeight.w700, color: tone)),
                  ],
                ),
              ),
              const Spacer(),
              if (finding.scoreImpact > 0)
                Text(context.l10n.pointsLost(finding.scoreImpact), style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 10),
          Text(finding.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(finding.detail, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Product photo from Open Food Facts for a suggested alternative. Falls back
/// to an icon when the image can't be loaded (offline, removed upstream).
class _ProductThumb extends StatelessWidget {
  final String url;
  const _ProductThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        color: c.elevated,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              Icon(Icons.image_not_supported_outlined, color: c.muted),
        ),
      ),
    );
  }
}
